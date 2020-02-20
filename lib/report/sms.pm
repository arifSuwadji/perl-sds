package report::sms;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use daemon::trx ();
use POSIX (qw/strftime/);


sub dompul {
	my ($q,$db,$log,$arg) = @_;
	# Transaksi Dompul ke 087886496037 sebanyak 300000 dgn trx id 22127400 berhasil. Sisa Dompul Anda saat ini Rp. 2625000.;
	# Transaksi Nominal 5000 ke 087885786468 sebanyak 500 unit dgn trx id 22127112 berhasil. Sisa nominal 5000 Anda saat ini 1309 unit.
	# MSISDN Penerima 6281932151429 tidak boleh menerima transaksi di cluster : J1-CJK-JKBR-01, J1-CJK-JKPS-01, Site.Name 0026L1.JELAMBAR MADYA2
	# Maaf, Transaksi Dompul ke 087884215061 gagal. Penerima sedang tidak aktif.

	my $text = $arg->{msg};
	# Transaksi Dompul ke 087886496037 sebanyak 300000 dgn trx id 22127400 berhasil. Sisa Dompul Anda saat ini Rp. 2625000.;
	# Transaksi Nominal 5000 ke 087885786468 sebanyak 500 unit dgn trx id 22127112 berhasil. Sisa nominal 5000 Anda saat ini 1309 unit.
	# Maaf, Transaksi Nominal 5000 ke 081997301867 gagal. Nomor Penerima tidak terdaftar.
	my $trans_id;
	my @trans_id;
	my $new_status;
	my $payment_gateway;

	unless ($text =~ m/Maaf, Transaksi Nominal/) { # unless (Maaf, Transaksi Nominal 5000 ke 081997301867 gagal. Nomor Penerima tidak terdaftar.)
		if ($text =~ m/Dompul/) {
			my ($rs_number, $topup_qty) = $text =~ m/Dompul ke (\d+) sebanyak (\d+) dgn/;
			$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
			$log->warn("rs_number = ", $rs_number," and topup_qty=", $topup_qty);
			$trans_id = $db->query(<<"EOS"
select trans_id from topup 
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where rs_number=? and topup_qty =? and topup_status in ('P', 'S')
 and log_id is NULL and topup_ts > curdate()
EOS
			,$rs_number, $topup_qty)->list;
		} elsif ($text =~ m/Nominal/) {
			my ($nominal, $rs_number, $topup_qty) = $text =~ m/Nominal (\d+) ke (\d+) sebanyak (\d+) unit/; 
			$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
			$trans_id = $db->query(<<"EOS"
select trans_id from topup 
 inner join stock_ref using(stock_ref_id)
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where nominal=? and rs_number=? and topup_qty=? and topup_status in ('P', 'S')
 and log_id is NULL and topup_ts > curdate()
EOS
			,$nominal, $rs_number, $topup_qty)->list;
		}
		push @trans_id, $trans_id;
		$new_status = 'S';

	} elsif ($text =~ m/gagal/) {
		# Maaf, Transaksi Nominal 5000 ke 081997301867 gagal. Nomor Penerima tidak terdaftar.
		my ($nominal, $rs_number) = $text =~ m/Nominal (\d+) ke (\d+) gagal/;
		$rs_number =~ s/0/62/;
		my $result = $db->query(<<"EOS"
select trans_id, payment_gateway from topup 
 inner join stock_ref using(stock_ref_id)
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where nominal=? and rs_number=? and topup_status in ('P', 'S')
 and log_id is NULL and topup_ts > curdate()
 order by trans_id desc limit 1
EOS
		,$nominal, $rs_number);
		while (($trans_id, $payment_gateway) = $result->list) {
			push @trans_id, $trans_id;
		}
		$new_status = 'R';
		$new_status = 'F' if $payment_gateway ne 0;
	}
	
	my $res_process = process($db, $log, $text, \@trans_id, $new_status, $arg);
	return $res_process;
}

