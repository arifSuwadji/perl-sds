package misc::sms;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

sub list_sms {
	my ($s) = shift;
	my $from = $s->param('from')||'';
	my $until= $s->param('until')||'';
	return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	my $sql = 'select sms_int, username, member_name, out_msg, sms_time, sms_localtime,smsc_name from sms inner join smsc using(smsc_id) inner join user using(user_id) inner join member using (member_id)left join sms_outbox using (sms_id)';
	my %param = (
		from => "sms_time >= str_to_date(?,'%d-%m-%Y')",
                until => "sms_time < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day)",
                username => "username = ?",
                smsc_name=> "smsc_name like concat('%',?,'%')",
                member_name=> "member_name like concat('%',?,'%')",
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

	$sql .= "\norder by sms_id desc";
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

