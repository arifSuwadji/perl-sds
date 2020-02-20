#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use common;
use daemon;
use Data::Dumper;
use LWPx::ParanoidAgent;
use CGI::Enurl;


while (1) {
	my $db = daemon::db_connect();

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
SELECT sms_rs_id, sms_out, rs_number
FROM sms_rs INNER JOIN rs_chip using (rs_id)
WHERE out_status='W'
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed: ', Dumper($row));
		my $out_ts  = common::now();

		my ($smsc_id, $smsc_name) = $db->query(
			"select smsc_id, smsc_name from smsc where smsc_status='active' and smsc_name <> ? order by rand() limit 1", $config::smsc)->list;

		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^192\./, '127.0.0.1');
		$ua->timeout(10);

		my $url = 'http://127.0.0.1:59194/service/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $smsc_name,
			text     => $row->{sms_out},
			to       => $row->{rs_number},
			ts       => $out_ts,
		});
		daemon::warn('url: ', $url);
		my $resp = $ua->get($url);
		daemon::warn('resp: ', $resp->status_line, ' : ', $resp->content);
		my $out_status = $resp->is_success ? 'S' : 'F';

		$db->update('sms_rs',
			{sms_out => $row->{sms_out}, out_status => $out_status, out_smsc_id => $smsc_id, sms_localtime => $out_ts,},
			{sms_rs_id => $row->{sms_rs_id}},
		);
		sleep 1;
	}

	$db->disconnect;
	sleep 1;
}

