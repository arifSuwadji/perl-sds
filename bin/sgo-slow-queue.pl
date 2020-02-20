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
	open(my $FH, '-|', 'ps x|egrep \'\.\/sgo-mandiri\.pl \[\'|wc');
	my $sgo_procs;
	while (<$FH>) {
    	chomp; $sgo_procs = $_;
	}
	close $FH;
	($sgo_procs) = ($sgo_procs =~ /(\d+)/);

	my $limit = int(40-$sgo_procs);
	unless ($limit) {
		$db->disconnect;
		sleep 5; next;
	}

	my $res = $db->query(<<"__eos__");
SELECT outlet_mutation.outlet_id, group_concat(outlet_mutation.trans_id), topup.member_id, transaction.trans_date
FROM outlet_mutation 
inner join transaction on transaction.trans_id = outlet_mutation.trans_id
left join topup on topup.trans_id = transaction.trans_id
left join transaction as trans on trans.trans_ref = transaction.trans_id 
inner join rs_chip using(rs_id)
inner join outlet on outlet.outlet_id = rs_chip.outlet_id
WHERE topup_status in('WT','CT') AND exec_ts>0 and exec_ts<=now() group by outlet_id,trans_date
ORDER BY topup_id
LIMIT $limit
__eos__

	my $pua = HTTP::Async->new(timeout => 1, slots => 40);
	my @trans;
	while(my($outlet_id, $trans_id, $member_id, $trans_date) = $res->list){
		my $url = "http://localhost:63200/trans/".$trans_id;
		push @trans, {trans_id => $trans_id, url => $url};
		$pua->add( HTTP::Request->new(GET => $url));
	}
	$db->disconnect;
	unless(scalar @trans){
		sleep 7; next;
	}
	daemon::warn("busy topup processes : ", $sgo_procs);
	daemon::warn("sending ", scalar(@trans), " request in parallel");

	#triger
	#in the future, 'localhost' shouldn't be hard-coded
	while( my($resp, $id) = $pua->wait_for_next_response ){
		my $url = $trans[$id-1]->{url};
		daemon::warn($url, ": ", $resp->status_line);
	}
	
	sleep 10;
}

