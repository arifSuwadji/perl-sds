#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use config;
use daemon;
use config;
use Data::Dumper;
use LWPx::ParanoidAgent;
use LWP::UserAgent::Paranoid;
use LWP::UserAgent;
use HTTP::Response;
use CGI::Enurl;

my $ua = LWP::UserAgent->new();
$ua->ssl_opts(verify_hostname => 0);
#$ua->resolver->whitelisted_hosts(qr/^10\./ ,qr/^192\./, '127.0.0.1');

sub getUrl {
    my $url = shift;
    my $response;
    eval {
        local $SIG{ALRM} = sub { die "590 timeout"; };
        alarm 20;
        $response = $ua->get($url);
        alarm 0;
    };

    if ($@ && $@ =~ /590 timeout/) {
    print ("Execution Timeout !!!");
        return HTTP::Response->new(590, "Execution Timeout"); # return false on a timeout.
    }

    return $response;
}

while (1) {
	my $db = daemon::db_connect();

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
SELECT user_id, out_ts, out_msg, username, member_id
FROM sms_outbox INNER JOIN user using (user_id)
WHERE out_status='W' and user_id != $config::reg_user_id
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed: ', Dumper($row));
		my $user_id = $row->{user_id};
		my $out_ts  = $row->{out_ts};
		my $site_id = 1;
		my $site_url;

		($site_id, $site_url) = $db->query("select site_id, site_url from site inner join member using (site_id) where member_id=?", $row->{member_id})->list if ($row->{member_id});

		my ($smsc_id, $smsc_name) = $db->query(
			"select smsc_id, smsc_name from smsc where smsc_status='active' and site_id=? and smsc_type='sender' and smsc_id not in(1,7,8) order by rand() limit 1", $site_id
		)->list;
		if($config::use_smsc){
			($smsc_id, $smsc_name) = $db->query(
				"select smsc_id, smsc_name from smsc where smsc_status='active' and site_id=? and smsc_type='sender' order by rand() limit 1", $site_id
			)->list;
		}

		daemon::warn('smsc_id ; ', $smsc_id || '');
		daemon::warn('smsc_name ; ', $smsc_name || '');
		unless ($smsc_id){
		sleep 1;
		($smsc_id, $smsc_name) = $db->query(
		"select smsc_id, smsc_name from smsc where smsc_status='active' and site_id=5 and smsc_type='sender' limit 1")->list;
		
		daemon::warn('smsc_name-2 ; ', $smsc_name || '');
		}

		#my $ua = LWP::UserAgent::Paranoid->new(request_timeout => 45);
		#$ua->ssl_opts(verify_hostname => 0);
		#$ua->resolver->whitelisted_hosts(qr/^10\./ ,qr/^192\./, '127.0.0.1');

		#my $ua = LWPx::ParanoidAgent->new;
		#$ua->whitelisted_hosts(qr/^10\./ ,qr/^192\./, '127.0.0.1');
		#$ua->timeout(10);

		# my $url = $row->{url}."im/send_msg?". enurl ({

		my $url = $site_url.'/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $smsc_name,
			text     => $row->{out_msg},
			to       => $row->{username},
			ts       => $out_ts,
		});
		daemon::warn('url: ', $url);
		#my $resp = $ua->get($url);
		my $resp = getUrl($url);
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