sub process {
	my ($db, $log, $text, $trans_id, $new_status, $arg) = @_;
	
	foreach (@$trans_id) {
		return {} unless defined $_;
		
		$log->warn('trans_id :', $_||'0');
		return {} unless ($_);
		$db->begin;
		eval { 
			my $log_id = $db->query(
				'select log_id from sd_log where sd_id=? and orig_ts=?', 
				$arg->{sd_id}, $arg->{ts},
			)->list;
			unless ($log_id) {
				$db->insert('sd_log', {
					sd_id => $arg->{sd_id}, orig_ts=>$arg->{ts},
					local_ts=>\['now()'], log_msg=>$arg->{msg},
				});
				$log_id = $db->last_insert_id(0,0,0,0);
			}
			else {
				$log->warn('existing log-id: ', $log_id) if $log_id;
			}
			my %update = (log_id => $log_id);
			$update{need_reply}   = 1;
			$update{topup_status} = $new_status;

			$db->update('topup', \%update, {trans_id => $_});
			if ($new_status eq 'R') {
				my $trx = daemon::trx->new($db);
				$trx->reversal($_);
			}
		};
		if ($@) {
			$log->warn($@);
			$db->rollback;
			return {param => $text}
		}
		$db->commit;
		return {param => $text}
	}
}
sub esia {
	my ($q,$db,$log,$arg) = @_;
        # Anda tlh transfer 5K=20 unit ke 02141554332 pada 30-09-2011 13:50:52. Ref 0930135052226651. Saldo Anda skrg Range 0=Rp 2850000, jumlah unit Anda 1K=1284 unit,
	# Anda tlh transfer Range 0=Rp 200000 ke 02141553732 pada 19-10-2011 12:23:46. Ref 1019122346290049. Saldo Anda skrg Range 0=Rp 900000, jumlah unit Anda 1K=295
	
	my $text = $arg->{msg};
        my $trans_id;
        
	my $nominal;
	my $topup_qty;
	my $rs_number;
        
	if ($text =~ m/transfer Range/) {
                ($nominal, $topup_qty, $rs_number) = ($text =~ m/transfer Range (0)=Rp (\d+) ke (\d+) pada/);
        }
        if ($text =~ m/transfer \w+\=/) {
                ($nominal, $topup_qty, $rs_number) = ($text =~ m/transfer (\d+)K=(\d+) unit ke (\d+) pada/);
                $nominal= $nominal*1000;
        }

	$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
	$log->warn("nominal=$nominal, topup_qty= $topup_qty, rs_number = $rs_number");
	$trans_id = $db->query(<<"EOS"
select trans_id from topup 
 inner join stock_ref using(stock_ref_id)
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where nominal=? and rs_number=? and topup_qty=? and topup_status in ('P', 'S') and date(topup_ts)=date(now()) and log_id is NULL
EOS
                ,$nominal, $rs_number, $topup_qty)->list;
	
        $log->warn('trans_id :', $trans_id||'0');
        return {} unless ($trans_id);
        $db->begin;
        $db->insert('sd_log', {
                sd_id=>$arg->{sd_id}, orig_ts=>$arg->{ts}, local_ts=>\['now()'], log_msg=>$arg->{msg},
        });
        my $log_id = $db->last_insert_id(0,0,0,0);
        $db->query(
                "update topup set log_id=?, topup_status='S', need_reply=1 where trans_id=?",
                $log_id, $trans_id,
        );
        $db->commit;
        return {param => $text}
}

