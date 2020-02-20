package misc::stock;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

sub stock_mutation {
	my ($s) = shift;
	my $from = $s->param('from')||'';
	my $until= $s->param('until')||'';
	return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	my $sql = 'select sd_id, sd_name, sd_number, sm_ts, stock_ref_name, if(trx_qty>=0,trx_qty,0) as sin, if(trx_qty<=0,trx_qty,0) as sout, stock_qty from stock_mutation inner join sd_stock using(sd_stock_id) inner join stock_ref using (stock_ref_id) left join topup using (trans_id) inner join sd_chip using (sd_id)';

	my %param;
        if ($s->{adm_gid} == 1) {
		%param = (
			from => "sm_ts >= str_to_date(?,'%d-%m-%Y')",
			until => "sm_ts < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day)",
			stock_ref_name => "stock_ref_name like concat('%',?,'%')",
			sd_name => "sd_name =?",
		);
        } else {
		%param = (
			from => "sm_ts >= str_to_date(?,'%d-%m-%Y')",
			until => "sm_ts < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day)",
			stock_ref_name => "stock_ref_name like concat('%',?,'%')",
			sd_name => "sd_name =?",
			site_id => "sd_chip.site_id = ?",
		);
		%param = ("site_id" => $s->{site_id});
	}
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

	$sql .= "\norder by sm_ts DESC";
	my $log = $s->log();
        $log->warn($sql);
	
	my $res = $s->query($sql, @bind); $sql = '';
	while (my @row = $res->list) {
	#	$log->warn(scalar(@row));
		for (my $i=0;$i<scalar(@row);$i++) {
		$row[$i]='' unless defined($row[$i]);
		}
		$sql .= join("\t", @row)."\n";
	}
	
	return [$sql, 'application/vnd.ms-excel']
}

1;
