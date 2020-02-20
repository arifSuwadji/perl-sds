package misc::setting;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

sub reg_list {
	my ($s) = shift;
	my $from = $s->param('from')||'';
	my $until= $s->param('until')||'';
	return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	my $sql = "select perdana_id, ts_perdana, perdana_number, status, note from msisdn_perdana";
	my %param = (
		from       => "ts_perdana >= str_to_date(?,'%d-%m-%Y')",
		until      => "ts_perdana < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day)",
		number     => "perdana_number = ?",
		status     => "status=?",
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
	$sql .= "\norder by perdana_id desc";
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
