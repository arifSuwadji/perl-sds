package misc::outlet;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

sub outlet_list{
	my ($s) = shift;

	my $outlet_name = $s->param('outlet_name') || '';
	my $rs_number = $s->param('rs_number') || '';
	my $sql = <<"__eos__",
		select outlet_id, outlet_name, group_concat(rs_number separator ';') as rs_numbers, address, district, sub_district, pos_code, owner,
		concat(mobile_phone,',',username) as mobile_phone, user.pin, type_name, format(plafond,0) as plafond, 
		format(balance,0) as balance, date_format(curdate(),'%d-%m-%Y') as date_from, date_format(curdate(),'%d-%m-%Y') as until,
		member_name, concat(sd_name,'[',sd_number,']') as sub_master
from outlet 
		left join rs_chip using(outlet_id)
		inner join sd_chip using(sd_id)
		inner join member using (member_id)
		inner join outlet_type using (outlet_type_id)
		left join user using (outlet_id)
__eos__
	
	my %param  = (
		outlet_name => "outlet_name like concat(?,'%')",
		rs_number => "rs_number like concat(?,'%')",
		member_name => "member_name like concat(?,'%')",
		status => "outlet.status like concat(?,'%')",
		sub_district => "sub_district like concat(?,'%')",
		district => "district like concat (?,'%')",
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
	$sql .= "\n group by outlet_id ";
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