sub three {
	my ($q,$db,$log,$arg) = @_;
	
	# TRF RP= 600,000  ke 89652158222 OK 14-12-2011 12:13:54. ID 1214121354211868. Saldo RP= 29,655,005 , V500MB= 5, V1GB= 7, V2GB= 6, V5GB= 7.
	my $text = $arg->{msg};
	my $trans_id;
	
	my $topup_qty; my $rs_number; my $nominal;
	if ($text =~ m/TRF RP/) {
		($topup_qty, $rs_number) = ($text =~ m/TRF RP= (\d+)\,\d+  ke (\d+) OK/);
		$topup_qty = $topup_qty."000";
		$rs_number = "0".$rs_number;
		$rs_number =~ s/0/62/;
		$log->warn("rs_number = ", $rs_number," and topup_qty=", $topup_qty);
		$trans_id = $db->query(<<"EOS"
select trans_id from topup 
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where rs_number=? and topup_qty =? and topup_status in ('P', 'S')
 and log_id is NULL
EOS
		,$rs_number, $topup_qty)->list;
	} elsif ($text =~ m/TRF V/) {
		#TRF V1GB= 5 ke 89652118080 OK
		($nominal, $topup_qty, $rs_number) = ($text =~ m/TRF V(\d+)\w{1}B= (\d+) ke (\d+) OK/);
		if ($nominal eq 500) {
			$nominal = 35000; 
		} elsif ($nominal eq 1) {
			$nominal = 50000;
		} elsif ($nominal eq 2) {
			$nominal = 75000;
		} elsif ($nominal eq 5) {
			$nominal = 125000;
		}

		$rs_number = "0".$rs_number;
                $rs_number =~ s/0/62/;
                $log->warn("nominal = ",$nominal, "rs_number = ",$rs_number," and topup_qty=", $topup_qty);

		$trans_id = $db->query(<<"EOS"
select trans_id from topup 
 inner join stock_ref using(stock_ref_id)
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where nominal=? and rs_number=? and topup_qty=? and topup_status in ('P', 'S') and date(topup_ts)=date(now()) and log_id is NULL
EOS
                ,$nominal, $rs_number, $topup_qty)->list;


	}
	$log->warn('trans_id :', $trans_id||'0');
	return {} unless ($trans_id);
	$db->begin;
	my $log_id = $db->query(
		'select log_id from sd_log where sd_id=? and orig_ts=?', 
		$arg->{sd_id}, $arg->{ts},
	)->list;
	unless ($log_id) {
		$db->insert('sd_log', {
			sd_id => $arg->{sd_id}, orig_ts=>$arg->{ts},
			local_ts=>\['now()'], log_msg=>$arg->{msg},
		});
		$log_id = $db->last_insert_id(0,0,0,0);
	}
	else {
		$log->warn('existing log-id: ', $log_id) if $log_id;
	}

	my $topup_status = $db->query(
		'select topup_status from topup where trans_id=?', $trans_id,
	)->list;
	my %update = (log_id => $log_id);
	if ($topup_status eq 'P') {
		$update{need_reply}   = 1;
		$update{topup_status} = 'S';
	}
	$db->update('topup', \%update, {trans_id => $trans_id});
	$db->commit;
	return {param => $text}
}

sub smart{
	my ($q,$db,$log,$arg) = @_;

	#(43) Terima kasih,  Anda melakukan transfer pulsa jual sebesar 5,000 pada tanggal 25/07/12 13:25 ke 628811837053. Jumlah pulsa jual anda saat ini sebesar 4,540
	my $text = $arg->{msg};
	$log->warn( "ini pesan yang di terima smart : ",$text);
	my $rs_number ;
	my $topup_qty ;
	if($text =~ m/ke (\d+)/){
	        $rs_number = $1;
	}
	if($text =~ m/sebesar (\d+)/){
	        $topup_qty = $1;
	}

	$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
	$topup_qty = $topup_qty ."000";
	$log->warn("rs_number = ", $rs_number," and topup_qty=", $topup_qty);
	my $trans_id = $db->query(<<"EOS"
select trans_id from topup 
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where rs_number=? and topup_qty =? and topup_status in ('P', 'S')
 and log_id is NULL
EOS
		,$rs_number, $topup_qty)->list;
	$log->warn('trans_id :', $trans_id||'0');	
	return {} unless ($trans_id);

	$db->begin;
	my $sd_id = $db->query("select sd_id from sd_chip where sd_name = 'smart'")->list;
        $db->insert('sd_log', {
                sd_id=>$sd_id, orig_ts=>$arg->{ts}, local_ts=>\['now()'], log_msg=>$arg->{msg},
        });
        my $log_id = $db->last_insert_id(0,0,0,0);
        $db->query(
                "update topup set log_id=?, topup_status='S', need_reply=1 where trans_id=?",
                $log_id, $trans_id,
        );
	$db->commit;

	return {param => $text}
}

