#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use Data::Dumper;
use LWPx::ParanoidAgent;
use CGI::Enurl;


while (1) {
	my $db = daemon::db_connect();

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
SELECT out_ts, out_msg, rs_number, rs_id, site_id
FROM sms_outbox_rs INNER JOIN rs_chip using (rs_id) inner join sd_chip using(sd_id)
WHERE out_status='W'
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed: ', Dumper($row));
		my $rs_id = $row->{rs_id};
		my $out_ts  = $row->{out_ts};

		my ($smsc_id, $smsc_name) = $db->query(
			"select smsc_id, smsc_name from smsc where smsc_status='active' and smsc_type='sender' and site_id=? order by rand() limit 1",$row->{site_id}
		)->list;

		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^10\./ ,qr/^192\./, '127.0.0.1');
		$ua->timeout(10);

		my $url = 'http://10.0.0.201:59194/service/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $smsc_name,
			text     => $row->{out_msg},
			to       => $row->{rs_number},
			ts       => $out_ts,
		});
		daemon::warn('url: ', $url);
		my $resp = $ua->get($url);
		daemon::warn('resp: ', $resp->status_line, ' : ', $resp->content);
		my $out_status = $resp->is_success ? 'S' : 'F';

		$db->update('sms_outbox_rs',
			{smsc_id => $smsc_id, out_status => $out_status},
			{rs_id => $rs_id, out_ts => $out_ts},
		);
	}

	$db->disconnect;
	sleep 1;
}

