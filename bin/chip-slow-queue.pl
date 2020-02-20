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
	open(my $FH, '-|', 'ps x|egrep \'\.\/(mkios|dompul)\.pl \[\'|wc');
	my $mkios_procs;
	while (<$FH>) {
    	chomp; $mkios_procs = $_;
	}
	close $FH;
	($mkios_procs) = ($mkios_procs =~ /(\d+)/);

	my $limit = int(40-$mkios_procs);
	unless ($limit) {
		$db->disconnect;
		sleep 5; next;
	}

	my $res = $db->query(<<"__eos__");
SELECT topup_id, topup_ts, trans_id, exec_ts, stock_ref.ref_type_id
FROM topup
  inner join stock_ref using (stock_ref_id)
  inner join rs_chip using (rs_id)
  inner join sd_chip using (sd_id)
  inner join site using (site_id)
WHERE topup_status='W'
  AND exec_ts>0 and exec_ts<=now()
ORDER BY rand()
LIMIT $limit
__eos__

	my $pua = HTTP::Async->new(timeout => 1, slots => 40);
	my @top;
	while(my($topup_id, $topup_ts, $trans_id, $exec_ts, $ref_type_id) = $res->list){
		my $url = "http://localhost:".(62000+$ref_type_id)."/topup/".$topup_id;
		push @top, {topup_id => $topup_id, url => $url};
		$pua->add( HTTP::Request->new(GET => $url));
	}
	$db->disconnect;
	unless(scalar @top){
		sleep 7; next;
	}
	daemon::warn("busy topup processes : ", $mkios_procs);
	daemon::warn("sending ", scalar(@top), "request in parallel");

	#triger
	#in the future, 'localhost' shouldn't be hard-coded
	while( my($resp, $id) = $pua->wait_for_next_response ){
		my $url = $top[$id-1]->{url};
		daemon::warn($url, ": ", $resp->status_line);
	}
	
	sleep 5;
}