sub fkios{
	my ($q,$db,$log,$arg) = @_;
	
	my $text = $arg->{msg};
	$log->warn("ini pesan yang diterima fkios : ", $text);
	
	my $rs_number ;
	my $topup_qty ;
	if($text =~ m/ke (\d+)/){
	        $rs_number = $1;
	}
	if($text =~ m/sebesar (\d+)/){
	        $topup_qty = $1;
	}

	$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
	$log->warn("rs_number = ", $rs_number," and topup_qty=", $topup_qty);
	my $trans_id = $db->query(<<"EOS"
select trans_id from topup 
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where rs_number=? and topup_qty =? and topup_status in ('P', 'S')
 and log_id is NULL
EOS
		,$rs_number, $topup_qty)->list;
	$log->warn('trans_id :', $trans_id||'0');	
	return {} unless ($trans_id);

	$db->begin;
	my $sd_id = $db->query("select sd_id from sd_chip where sd_name = 'smart'")->list;
        $db->insert('sd_log', {
                sd_id=>$sd_id, orig_ts=>$arg->{ts}, local_ts=>\['now()'], log_msg=>$arg->{msg},
        });
        my $log_id = $db->last_insert_id(0,0,0,0);
        $db->query(
                "update topup set log_id=?, topup_status='S', need_reply=1 where trans_id=?",
                $log_id, $trans_id,
        );
	$db->commit;
	
	return {param => $text}
}

sub sevnusapro {
	my ($q,$db,$log,$arg) = @_;
        # DSVR.V5=20.081511581304.99;SUKSES.SAL=40.084.250,HRG=104.000,SN=000018158183 
	
	my $text = $arg->{msg};
        my $trans_id;
	my $sd_id;
        my $nominal;
	my $topup_qty;
	my $rs_number;
	my $bal;
	my $price;
	my $sn;
 
	if($text =~ /SUKSES/) {
        	($nominal,$topup_qty,$rs_number,$bal,$price,$sn) = ($text =~ /\w(\d+)\=(\w+).(\w+)\.\w+\;SUKSES\.SAL\=([\d\.]+)\,HRG\=([\d\.]+)\,SN\=(\d+)/);
		$nominal = $nominal * 1000;
	}
	$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
	$log->warn("nominal=$nominal, topup_qty= $topup_qty, rs_number = $rs_number");
	($trans_id,$sd_id) = $db->query(<<"EOS"
select trans_id, sd_id from topup 
 inner join stock_ref using(stock_ref_id)
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where nominal=? and rs_number=? and topup_qty=? and topup_status in ('P', 'S') and date(topup_ts)=date(now()) and log_id is NULL
EOS
                ,$nominal, $rs_number, $topup_qty)->list;
	
        $log->warn('trans_id :', $trans_id||'0');
        return {} unless ($trans_id);
        $db->begin;
        $db->insert('sd_log', {
                sd_id=>$sd_id, orig_ts=>$arg->{ts}, local_ts=>\['now()'], log_msg=>$arg->{msg},
        });
        my $log_id = $db->last_insert_id(0,0,0,0);
        $db->query(
                "update topup set log_id=?, topup_status='S', need_reply=1 where trans_id=?",
                $log_id, $trans_id,
        );
        $db->commit;
        return {param => $text}
}

