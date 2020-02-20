#!/usr/bin/perl -l
package MyPackage;
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use config;
use daemon;
use daemon::trx;
use Data::Dumper;
use Math::Round qw(nearest);
use base qw(Net::Server::PreFork);


sub early_validation {
	my ($member, $row, $db) = @_;

	# canvaser utk chip ini blm diset
	my $rs_mem_id = $row->{rs_chip_member_id};
	return 'nomor chip RS tidak valid' unless $rs_mem_id;

	# status rs chip
	return 'nomor RS tidak aktif' if $row->{rs_status} ne 'Active';

	# status member harus aktif, jika tidak .....
	if($row->{payment_gateway} eq 0){#normal trx
		return 'member tidak aktif' unless $member->{status} eq 'Active';
	}

	# sesama canvaser jangan saling serobot
	if ($config::free_canvasser) {
		$rs_mem_id = $db->query(
			"select member_id from topup ".
			"where topup_status in ('W','P','S') and rs_id=?".
			"  and topup_ts>=curdate() limit 1",
			$row->{rs_id},
		)->list || $member->{member_id};
	}
	unless ($config::topup_web_empty){
	if ($member->{member_id} != $rs_mem_id){
	return 'member bukan canvaser dari chip RS';# if $member->{member_id} != $rs_mem_id){
	}};

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
		if($row->{payment_gateway} eq 0){#normal trx
			return 'saldo tdk mencukupi' if $total_price > $member->{member_balance};
		}
	}
	else { # credit
		return 'limit utang outlet melebihi plafon'
			if $total_price > $outlet->{plafond} + $outlet->{balance} ;
	}

	# NO ERROR, SIR !!
	$row->{total_price} = $total_price;
	return undef;
}

sub quota_rs_validation {
	my ($member, $row, $db, $total_trx) = @_;

	my $rs_id = $row->{rs_id};
	my $stock_ref_id = $row->{stock_ref_id};
	my $topup_qty = $row->{topup_qty};
	my $keyword = $row->{keyword};
	my $rs_number = $row->{rs_number};
	my $quota_rs_denom = $db->query('SELECT quota FROM rs_stock WHERE rs_id=? and stock_ref_id=?', $rs_id, $stock_ref_id)->list || 0;
	if($quota_rs_denom > 0){
		return "Request $keyword=$topup_qty ke rs $rs_number gagal, Quota RS denom tidak mencukupi" if $topup_qty > $quota_rs_denom;
	}
	my ($quota_rs_nominal, $last_balance_nominal, $quota_rs_qty, $last_balance_qty) = $db->query('SELECT rs_nominal_quota, rs_balance_nominal, rs_qty_quota, rs_balance_qty FROM rs_chip WHERE rs_id=?',$rs_id)->list;
	if($quota_rs_nominal > 0){
		$last_balance_nominal += $total_trx;
		return "Request $keyword=$topup_qty ke rs $rs_number gagal, Quota Nominal RS tidak mencukupi" if $last_balance_nominal > $quota_rs_nominal;
		$db->query("UPDATE rs_chip SET rs_balance_nominal=? WHERE rs_id=?", $last_balance_nominal, $rs_id);
	}
	if($quota_rs_qty > 0){
		$last_balance_qty += $topup_qty;
		return "Request $keyword=$topup_qty ke rs $rs_number gagal, Quota Qty RS tidak mencukupi" if $last_balance_qty > $quota_rs_qty;
		$db->query("UPDATE rs_chip SET rs_balance_qty=? WHERE rs_id=?", $last_balance_qty, $rs_id);
	}

	# NO ERROR, SIR !!
	return undef;
}

