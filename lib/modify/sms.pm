package modify::sms;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub send_answer {
        my ($s,$q,$db,$log) = @_;
	my $sms_out = $q->param('sms_out');
	my $sms_id = $q->param('sms_id');
	my $user_id = $db->query('select user_id from sms where sms_id=?', $sms_id)->list;
	#$db->begin;
	$db->insert("sms_outbox", {
		out_msg=>$sms_out, sms_id=>$sms_id, out_status=>'W',
		user_id=>$user_id, out_ts=>\['now()'],
	});
	#$db->rollback;
        return '/view/sms/list';
}

1;
