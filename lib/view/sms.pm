package view::sms;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub list {
	my ($s,$q,$db,$log) = @_;
	my $from = $q->param('from');
	my $until = $q->param('until');
	my $list = $s->q_pager(<<'EOS',
select sms_id, smsc.smsc_name, sms_int, user.username, member_name, outlet_name,
  out_msg, sms_time, sms_localtime, out_status, out_ts, out_status,
  smsc2.smsc_name as smsc_outbox_name, user2.username as sms_outbox_username
from sms
  inner join smsc using (smsc_id)
  inner join user using (user_id)
  left join member using (member_id)
  left join outlet using (outlet_id)
  left join sms_outbox using (sms_id)
  left join smsc smsc2 on smsc2.smsc_id = sms_outbox.smsc_id
  left join user user2 on user2.user_id = sms_outbox.user_id
EOS
		filter => {
			from => "date(sms_localtime) >= str_to_date(?,'%d-%m-%Y')",
			until => "date(sms_localtime) <= str_to_date(?,'%d-%m-%Y')",		
			member_name => "member_name like concat(?, '%')",
			outlet_name => "outlet_name like concat(?, '%')",
			username => "user.username like concat(?,'%')",
			smsc_name=> "smsc.smsc_name like concat(?,'%')",	
		},
		suffix => 'order by sms_id desc',
	);

	return {
		r_args=> $s->{r}->args,
		from => $from,
		until => $until,
		username => $q->param('username')||'',
		member_name => $q->param('member_name')||'',
		outlet_name => $q->param('outlet_name')||'',
		smsc_name=> $q->param('smsc_name')||'',
		list_sms => $list->{list},
		nav => $list->{nav}
	};
}

sub detail_report {
	my ($s,$q,$db,$log) = @_;
	my $sms_id = $q->param('sms_id');
	my ($sms_in, $sms_out, $msisdn ) = $db->query(
		'select sms_int, out_msg, username from sms inner join user using(user_id) inner join member using(member_id) inner join sms_outbox using (sms_id) where sms_id=?', $sms_id,
	)->list;
	return {
		sms_id => $sms_id,
		sms_in => $sms_in,
		sms_out => $sms_out,
		msisdn => $msisdn,
	}
}

1;

# vim: ts=4
