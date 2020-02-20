#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use common;
use daemon;
my $db = daemon::db_connect();

# semua tagihan yg sdh jatuh tempo & belum lunas
my $res = $db->query(<<"__eos__");
select invoice.outlet_id, sum(mutation), group_concat(inv_id)
from outlet_mutation inner join topup using (trans_id)
  inner join invoice using (inv_id)
where invoice.status='Unpaid' and due_date<=curdate()
group by invoice.outlet_id
__eos__

# insert into sms-inbox, menggunakan smsc-id = 1, user-id =1
$db->insert("sms", {
	sms_int => \["concat('|[ reminder ', curdate(), ' ]|')"],
	smsc_id => 1, sms_time => \['now()'],
	user_id => 1, sms_localtime => \['now()'],
} );
my $sms_id = $db->last_insert_id(0,0,0,0);

while (my ($outlet, $sum, $inv) = $res->list) {
	my ($user_id, $outlet_name) = $db->query(
		"select user_id, outlet_name ".
		"from user inner join outlet using (outlet_id) ".
		"where outlet_id=? and user.status='Active' limit 1", $outlet,
	)->list;
	next unless $user_id;

	# insert into sms-outbox
	daemon::warn("$outlet_name, outlet-id: $outlet, user-id: $user_id, sum: $sum, inv: $inv");
	$db->insert('sms_outbox', {
		sms_id => $sms_id, user_id => $user_id, out_ts => common::now(),
		out_msg => "Tagihan dg total berjumlah $sum dari invoice:$inv telah jatuh tempo. Terimakasih",
		out_status => 'W',
	});
}

$db->disconnect;

