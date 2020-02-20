package misc::invoice;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

sub invoice_due{
	my ($s) = shift;

	my $until = $s->param('until');
	
	my $sql = <<"__eos__",
		select date_format(inv_date,'%d-%m-%Y') as inv_date, date_format(due_date,'%d-%m-%Y') as due_date, outlet_name, outlet_id, 
        concat(outlet_id,'/',inv_date) as invoice_number, format(amount,2) as amount, inv_id,invoice.status='Unpaid' as status, member_name
from invoice
        inner join outlet using (outlet_id)
		inner join member using (member_id)
__eos__
	
	my %param  = (
		until => 'due_date < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
		member_name => "member_name = ?",
	);
	
	my (@where, @bind);
	foreach (keys %param) {
		if ($s->param($_)) {
			push @where, $param{$_};
			push @bind, $s->param($_);
		}
	}
		
	if (@where) {
		$sql .= "\n WHERE ";
		$sql .= join(" and ", @where);
	}
	$sql .= "\n having status > 0 ";
	my $log = $s->log();
        $log->warn($sql);

	my $res = $s->query($sql, @bind); $sql = '';
	while (my @row = $res->list) {
		for (my $i=0;$i<scalar(@row);$i++) {
		$row[$i]='' unless defined($row[$i]);
		}
		$sql .= join("\t", @row)."\n";
	}
	
	return [$sql, 'application/vnd.ms-excel']
}

sub invoice_payment{
	my ($s) = shift;

	my $from = $s->param('from');
	my $until = $s->param('until');
	my $member_name = $s->param('member_name');
	my $site_id = $s->param('site_id');
	
	my $sql = <<"__eos__",
		select if(inv_date=due_date,'',date_format(inv_date,'%d-%m-%Y')) as inv_date, if(inv_date=due_date,'',date_format(due_date,'%d-%m-%Y')) as due_date,
		outlet_name, outlet_id, if(inv_date=due_date,'',concat(outlet_id,'/',inv_date)) as invoice_number, format(amount,2) as amount, inv_id, member_name,
		date_format(trans_date, '%d-%m-%Y')trans_date, trans_time, case trans_type when 'paid_cash' then 'cash' when 'paid_bank' then 'transfer' end as trans_type, site_name, site_id
from invoice
        inner join outlet using (outlet_id)
		inner join transaction using (trans_id)
		inner join member using (member_id)
		inner join site using (site_id)
__eos__

	my %param  = (
		from  => 'trans_date >= str_to_date(?, "%d-%m-%Y")',
		until => 'trans_date < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
		member_name => "member_name = ?",
		site_id => "site_id=?", 
	);
	
	my (@where, @bind);
	foreach (keys %param) {
		if ($s->param($_)) {
			push @where, $param{$_};
			push @bind, $s->param($_);
		}
	}
		
	if (@where) {
		$sql .= "\n WHERE ";
		$sql .= join(" and ", @where);
	}
	$sql .= "\n order by trans_id desc";
	my $log = $s->log();
        $log->warn($sql);

	my $res = $s->query($sql, @bind); $sql = '';
	while (my @row = $res->list) {
		for (my $i=0;$i<scalar(@row);$i++) {
		$row[$i]='' unless defined($row[$i]);
		}
		$sql .= join("\t", @row)."\n";
	}
	
	return [$sql, 'application/vnd.ms-excel']
}

1;
