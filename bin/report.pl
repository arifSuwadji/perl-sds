#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use Data::Dumper;


while (1) {
	my $db = daemon::db_connect();

	# get all TOPUP records which already need reply message composition
	my $res = $db->query(<<"__eos__");
SELECT topup_id, topup_status, error_msg, rs_id,
  ifnull(rs_number, dest_msisdn) as rs_number, ref_type_id,
  topup_qty, stock_ref_name, member_balance, amount
FROM topup
  INNER JOIN member using (member_id)
  LEFT JOIN rs_chip using (rs_id)
  LEFT JOIN stock_ref using (stock_ref_id)
  LEFT JOIN transaction using(trans_id)
  LEFT JOIN mutation using(trans_id)
  LEFT JOIN topup_sms using (topup_id)
WHERE need_reply=1
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed TOPUP: ', Dumper($row));
		my $topup_id     = $row->{topup_id};
		my $topup_status = $row->{topup_status};

		$db->begin();

		# did message come from sms ?
		my ($sms_id, $user_id, $smsc_id, $sms_time, $sms_localtime) = $db->query(
			"SELECT sms_id, user_id, smsc_id, sms_time, sms_localtime ".
			'FROM topup_sms inner join sms using (sms_id) '.
			'WHERE topup_id=?', $topup_id,
		)->list;
		if ($sms_id) {
			# queue was droppped (not approved)
			if ($topup_status eq 'D') {
				$db->insert('sms_outbox', {
					sms_id     => $sms_id,
					user_id    => $user_id,
					out_ts     => \['now()'],
					out_status => 'W',
					smsc_id    => $smsc_id,
					out_msg    => 'Maaf, '.$row->{error_msg},
				});
				$db->update('topup', {need_reply => 0}, {topup_id => $topup_id});
				$db->commit;
				sleep 1;
				next;
			}

			# queue was Approved (W/P/S/R)
			if ($topup_status eq 'R') {
				$db->insert('sms_outbox', {
					sms_id     => $sms_id,
					user_id    => $user_id,
					out_ts     => \['now()'],
					out_status => 'W',
					out_msg    => "Gagal, isi $row->{stock_ref_name} sebanyak $row->{topup_qty} ke $row->{rs_number}. saldo: $row->{member_balance}",
				});
				$db->insert('sms_outbox_rs', {
					sms_id    => $sms_id,
					rs_id 	  => $row->{rs_id},
					out_ts	  => \['now()'],
					out_status=> 'W',
					out_msg   => "Gagal, isi $row->{stock_ref_name} sebanyak $row->{topup_qty} ke $row->{rs_number}",
				}) unless $row->{ref_type_id} == 9;
				$db->update('topup', {need_reply => 0}, {topup_id => $topup_id});
				$db->commit;
				sleep 1;
				next;
			}
			
			# topup_status : S
			sleep 1 if $db->query(
				'select count(*) from sms_outbox '.
				'where out_ts=now() and user_id=?', $user_id,
			)->list;
			my $rs_number = $row->{rs_number} || 'unless rs number';
			my $stock_ref_name = $row->{stock_ref_name} || 'empty';
			my $topup_qty = $row->{topup_qty} || 0;
			my $amount = $row->{amount} || 0;
			$amount =~ s/\.000$//;
			eval{
				$db->insert('sms_outbox', {
					sms_id     => $sms_id,
					user_id    => $user_id,
					out_ts     => \['now()'],
					out_status => 'W',
					out_msg => "Transaksi Anda ke nomor $rs_number sebesar $stock_ref_name=$topup_qty total $amount telah berhasil diproses",
				});
			};
			if($@){
				daemon::warn("error sms outbox : $@");
				$db->rollback();
				next;
			}
			$db->update('topup', {need_reply => 0}, {topup_id => $topup_id});
			$db->commit;
			sleep 1;
			next;
			
		}

		# message didnt come from sms : web (single or bulk/basket provisioning)
		$db->update('topup', {need_reply => 0}, {topup_id => $topup_id});
		$db->commit();
	}

	$db->disconnect;
	sleep 1;


	$db = daemon::db_connect();
	# ==============================================
	# get all DEPOSIT records which already need reply message composition
	$res = $db->query(<<"__eos__");
SELECT admin_log_id, member_balance, dep_amount,
  dep_status, trans_id, user_id
FROM deposit_web
  INNER JOIN user using (user_id)
  INNER JOIN member using (member_id)
WHERE need_reply=1
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed DEPOSIT: ', Dumper($row));
		my $log_id = $row->{admin_log_id};

		$db->begin();

		# did message come from sms ?
		# NO! Sorry, currently we only support DEPosit service via web,
		# but there's always a canvaser msisdn as msg report recipient

		# queue was droppped (not approved)
		# we don't need to send any notification
		if ($row->{dep_status} eq 'D') {
			$db->update('deposit_web', {need_reply => 0}, {admin_log_id => $log_id});
			$db->commit;
			next;
		}

		# queue was Approved (W/P/S/R)
		my $now = $db->query('select now()')->list;
		$db->insert('sms_outbox', {
			user_id    => $row->{user_id},
			out_ts     => $now,
			out_status => 'W',
			out_msg    => "Telah ditambahkan deposit Anda sebesar $row->{dep_amount}. saldo: $row->{member_balance}",
		});
		$db->update('deposit_web',
			{need_reply => 0, out_ts => $now}, {admin_log_id => $log_id}
		);
		$db->commit;

		sleep 1;
		# so that the next queue can get unique out-ts
		# this has tobe fixed in the near future,
		# by checking the uniqueness of user-id+out-ts
	}

	$db->disconnect;
	sleep 1;
}
