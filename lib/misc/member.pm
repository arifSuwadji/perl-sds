package misc::member;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

sub mutation {
	my ($s) = shift;
	my $member_id = $s->param('id');
	my $from = $s->param('from');
	my $until= $s->param('until');
	return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	my $sql = 'select trans_date, trans_time, trans_id,trans_type, 
  if(amount<0, format(-amount,3), null) as debet, 
  if(amount>0, format(amount, 3), null) as kredit,
  balance
from mutation 
  inner join transaction using (trans_id)';

	my %param = (
		from => "trans_date >= str_to_date(?,'%d-%m-%Y')",
                until => "trans_date <= str_to_date(?,'%d-%m-%Y')",
		id => "mutation.member_id = ?",
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

	$sql .= "\norder by trans_id desc";
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

