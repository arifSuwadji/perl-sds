#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use daemon::trx;
use Data::Dumper;


while (1) {
	my $db = daemon::db_connect();

	# ambil record2 yg sudah diantrikan.
	# record2 tsb selanjutnya bisa menjadi transaksi riil, atau juga "tidak ter-approve"
	my $res = $db->query(<<"__eos__");
SELECT admin_log_id, user_id, member_id, dep_amount
FROM deposit_web inner join user using (user_id)
WHERE dep_status=''
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed: ', Dumper($row));

		$db->begin();

		my $log_id = $db->query(
			"select admin_log_id from deposit_web where admin_log_id=? and dep_status='' FOR UPDATE",
			$row->{admin_log_id},
		)->list;

		# jika ternyata topup-status telah berubah
		unless ($log_id) {
			$db->rollback();
			daemon::warn('Deposit record has changed. rolled back.');
			next;
		}

		# siap2 bertransaksi
		my $trx    = daemon::trx->new($db);
		my $member = $trx->lock_member($row->{member_id});

		# Serangkaian validasi
		# =====================
		#
		# .......
		# .......



		# the REAL transaction begins
		# ===========================

		$trx->trx('dep'); # type of transaction: TOPUP
		$trx->mutation($row->{dep_amount}, $member);

		$db->update('deposit_web',
			{dep_status => 'A',  need_reply => 1, trans_id => $trx->{trans_id}},
			{admin_log_id => $log_id},
		);

		$db->commit();
	}

	$db->disconnect;
	sleep 1;
}
