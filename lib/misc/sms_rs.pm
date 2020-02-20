package misc::sms_rs;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

sub list_sms_rs {
	my ($s) = shift;
	my $from = $s->param('from')||'';
	my $until= $s->param('until')||'';
	return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	my $sql = 'select sms_rs_id, sms_int, rs_number, sms_out, sms_time, in_smsc.smsc_name as in_smsc_name, out_smsc.smsc_name as out_smsc_name
from sms_rs
  inner join smsc as in_smsc on in_smsc.smsc_id = sms_rs.in_smsc_id
  inner join smsc as out_smsc on out_smsc.smsc_id = sms_rs.out_smsc_id
  inner join rs_chip using (rs_id)
';
	my %param = (
		from => "date(sms_time) >= str_to_date(?,'%d-%m-%Y')",
                until => "date(sms_time) <= str_to_date(?,'%d-%m-%Y')",
                rs_number => "rs_number=?",
                in_smsc_name => "in_smsc.smsc_name like concat(?,'%')",
                out_smsc_name => "out_smsc.smsc_name like concat(?,'%')",
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

	$sql .= "\norder by sms_rs_id desc";
	my $log = $s->log();
        $log->warn($sql);
	my $res = $s->query($sql, @bind); $sql = '';
	while (my @row = $res->list) {
		$log->warn(scalar(@row));
		for (my $i=0;$i<scalar(@row);$i++) {
		$row[$i]='' unless defined($row[$i]);
		}
		$sql .= join("\t", @row)."\n";
	}
	
	return [$sql, 'application/vnd.ms-excel']
}

1;

