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
SELECT perdana_id, perdana_number from msisdn_perdana
WHERE status='Approve'
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed: ', Dumper($row));

		my ($modem_id, $modem_name, $pin) = $db->query(
			"select modem_id, modem_name, pin from modem where status = 'Active' order by rand() limit 1"
		)->list;
		unless ($modem_id){
			daemon::warn("no-modem selected");
			next;
		}
		#check sms format
		my $search_number = substr($row->{perdana_number},2);
		daemon::warn("search number : ", $search_number);
		my $sms_format = $db->query("select sms_int from sms where sms_int like '%$search_number%' order by sms_id desc")->list;
		daemon::warn("sms : ", $sms_format);
		my @msg = split /\./, $sms_format;
		my ($type, $cmd, $receiver) = $db->query("select type, command, receiver from perdana_cmd where cmd_name=?",$msg[0])->list;
		$cmd =~ s/no_hp/$row->{perdana_number}/;
		$cmd =~ s/pin/$pin/;
		print "command = ",$cmd;
		my $out_ts  = common::now();
		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^192\./, '10.221.1.101');
		$ua->timeout(10);
		my $url;
		if ($type eq 'sms'){
		$url = 'http://10.221.1.101:59194/service/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $modem_name,
			text     => $cmd,
			to       => $receiver,
			ts       => $out_ts,
		});
		} else {
		$url = 'http://10.221.1.101:59194/service/sendussd?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $modem_name,
			cmd      => $cmd,
			ts       => $out_ts,
		});
		}
		daemon::warn('url: ', $url);
		my $resp = $ua->get($url);
		daemon::warn('resp: ', $resp->status_line, ' : ', $resp->content);
		my $out_status = $resp->is_success ? 'S' : 'F';
#		if ($resp->is_success) {
			$db->query('update msisdn_perdana set status="wait-Response" where perdana_id=?',$row->{perdana_id});
#		}
	#	$db->update('sms_outbox',
	#@		{smsc_id => $smsc_id, out_status => $out_status},
	#		{user_id => '12', out_ts => $out_ts},
	#	);
	}

	$db->disconnect;
	sleep 1;
}

