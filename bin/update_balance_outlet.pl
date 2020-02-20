#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use Data::Dumper;
my $db = daemon::db_connect();

#for update balance outlet
my $res = $db->query(<<"__eos__");
SELECT rs_id,inv_id,rs_chip.outlet_id,outlet_name,inv_date,invoice.trans_id,amount,balance
FROM topup
INNER JOIN rs_chip using(rs_id)
INNER JOIN outlet using (outlet_id)
INNER JOIN invoice using (inv_id)
WHERE payment_gateway=1 AND topup_ts > now() - interval 1 day AND topup_ts < now() AND balance < 0
GROUP BY outlet_id
__eos__

while (my $row = $res->hash) {
	my $balance = $row->{balance} + $row->{amount};
	daemon::warn('update for outlet name : ', $row->{outlet_name} .' outlet id : '. $row->{outlet_id});
	$db->query("UPDATE outlet SET balance=? WHERE outlet_id=?", $balance, $row->{outlet_id});

	#insert outlet_mutation
	$db->insert('outlet_mutation',{
		outlet_id => $row->{outlet_id},
		trans_id  => $row->{trans_id},
		balance   => $balance,
		mutation  => $row->{amount},
	});
}

$db->disconnect;
