package modify::sms_rs;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub send_answer {
        my ($s,$q,$db,$log) = @_;
	my $sms_out = $q->param('sms_out');
	my $sms_rs_id = $q->param('sms_rs_id');
	my $rs_id = $db->query('select rs_id from sms_rs where sms_rs_id=?', $sms_rs_id)->list;
	$db->query("update sms_rs set sms_out=?, sms_localtime=now(), out_status='W' where sms_rs_id = ?", $sms_out, $sms_rs_id);
        return '/view/sms_rs/list';
}

1;
