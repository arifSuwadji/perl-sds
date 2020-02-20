package view::sms_rs;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub list {
	my ($s,$q,$db,$log) = @_;
	my $from = $q->param('from');
	my $until = $q->param('until');
	my $list = $s->q_pager(<<'EOS',
select sms_rs_id, in_smsc.smsc_name as in_smsc_name, sms_int, 
sms_out, out_smsc.smsc_name as out_smsc_name, rs_number, sms_time
from sms_rs
  inner join smsc as in_smsc on in_smsc.smsc_id = sms_rs.in_smsc_id
  left join smsc as out_smsc on out_smsc.smsc_id = sms_rs.out_smsc_id
  inner join rs_chip using (rs_id)
EOS
	 filter => {
		from => "date(sms_time) >= str_to_date(?,'%d-%m-%Y')",
		until => "date(sms_time) <= str_to_date(?,'%d-%m-%Y')",		
                rs_number => "rs_number =?",
		in_smsc_name => "in_smsc.smsc_name like concat(?,'%')",
		out_smsc_name => "out_smsc.smsc_name like concat(?,'%')",
	},
	suffix => 'order by sms_rs_id desc',
	);
	return {
		r_args=> $s->{r}->args,
		from => $from,
		until => $until,
		rs_number => $q->param('rs_number')||'',
		in_smsc_name=> $q->param('in_smsc_name')||'',
		out_smsc_name=> $q->param('out_smsc_name')||'',
		list => $list->{list},
		nav => $list->{nav},
	};
}

sub detail_report_sms {
	my ($s,$q,$db,$log) = @_;
	my $sms_rs_id = $q->param('sms_rs_id');
	my ($sms_in, $sms_out, $rs_number, $out_smsc_name, $in_smsc_name ) = $db->query(
		'select sms_int, sms_out, rs_number, out_smsc.smsc_name, in_smsc.smsc_name from sms_rs inner join rs_chip using(rs_id) inner join smsc as in_smsc on in_smsc.smsc_id = sms_rs.in_smsc_id left join smsc as out_smsc on out_smsc.smsc_id = sms_rs.out_smsc_id where sms_rs_id=?', $sms_rs_id,
	)->list;
	return {
		sms_rs_id => $sms_rs_id||0,
		sms_in => $sms_in||'',
		sms_out => $sms_out||'',
		rs_number => $rs_number||'',
		out_smsc_name => $out_smsc_name||'',
		in_smsc_name => $in_smsc_name||'',
	}
}

1;