sub sev {
	my ($q,$db,$log,$arg) = @_;
        # Ref:211049719.TRS 556V5 pada 02/04 15:12 ke 085811323691 SUKSES.Stok anda 0,90550,0,41050,0,0,4250,0,3070,540. 
		# Ref:338804665.TRS 1V5 pada 16/04 16:45 ke 081559815829 SUKSES.Stok anda 0,73332,0,46465,0,0,3975,0,1737,256.	
	my $text = $arg->{msg};
	my $trans_id;
	my $sd_id;
	my ($nominal, $topup_qty, $rs_number);
	my $local_ts = strftime("%Y-%m-%d %H:%M:%S", CORE::localtime);
	my @stock_denom;
	my $val_stock = undef;
	if ($text =~ /SUKSES/) {
		($nominal) = ($text =~ /TRS [^"]+V(\d+) pada/);
		($topup_qty) = ($text =~ /TRS ([^"]+)V\d+ pada/);
		($rs_number) = ($text =~ /ke (\d+) SUKSES/);
		$nominal = $nominal * 1000 if $nominal;
		$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
		#report stock
		($val_stock)= ($text =~ /Stok\sanda\s([^!]+)\./);
		my @val_rep = split /\,/, $val_stock;
		my $i = 0;
		foreach(@val_rep){
			$i++;
			push @stock_denom, $_ if $i eq 2; #for indosat 5K
			push @stock_denom, $_ if $i eq 4; #for indosat 10K
			push @stock_denom, $_ if $i eq 7; #for indosat 25K
			push @stock_denom, $_ if $i eq 9; #for indosat 50K
			push @stock_denom, $_ if $i eq 10; #for indosat 100K
		}
	}
	$topup_qty =~ s/\,// if $topup_qty =~ /\,/;
	$_ ||= '' foreach ($nominal, $topup_qty, $rs_number);
	$log->warn("nominal=$nominal, topup_qty= $topup_qty, rs_number = $rs_number");
	($trans_id,$sd_id) = $db->query(<<"EOS"
select trans_id, sd_id from topup 
 inner join stock_ref using(stock_ref_id)
 inner join rs_chip using(rs_id)
 inner join sd_chip using(sd_id)
where nominal=? and rs_number=? and topup_qty=? and topup_status in ('P', 'S') and date(topup_ts)=date(now()) and log_id is NULL
EOS
                ,$nominal, $rs_number, $topup_qty)->list;
	
        $log->warn('trans_id :', $trans_id||'0');
        return {} unless ($trans_id);
		my $check_logID = $db->query("SELECT log_id FROM sd_log WHERE local_ts=?", $local_ts)->list;
		$local_ts = strftime("%Y-%m-%d %H:%M:%S", CORE::localtime(time + 1)) if $check_logID;
        $db->begin;
        $db->insert('sd_log', {
                sd_id=>$sd_id, orig_ts=>$arg->{ts}, local_ts=>$local_ts, log_msg=>$arg->{msg},
        });
        my $log_id = $db->last_insert_id(0,0,0,0);
        $db->query(
                "update topup set log_id=?, topup_status='S', need_reply=1 where trans_id=?",
                $log_id, $trans_id,
        );
        $db->commit;
		#report stock
		if(@stock_denom){
			my $result = $db->query(<<"EOS"
SELECT stock_ref_id, stock_ref_name, keyword, qty FROM sd_stock
INNER JOIN stock_ref USING(stock_ref_id)
GROUP BY stock_ref.stock_ref_id
EOS
);
			my $i = -1;
			while(my $row = $result->hash){
				$i++;
				my $ref_id = $row->{stock_ref_id};
				my $last_balance = $stock_denom[$i] || 0;
				$log->warn("ref id : ", $ref_id. " value $i : ", $stock_denom[$i] || 'empty');
				$db->insert('stock_denom',{
					trans_id => $trans_id, stock_ref_id => $ref_id, last_balance => $last_balance,
				});
			}
		}
        return {param => $text}
}

1;
