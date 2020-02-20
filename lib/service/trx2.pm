package service::trx2;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use service ();
use daemon::trx ();

use POSIX qw(strftime);
use CGI::Enurl;
use XML::Simple;


sub transfer {
	# T.081234567.100000.pin
	# T.081234567.1jt.pin --> nom =~ s/jt/000000/
	my ($db, $log, $param, $msg) = @_;

	# start locking
	$db->begin;
	my $trx = daemon::trx->new($db);

	# pelaku transfer
	my $member_id = $param->{member_id} || 0;
	$log->warn('member id: ', $member_id);
	my $member = $trx->lock_member($member_id);
	my $amount = $msg->[2] || 0;
	$amount =~ s/\D//g; $amount ||= 0;
	if ($amount > $member->{member_balance}) {
		$db->rollback;
		return 'saldo tdk mencukupi';
	}

	# tujuan transfer (canvasser) : nomor hp / username di table evo.user
	my $dest_num = $msg->[1] || 0;
	unless ($dest_num) {
		$db->rollback;
		return 'cek kembali nomor tujuan transfer';
	}

	# mulai trx dan kurangi saldo pelaku trx
	$trx->trx('trf');
	$trx->mutation(-$amount, $member);

	# di evo : pindahkan saldo dari member "sds" ke nomor tujuan transfer
	my $ua = LWP::UserAgent->new;
	# /service?msg=T.0219929xxxx.150000.1234&msisdn=628389028xxxx&smsc=m3-center&ts=2012-08-13+14%3A25%3A25&modem_id=31
	my %param = (
		msg => join('.', 'T', $dest_num, $amount, 75893),
		msisdn => 'sds-server', smsc => 'h2h',
		ts => strftime('%Y-%m-%d %H:%M:%S', localtime()),
	);
	my $resp = $ua->get('http://evo:9192/service?'.enurl(\%param));
	$log->warn('http resp from svc 9192: ', $resp->status_line);
	$log->warn('http resp content: ', $resp->content);
	my $ref = XMLin $resp->content;
	my $svc_resp = $ref->{svc_resp} || 0;
	unless ($svc_resp =~ /(42|39)$/) {
		$db->rollback;
		return 'Maaf, transfer tidak berhasil dilakukan, cek kembali no tujuan';
	}

	# finishing
	$db->commit;
	return "Telah ditransfer sejumlah Rp $amount ke $dest_num.";
}

sub package {
	my ($db, $log, $param, $msg) = @_;
	# P.S50.3.0817.pin.2
	# XL5.100.0817.pin.2
	# service::trx ini adalah bagian dari messaging gtw, bukan bagian dari trx/core proc,
	# jadi rolenya hanya sebatas memasukkan ke topup queue (table topup)
	# topup_id, rs_id, member_id, stock_ref_id, topup_qty
	# selebihnya (cek saldo, stock availability, etc.) diolah oleh core proc

	my $rs_number = $msg->[3];
	$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
	
	# free canvasser
        if ($config::free_canvasser) {
               $param->{member_id} = $db->query("select member_id from rs_chip where rs_number =?", $rs_number)->list;
        }
	
	my $rs_id = $db->select('rs_chip', ['rs_id'], {rs_number => $rs_number})->list;
	my $reply_msg = {};
	unless ($rs_id) {
		$reply_msg->{sms_outbox} = "nomor rs chip yang anda masukkan salah";
		return $reply_msg;
	} else {
	# package id diambil dulu
		my $pkg_name = $msg->[1];
		my $pkg_id = $db->select('package', ['pkg_id'], {pkg_name => $pkg_name})->list;
		my $result = $db->select('package_detail', ['stock_ref_id','pkg_qty'], {pkg_id => $pkg_id});
		# my $result = $db->query("select stock_ref_id, pkg_qty from package_detail where pkg_id =?", $pkg_id);
 		my $qty = $msg->[2]; $qty =~ s/[\-\D]//g; # there might be spaces,commas,etc.
		while (my ($stock_ref_id, $pkg_qty) = $result->list) {
			# stock_ref_id untuk mencari keyword stock yg unit based
			my $keyword = $db->select('stock_ref', ['keyword'], {stock_ref_id => $stock_ref_id})->list;
		
			# qty
			my $topup_qty = $qty * $pkg_qty;
			unless ($qty and $qty > 0) {
				$reply_msg->{sms_outbox} = "qty tidak valid, silakan ulangi request anda";
				return $reply_msg;
			} else {

				$log->warn("qty=$qty, stock_ref_id=$stock_ref_id, rs_id=$rs_id");

				# topup ke rs, stock-ref, dan qty yg sama hrs menunggu 6 jam
				# atau menggunakan sequence yg berbeda
				my $seq = $msg->[5] || 1;
				my $reply_msg;

				$db->begin();
				eval {
					my $found = $db->query(<<"EOS",
select topup_id from topup_sms inner join topup using (topup_id)
where rs_id=? and topup_qty=? and stock_ref_id=? and sequence=?
  and topup_status in ('', 'W', 'P', 'S')
  and topup_ts >= date_sub(now(), interval 6 hour)
for update
EOS
						$rs_id, $qty, $stock_ref_id, $seq,
						)->list;
					if ($found) {
						$reply_msg->{sms_outbox} = "pengisian $keyword ke $rs_number sejumlah $qty utk yg ke $seq telah/sedang dilakukan. tunggu dlm 6 jam utk mengulang";
						die('duplicate topup request found');
					}

					$db->insert('topup', {
						stock_ref_id => $stock_ref_id,       rs_id     => $rs_id,
						member_id    => $param->{member_id}, topup_qty => $topup_qty,
						topup_ts     => \['now()'],
					});
					my $topup_id = $db->last_insert_id(0,0,0,0);
					$db->insert('topup_sms', { topup_id=>$topup_id, sms_id=>$param->{sms_id} });
				};
				if ($@) {
					$log->warn("transaction aborted: $@");
					$db->rollback();
					return $reply_msg if $@ =~ /duplicate topup/;
					$reply_msg->{sms_outbox} = "transaksi GAGAL. silakan coba kembali bbrp saat lagi.";
					return $reply_msg;
				}
				$db->commit();
			}
		}
		return {};
	}
}


1;