sub quota_outlet_validation {
	my ($member, $row, $db, $outlet) = @_;

	my $rs_id = $row->{rs_id};
	my $stock_ref_id = $row->{stock_ref_id};
	my $topup_qty = $row->{topup_qty};
	my $keyword = $row->{keyword};
	my $rs_number = $row->{rs_number};
	my $quota_outlet_denom = $db->query('SELECT quota FROM outlet_quota WHERE outlet_id=? and stock_ref_id=?', $outlet->{outlet_id}, $stock_ref_id)->list || 0;
	if($quota_outlet_denom > 0){
		return "Request $keyword=$topup_qty ke rs $rs_number gagal, Quota Outlet denom tidak mencukupi" if $topup_qty > $quota_outlet_denom;
	}
	if($outlet->{nominal_quota} > 0){
		my $sum_balance_rs_nominal = $db->query('SELECT sum(rs_balance_nominal) FROM rs_chip WHERE outlet_id=?', $outlet->{outlet_id})->list || 0;
		return "Request $keyword=$topup_qty ke rs $rs_number gagal, Quota Nominal Outlet tidak mencukupi" if $sum_balance_rs_nominal > $outlet->{nominal_quota};
		$db->query('UPDATE outlet SET balance_nominal=? WHERE outlet_id=?', $sum_balance_rs_nominal, $outlet->{outlet_id});
	}
	if($outlet->{qty_quota} > 0){
		my $sum_balance_rs_qty = $db->query('SELECT sum(rs_balance_qty) FROM rs_chip WHERE outlet_id=?', $outlet->{outlet_id})->list || 0;
		daemon::warn("sum balance : ",$sum_balance_rs_qty," qty quota : ", $outlet->{qty_quota});
		if($sum_balance_rs_qty > 0){
			return "Request $keyword=$topup_qty ke rs $rs_number gagal, Quota Qty Outlet tidak mencukupi" if $sum_balance_rs_qty > $outlet->{qty_outlet};
		}
		$db->query('UPDATE outlet SET balance_qty=? WHERE outlet_id=?',$sum_balance_rs_qty, $outlet->{outlet_id});
	}

	# NO ERROR, SIR !!
	return undef;
}

MyPackage->run({port => 63101, min_servers => 3});

sub process_request{
	my $self = shift;
	eval {

		local $SIG{'ALRM'} = sub { die "Timed Out!\n" };
		my $timeout = 30; # give the user 30 seconds to type some lines

		my $line = <STDIN> || die "no data";
		$line =~ s/[\r\n]+$//;
		if ($line !~ /^ (\w+) \ + (\S+) \ + (HTTP\/1.\d) $ /x) {
			die "Bad request";
		}

		my ($method, $req, $protocol) = ($1, $2, $3);
		print STDERR join(" ", $self->log_time, $method, $req)."\n";

		#GET Topup id
		my ($topup_id) = ($req =~ /\/(\d+)/);

		my $db = daemon::db_connect();

		# ambil record2 yg sudah diantrikan.
		# record2 tsb selanjutnya bisa menjadi transaksi riil, atau juga "tidak ter-approve"
		my $res = $db->query(<<"__eos__", $topup_id);
SELECT topup_id, topup.member_id as topup_member_id, topup_qty, stock_ref_id, rs_id, rs_number, rs_chip.status as rs_status, keyword, mapping,
  rs_type_id, rs_chip.member_id as rs_chip_member_id, sd_id, max_qty, nominal,
  ref_type_id, outlet_id, credit, date(topup_ts) as inv_date, payment_gateway
FROM topup
  LEFT JOIN rs_chip using (rs_id)
  INNER JOIN stock_ref using (stock_ref_id)
  INNER JOIN stock_ref_type using (ref_type_id)
WHERE topup_id=?
__eos__

		while (my $row = $res->hash) {
			daemon::warn('Data Process : ', Dumper($row));
			process_row($db, $row);
		}
		$db->disconnect;
	};

	if ($@ =~ /timed out/i) {
		print STDOUT "Timed Out.\r\n";
		return;
	}
}

