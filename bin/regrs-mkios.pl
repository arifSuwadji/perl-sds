#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use CGI::Enurl;
use LWPx::ParanoidAgent;
use DBIx::Simple();
use Data::Dumper;
use common;

while (1) {
	my $db = daemon::db_connect();

	my $res = $db->query(<<"EOS");
SELECT rs_req_id, rs_req_number, sd_number, rs_req_response, pin, modem
  pin, site_url
FROM rs_request 
  inner join sd_chip using (sd_id)
  inner join site using (site_id)
WHERE rs_req_status='W' and ref_type_id = 2
EOS
	while (my $row = $res->hash) {
		daemon::warn("row: ", Dumper($row));

		my $msisdn = $row->{rs_req_number};
		$msisdn =~ s/62// if $msisdn =~ /^62/;
		
		my $ts = common::now();
		#cmd = *772*1*nomor_rs*pin_sd*1#;
		my $cmd = "*"."772*1*"."*".$msisdn."*".$row->{pin}."*1#"; 
		my $url = 'ussd?' . enurl({
			cmd => $cmd,
			modem => $row->{modem},
			ts => $ts,
		});

		$url = $row->{site_url}."/send".$url."&username=app1&password=1234";
		daemon::warn($url);

		# hit jj
		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^10\./ ,qr/^192\./, '127.0.0.1');
		$ua->timeout(10);

		my $resp = $ua->get($url);
		daemon::warn($resp->status_line, ' : ', $resp->content);
		
		unless($resp->is_success) {
                        my $resp_msg = $resp->status_line.', '.$resp->content;
                        $db->update("rs_request", {rs_req_status=>'F', rs_req_ts=>$ts, rs_req_response => $resp_msg}, {rs_req_id => $row->{rs_req_id}});
                        next;
                }
		if ($resp->is_success) {
                        $db->update("rs_request", {rs_req_status=>'P', rs_req_ts=>$ts}, {rs_req_id=>$row->{rs_req_id}});
                }
		sleep 1;
	}
}
