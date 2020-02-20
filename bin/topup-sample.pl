#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use config;
use daemon;
use daemon::trx;
use Data::Dumper;
use Math::Round qw(nearest);


sub early_validation {
	my ($member, $row, $db) = @_;

	# canvaser utk chip ini blm diset
	my $rs_mem_id = $row->{rs_chip_member_id};
	return 'nomor chip RS tidak valid' unless $rs_mem_id;

	# status member harus aktif, jika tidak .....
	return 'member tidak aktif' unless $member->{status} eq 'Active';

	# sesama canvaser jangan saling serobot
	if ($config::free_canvasser) {
		$rs_mem_id = $db->query(
			"select member_id from topup ".
			"where topup_status in ('W','P','S') and rs_id=?".
			"  and topup_ts>=curdate() limit 1",
			$row->{rs_id},
		)->list || $member->{member_id};
	}
	return 'member bukan canvaser dari chip RS' if $member->{member_id} != $rs_mem_id;

	# ada quota utk suatu stock reference
	return 'quantity melebihi quota' if $row->{nominal} and $row->{topup_qty} > $row->{max_qty};

	# NO ERROR !!
	return undef;
}

sub pricing_validation {
	my ($member, $row, $db, $outlet) = @_;

	# stock_ref.nominal = 0 berarti nominal based : 
	# - perhitungan mutasi saldo berbasis discount
	# - bukan berbasis pricing seperti di unit based
	#
	my $price =  $db->query(
		'select price from outlet_pricing where stock_ref_id=? and outlet_type_id=?',
		$row->{stock_ref_id}, $outlet->{outlet_type_id},
	)->list;

	if($config::take_price){
		$price =  $db->query(
			'select price from pricing inner join stock_ref using(stock_ref_id) where stock_ref_id=? and rs_type_id=?',
			$row->{stock_ref_id}, $row->{rs_type_id},
		)->list;
	}
	# harga blm diset / record not found
	return 'harga belum diset' unless defined($price) or $row->{ref_type_id} == 9;

	my $total_price;

	if ($row->{nominal}) {
		return 'harga per unit belum diset' unless $price; # Rp 0 ?
 		$total_price = $price * $row->{topup_qty};
	}
	elsif ($row->{ref_type_id} == 9) {
		$total_price = $row->{topup_qty};
	}
	else {
		return 'angka diskon tidak valid' if $price > 50;
		$total_price = nearest( 0.01, (1-$price/100) * $row->{topup_qty} );
	}

	# saldo cukup ?
	if ($row->{credit} == 0) { # cash
		return 'saldo tdk mencukupi' if $total_price > $member->{member_balance};
	}
	else { # credit
		return 'limit utang outlet melebihi plafon'
			if $total_price > $outlet->{plafond} + $outlet->{balance} ;
	}

	# NO ERROR, SIR !!
	$row->{total_price} = $total_price;
	return undef;
}


