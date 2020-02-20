package report::ussd;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use daemon::trx ();


sub mkios {
	my ($q, $db, $log, $arg) = @_;

	my $topup_status = 'S';

	my ($topup_id, $trans_id, $payment_gateway) = $db->query(<<"EOS"
select topup_id, trans_id, payment_gateway from topup inner join rs_chip using (rs_id)
where sd_id=? and exec_ts=?
EOS
		, $arg->{sd_id}, $arg->{ts},
	)->list;

	if ($arg->{info} =~ /Maaf,/) {
		$topup_status = 'R';
		$topup_status = 'F' if $payment_gateway ne 0;
	}

	$db->begin;
	eval{
		$db->insert('sd_log', {
			sd_id=>$arg->{sd_id}, orig_ts=>$arg->{ts}, local_ts=>\['now()'], log_msg=>$arg->{info},
		});
		my $log_id = $db->last_insert_id(0,0,0,0);
		if ($topup_status eq 'R') {
			my $trx = daemon::trx->new($db);
			$trx->reversal($trans_id);
		}
		else {
			$db->query(
				"update topup set log_id=?, topup_status='S', need_reply=1 where topup_id=?",
				$log_id, $topup_id,
			);
		}
	};
	if($@){
		$log->warn("mkios ussd error report : ", $@);
	}

	$db->commit;
}


sub three {
	my ($q, $db, $log, $arg) = @_;

	my $topup_status = 'S';
	if ($arg->{info} =~ /Maaf,/) {
		$topup_status = 'R';
	}

	my ($topup_id, $trans_id) = $db->query(<<"EOS"
select topup_id, trans_id from topup inner join rs_chip using (rs_id)
where sd_id=? and exec_ts=?
EOS
		, $arg->{sd_id}, $arg->{ts},
	)->list;

	$db->begin;
	$db->insert('sd_log', {
		sd_id=>$arg->{sd_id}, orig_ts=>$arg->{ts}, local_ts=>\['now()'], log_msg=>$arg->{info},
	});
	my $log_id = $db->last_insert_id(0,0,0,0);
	if ($topup_status eq 'R') {
		my $trx = daemon::trx->new($db);
		$trx->reversal($trans_id);
	}
	else {
		$db->query(
			"update topup set log_id=?, topup_status='S', need_reply=1 where topup_id=?",
			$log_id, $topup_id,
		);
	}

	$db->commit;
}

sub axis {
	my ($q, $db, $log, $arg) = @_;

	my $topup_status = 'S';
	if ($arg->{info} =~ /Maaf,/) {
		$topup_status = 'R';
	}

	my ($topup_id, $trans_id) = $db->query(<<"EOS"
select topup_id, trans_id from topup inner join rs_chip using (rs_id)
where sd_id=? and exec_ts=?
EOS
		, $arg->{sd_id}, $arg->{ts},
	)->list;

	$db->begin;
	$db->insert('sd_log', {
		sd_id=>$arg->{sd_id}, orig_ts=>$arg->{ts}, local_ts=>\['now()'], log_msg=>$arg->{info},
	});
	my $log_id = $db->last_insert_id(0,0,0,0);
	if ($topup_status eq 'R') {
		my $trx = daemon::trx->new($db);
		$trx->reversal($trans_id);
	}
	else {
		$db->query(
			"update topup set log_id=?, topup_status='S', need_reply=1 where topup_id=?",
			$log_id, $topup_id,
		);
	}

	$db->commit;
}


1;