sub process_row{
		my($db, $row) = @_;

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

		#get price for quota
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
		my $total_trx = $row->{topup_qty} * $price;
		if($config::need_check_quota){
			# quota rs validation
			$err_msg = quota_rs_validation($member, $row, $db, $total_trx);
			if($err_msg){
				$trx->error_msg($err_msg);
				my $last_balance_nominal = $db->query('SELECT rs_balance_nominal FROM rs_chip WHERE rs_id=?',$row->{rs_id})->list;
				if($err_msg =~ /, Quota Qty/){
					$last_balance_nominal -= $total_trx;
					$db->query("UPDATE rs_chip SET rs_balance_nominal=? WHERE rs_id=?", $last_balance_nominal, $row->{rs_id});
				}
				$db->commit();
				next;
			}

			#quota outlet validation
			$err_msg = quota_outlet_validation($member, $row, $db, $outlet);
			if($err_msg){
				$trx->error_msg($err_msg);
				my ($last_balance_nominal, $last_balance_qty) = $db->query('SELECT rs_balance_nominal, rs_balance_qty FROM rs_chip WHERE rs_id=?',$row->{rs_id})->list;
				$last_balance_nominal -= $total_trx;
				$last_balance_qty -= $row->{topup_qty};
				if($err_msg =~ /, Quota Outlet denom/ || $err_msg =~ /, Quota Nominal Outlet/){
					$db->query("UPDATE rs_chip SET rs_balance_nominal=? WHERE rs_id=?", $last_balance_nominal, $row->{rs_id});
					$db->query("UPDATE rs_chip SET rs_balance_qty=? WHERE rs_id=?", $last_balance_qty, $row->{rs_id});
				}elsif($err_msg =~ /, Quota Qty Outlet/){
					#update rs_chip
					$db->query("UPDATE rs_chip SET rs_balance_nominal=? WHERE rs_id=?", $last_balance_nominal, $row->{rs_id});
					$db->query("UPDATE rs_chip SET rs_balance_qty=? WHERE rs_id=?", $last_balance_qty, $row->{rs_id});
					#update outlet
					my $sum_balance_rs_nominal = $db->query('SELECT sum(rs_balance_nominal) FROM rs_chip WHERE outlet_id=?', $outlet->{outlet_id})->list;
					$db->query('UPDATE outlet SET balance_nominal=? WHERE outlet_id=?', $sum_balance_rs_nominal, $outlet->{outlet_id});
				}
				$db->commit();
				next;
			}
		}
		# cek stok SD
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
			if($config::need_check_quota){
				# data rs chip dan outlet
				my ($quota_rs_nominal, $last_balance_nominal, $quota_rs_qty, $last_balance_qty) = $db->query('SELECT rs_nominal_quota, rs_balance_nominal, rs_qty_quota, rs_balance_qty FROM rs_chip WHERE rs_id=?',$row->{rs_id})->list;
				$last_balance_nominal -= $total_trx;
				$last_balance_qty -= $row->{topup_qty};
				#update rs_chip
				if($quota_rs_nominal > 0){
					$db->query("UPDATE rs_chip SET rs_balance_nominal=? WHERE rs_id=?", $last_balance_nominal, $row->{rs_id});
				}
				if($quota_rs_qty > 0){
					$db->query("UPDATE rs_chip SET rs_balance_qty=? WHERE rs_id=?", $last_balance_qty, $row->{rs_id});
				}
				#update outlet
				my $sum_balance_rs_nominal = $db->query('SELECT sum(rs_balance_nominal) FROM rs_chip WHERE outlet_id=?', $outlet->{outlet_id})->list;
				my $sum_balance_rs_qty = $db->query('SELECT sum(rs_balance_qty) FROM rs_chip WHERE outlet_id=?', $outlet->{outlet_id})->list;
				if($outlet->{nominal_quota} > 0){
					$db->query('UPDATE outlet SET balance_nominal=? WHERE outlet_id=?', $sum_balance_rs_nominal, $outlet->{outlet_id});
				}
				if($outlet->{qty_quota} > 0){
					$db->query('UPDATE outlet SET balance_qty=? WHERE outlet_id=?',$sum_balance_rs_qty, $outlet->{outlet_id});
				}
			}
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
		my $note_bank = undef;

		$trx->trx('top'); # type of transaction: TOPUP

		# outlet or canvasser mutation
		if ($row->{credit} == 0) { # cash
			my $payTrx = daemon::trx->new($db);
			if($row->{payment_gateway} eq 0){#normal trx
				$trx->mutation(-$row->{total_price}, $member);
				$pay_trxid = $payTrx->trx('paid_cash');
			}else{#sgo trx
				$trx->outlet_mutation(-$row->{total_price}, $outlet);
				$pay_trxid = $payTrx->trx('paid_bank');
				$note_bank = 'Mandiri Payment';
			}
			$period    = 0;
			$invStatus = 'Paid';
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
				note_bank => $note_bank,
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
		my $topup_status = 'W'; # normal trx
		$topup_status = 'WT' if $row->{payment_gateway} ne 0; # sgo trx
		$db->update('topup',
			{
				topup_status => $topup_status,
				inv_id => $inv_id,
				trans_id => $trx->{trans_id},
				exec_ts => $exec_ts,
			},
			{topup_id => $topup_id}
		);
		# selanjutnya, masing2 stock/SCM gtw (dompul.pl, mkios.pl, dll) yg meneruskan
		# tapi tidak untuk trx sgo mandiri, harus menunggu konfirmasi token dari canvasser

		$db->commit();
}
