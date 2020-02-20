#!/usr/bin/perl -lw
use warnings;
use strict;
use lib "$ENV{HOME}/lib";

use config;
use daemon;
use HTTP::Request;
use HTTP::Async;

for(1 .. 8640){
	my $db = daemon::db_connect();

	#check count topup.pl
	open(my $FH, '-|', 'ps x|egrep \'\.\/topup\.pl \[\'|wc');
	my $topup_procs;
	while (<$FH>) {
    	chomp; $topup_procs = $_;
	}
	close $FH;
	($topup_procs) = ($topup_procs =~ /(\d+)/);

	my $limit = int(40-$topup_procs);
	unless ($limit) {
		$db->disconnect;
		sleep 5; next;
	}

	my $res = $db->query(<<"__eos__");
SELECT topup_id, topup_ts, payment_gateway
FROM topup
  LEFT JOIN rs_chip using (rs_id)
  INNER JOIN stock_ref using (stock_ref_id)
  INNER JOIN stock_ref_type using (ref_type_id)
WHERE topup_status=''
ORDER BY topup_id
LIMIT $limit
__eos__

	my $pua = HTTP::Async->new(timeout => 1, slots => 40);
	my @top;
	while(my($topup_id, $topup_ts, $payment_gateway) = $res->list){
		my $url = "http://localhost:63101/topup/".$topup_id;
		push @top, {topup_id => $topup_id, url => $url};
		$pua->add( HTTP::Request->new(GET => $url));
	}
	$db->disconnect;
	unless(scalar @top){
		sleep 7; next;
	}
	daemon::warn("busy topup processes : ", $topup_procs);
	daemon::warn("sending ", scalar(@top), "request in parallel");

	#triger
	#in the future, 'localhost' shouldn't be hard-coded
	while( my($resp, $id) = $pua->wait_for_next_response ){
		my $url = $top[$id-1]->{url};
		daemon::warn($url, ": ", $resp->status_line);
	}
	
	sleep 5;
}

