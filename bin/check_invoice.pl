#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use config;
use daemon;
use daemon::trx;
use Data::Dumper;
use Math::Round qw(nearest);


while (1) {
	my $db = daemon::db_connect();

	# query for check invoice amount
	my $res = $db->query(<<"__eos__");
select outlet_id, outlet_name, mutation.trans_id, mutation.member_id, sum(-amount) as amount, trans.trans_ref, transaction.trans_date,
date(topup_ts) as inv_date, outlet_type_id, credit
from mutation 
inner join transaction on transaction.trans_id = mutation.trans_id
left join topup on topup.trans_id = transaction.trans_id
left join transaction as trans on trans.trans_ref = transaction.trans_id 
inner join rs_chip using(rs_id)
inner join outlet using (outlet_id)
where transaction.trans_date =curdate() and trans.trans_ref is null group by outlet_id
__eos__

	while (my $row = $res->hash) {
		$row->{amount} =~ s/\.\d+$//;
		# get invoice for outlet
		my ($inv_id, $inv_date, $outlet_id, $member_id, $trans_id, $amount) = 
		$db->query("select inv_id, inv_date, outlet_id, member_id, trans_id, amount 
		from invoice where inv_date=curdate() and outlet_id=?", $row->{outlet_id})->list;
		if($inv_id){
			if($row->{amount} ne $amount){
				daemon::warn('Data : ', Dumper($row));
				daemon::warn("inv id : ", $inv_id);
				daemon::warn("inv date : ", $inv_date);
				daemon::warn("inv outlet id : ", $outlet_id);
				daemon::warn("inv member id : ", $member_id);
				daemon::warn("inv trans : ", $trans_id);
				daemon::warn("inv amount : ", $amount);
				daemon::warn("real amount invoice : ", $row->{amount});
				$db->begin();
				$db->query("update invoice set amount=? where outlet_id=? and inv_date=curdate()",$row->{amount}, $outlet_id);
				$db->commit();
			}
		}else{
			daemon::warn("make invoice for outlet_id : ", $row->{outlet_id});
			my $inv_date = $row->{inv_date};
			my $period = $db->query(
				'select period from outlet_type where outlet_type_id=?',
				$row->{outlet_type_id} )->list;
			my $invStatus = 'Unpaid';
			my $pay_trxid = undef;
			my $loan      = 1;
			if ($row->{credit} == 0) { # cash
				$period    = 0;
				$invStatus = 'Paid';
				my $payTrx = daemon::trx->new($db);
				$pay_trxid = $payTrx->trx('paid_cash');
				$loan      = 0;
			}
			$db->insert('invoice', {
				inv_date  => $inv_date,
				outlet_id => $row->{outlet_id},
				due_date  => \["date_add(?, interval ? day)", $inv_date, $period],
				amount    => $row->{amount},
				status    => $invStatus,
				trans_id  => $pay_trxid,
				member_id => $row->{member_id},
				debt      => $loan,
			} );
			$inv_id = $db->last_insert_id(0,0,0,0);
			my $rs_id = $db->query("select rs_id from topup where trans_id=?", $row->{trans_id})->list;
			$db->query("update topup set inv_id=? where rs_id=? and topup_ts > curdate()", $inv_id, $rs_id);
		}
	}
	$db->disconnect;
	exit;
}
