#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use config;
use daemon;
use Data::Dumper;
use LWPx::ParanoidAgent;
use CGI::Enurl;


while (1) {
	my $db = daemon::db_connect();

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
SELECT user_id, out_ts, out_msg, username
FROM sms_outbox INNER JOIN user using (user_id)
WHERE out_status='W' and user_id = $config::reg_user_id
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed: ', Dumper($row));
		my $user_id = $row->{user_id};
		my $out_ts  = $row->{out_ts};

		my ($smsc_id, $smsc_name) = $db->query(
			"select smsc_id, smsc_name from smsc where smsc_status='active' order by rand() limit 1"
		)->list;
		my ($nomor) = ($row->{out_msg} =~ /nomor (\d+) /);
		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^192\./, '10.221.1.101');
		$ua->timeout(10);

		my $url = 'http://10.221.1.101:59194/service/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $smsc_name,
			text     => $row->{out_msg},
			to       => $nomor,
			ts       => $out_ts,
		});
		daemon::warn('url: ', $url);
		my $resp = $ua->get($url);
		daemon::warn('resp: ', $resp->status_line, ' : ', $resp->content);
		my $out_status = $resp->is_success ? 'S' : 'F';

		$db->update('sms_outbox',
			{smsc_id => $smsc_id, out_status => $out_status},
			{user_id => $user_id, out_ts => $out_ts},
		);
	}

	$db->disconnect;
	sleep 1;
}