while (1) {
	my $db = daemon::db_connect();

	# ambil record2 yg sudah diantrikan.
	# record2 tsb selanjutnya bisa menjadi transaksi riil, atau juga "tidak ter-approve"
	my $res = $db->query(<<"__eos__");
SELECT topup_id, topup.member_id as topup_member_id, topup_qty, stock_ref_id, rs_id, mapping,
  rs_type_id, rs_chip.member_id as rs_chip_member_id, sd_id, max_qty, nominal,
  ref_type_id, outlet_id, credit, date(topup_ts) as inv_date
FROM topup
  LEFT JOIN rs_chip using (rs_id)
  INNER JOIN stock_ref using (stock_ref_id)
  INNER JOIN stock_ref_type using (ref_type_id)
WHERE topup_status=''
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed: ', Dumper($row));
		my $sd_id = $row->{sd_id};

		$db->begin();

		my $topup_id = $db->query(
			"select topup_id from topup where topup_id=? and topup_status='' FOR UPDATE",
			$row->{topup_id},
		)->list;

		# jika ternyata topup-status telah berubah
		unless ($topup_id) {
			$db->rollback();
			daemon::warn('topup record has changed. rolled back.');
			next;
		}

		# siap2 bertransaksi
		my $trx    = daemon::trx->new($db, $topup_id);
		my $member = $trx->lock_member($row->{topup_member_id});
		my $outlet = $trx->lock_outlet($row->{outlet_id});


		# Serangkaian validasi
		# =====================
		#
		# masing2 jenis trx gtw (sms, web, h2h),
		# hanya bertugas mengantarkan message dari user/admin, sampai ke table topup
		# bersesuaian dg constraint2/foreign key/tipe data shg
		# data2 dari: nomor rs, stock-ref, topup-qty sudah benar/valid.
		#

		my $err_msg = early_validation($member, $row, $db);
		if ($err_msg) {
			$trx->error_msg($err_msg);
			$db->commit();
			next;
		}

		# cek harga
		$err_msg = pricing_validation($member, $row, $db, $outlet);
		if ($err_msg) {
			$trx->error_msg($err_msg);
			$db->commit();
			next;
		}

		# cek stok
		# menambahkan kondisi untuk nilai stock virtual untuk H2H
		my $stockrefid;
		my $topupqty;
		
		if($row->{mapping}) {
			$stockrefid = $row->{mapping};
			$topupqty = $row->{topup_qty} * $row->{nominal};
		} else {
			$stockrefid = $row->{stock_ref_id};
			$topupqty = $row->{topup_qty};
		}

		my ($stock_id, $stock_qty, $exec_ts) = $db->query(<<"---EOS---"
select sd_stock_id, qty,
  if(
    last_topup < date_sub(now(), interval 10 second),
    now(), date_add(last_topup, interval 10 second)
  ) as new_ts
from sd_stock inner join sd_chip using (sd_id)
where sd_id=? and stock_ref_id=? FOR UPDATE
---EOS---
			, $sd_id, $stockrefid,
		)->list;

		daemon::warn("topupqty:",$topupqty," stockrefid:",$stockrefid);
		unless ($stock_qty and $stock_qty >= $topupqty) {
			$trx->error_msg('stok tdk mencukupi/tersedia');
			$db->commit();
			next;
		}

		# the REAL transaction begins
		# ===========================
		my $outlet_id = $outlet->{outlet_id};
		my $inv_date  = $row->{inv_date};
		my $period    = $outlet->{period};
		my $invStatus = 'Unpaid';
		my $pay_trxid = undef;
		my $loan      = 1;

		$trx->trx('top'); # type of transaction: TOPUP

		# outlet or canvasser mutation
		if ($row->{credit} == 0) { # cash
			$trx->mutation(-$row->{total_price}, $member);
			$period    = 0;
			$invStatus = 'Paid';
			my $payTrx = daemon::trx->new($db);
			$pay_trxid = $payTrx->trx('paid_cash');
			$loan      = 0;
		}
		else { # credit
			if ($period < 1) {
				$trx->error_msg('outlet tdk diperbolehkan berhutang');
				$db->commit();
				next;
			}

			$trx->outlet_mutation(-$row->{total_price}, $outlet);
		}

		# find or create invoice record
		my ($inv_id, $amount, $debt) = $db->query(
			'select inv_id, amount, debt from invoice where inv_date=? and outlet_id=? and debt=?',
			$inv_date, $outlet_id, $loan,
		)->list;
		unless ($inv_id) {
			$db->insert('invoice', {
				inv_date  => $inv_date,
				outlet_id => $outlet_id,
				due_date  => \["date_add(?, interval ? day)", $inv_date, $period],
				amount    => $row->{total_price},
				status    => $invStatus,
				trans_id  => $pay_trxid,
				member_id => $member->{member_id},
				debt      => $loan,
			} );
			$inv_id = $db->last_insert_id(0,0,0,0);
		}
		else {
			# invoice has already existed, update its amount!
			$db->update('invoice',
				{ amount => $amount+$row->{total_price} }, {inv_id => $inv_id, debt => $debt} );
		}

		# stock_mutation
		my $topup_qty;
		if($row->{mapping}) {
		 	$topup_qty = $row->{topup_qty} * $row->{nominal};
		} else {
			$topup_qty = $row->{topup_qty};
		}
		my $new_qty   = $stock_qty - $topup_qty;

		$db->update('sd_stock', {qty => $new_qty},
			{sd_id => $sd_id, stock_ref_id => $row->{stock_ref_id}},
		);

		$db->insert('stock_mutation', {
			sm_ts => \['now()'],
			trans_id => $trx->trans_id, sd_stock_id => $stock_id,
			trx_qty => -$topup_qty, stock_qty => $new_qty,
		});

		# prepare schedule for next topup
		$db->update('sd_chip',
			{last_topup => $exec_ts}, {sd_id => $sd_id},
		);

		# topup document/queue approved
		$db->update('topup',
			{
				topup_status => 'W',
				inv_id => $inv_id,
				trans_id => $trx->{trans_id},
				exec_ts => $exec_ts,
			},
			{topup_id => $topup_id}
		);
		# selanjutnya, masing2 stock/SCM gtw (dompul.pl, mkios.pl, dll) yg meneruskan

		$db->commit();
	}

	$db->disconnect;
	sleep 1;
}
