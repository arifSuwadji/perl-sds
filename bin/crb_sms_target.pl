#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use config;
use common;
use daemon;
use Data::Dumper;
use LWPx::ParanoidAgent;
use CGI::Enurl;

my $db = daemon::db_connect();
my $a = 1;
my $b = $db->query("select count(*) from member where member_type in ('CVS','SPV','BM')");
while ($a < $b) {

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
	select user_id, username, member_id, parent_id, member_name, member_type, member_target from member inner join user using (member_id) where member_type in ('CVS','SPV','BM') and user.status='Active' order by member_type
__eos__

	while (my $row = $res->hash) {
		print 'Unprocessed: ', Dumper($row);
		my $out_ts  = common::now();

		my ($smsc_id, $smsc_name) = $db->query(
			"select smsc_id, smsc_name from smsc where smsc_status='active' and smsc_name <> ? order by rand() limit 1", $config::smsc)->list;

		my ($from, $until) = $db->query('select from_date, until_date + interval 1 day from target_period where period_status="open"')->list;
		print "from = $from\n";
		print "until = $until\n";
		#my $d_sale = $db->query("select ref_type_id, ref_type_name from stock_ref_type where ref_type_id > 11 and ref_type_name like 'Dompul-%'");
		my $total =0;
		my $total_all =0;
		my $target_week =0;
		my $target_week_perdana =0;
		my $sum_qty_sale = 0;
		my $persen=0;
		my $persen_all=0;
		my $price=0;
		my $sum_price=0;
		my $message="";
		if ($row->{member_type} eq 'CVS'){
		my $d_sale = $db->query("select ref_type_id, ref_type_name from stock_ref_type where ref_type_id > 11");
		my $cvs_target_perdana = $db->query("select sum(qty_target) from dompul_target where member_id=?",$row->{member_id})->list;
		my %sale;
		my @sal = $d_sale->hashes;
		#print "==>",Dumper(@sal);
		my %target;
		my $sum_qty_sale = 0;
		my $target_sale = 0;
		my $persen_unit =0;
		my $text_unit = "";
		my $amount_price = 0;
		my $sum_price =0;
		my $persen_perdana = 0;
		foreach (@sal) {
			$sum_qty_sale = $db->query(
				"select sum(qty_sale) from dompul_sale where member_id=? and ref_type_id=? and sale_ts >= ? and sale_ts < ?",
				$row->{member_id}, $_->{ref_type_id}, $from, $until
			)->list;
			unless ($sum_qty_sale) {$sum_qty_sale = 0;}
			$sale{$_->{ref_type_id}} = $sum_qty_sale;
			if ($sum_qty_sale > 1 and $cvs_target_perdana > 1) {
			$persen_perdana = $sum_qty_sale / $cvs_target_perdana * 100;
			my ($new_persen_perdana) = ($persen_perdana =~ /(\d+.\d{2})/);
			$persen_perdana= $new_persen_perdana;
			} else {$persen_perdana = 0;}
			$text_unit .= "$_->{ref_type_name} - $sale{$_->{ref_type_id}} - $persen_perdana %, ";
		}
		# crb
		my $keyword = $db->query("select stock_ref_id, stock_ref_name, keyword  from stock_ref inner join stock_ref_type using(ref_type_id)");#)where ref_type_name='Dompul'");
		my @keys = $keyword->hashes;
		my $cvs_target_nominal = $db->query('select sum(nominal_target) from dompul_target where member_id=?',$row->{member_id})->list;
		my $sum_amount = 0;
		my $sum_amount_all = 0;
		my $text_unit2 = "";
		my $persen_nominal=0;
		foreach (@keys) {
		$sum_amount = $db->query("select sum(-amount) as sum_amount from topup inner join stock_ref using (stock_ref_id) inner join stock_ref_type using(ref_type_id) inner join mutation using (trans_id) where topup.member_id= ? and topup_status='S' and keyword=? and topup_ts >= ? and topup_ts < ?", $row->{member_id}, $_->{keyword}, $from, $until)->list;
		
		unless ($sum_amount) {
		#	print "kosong"; 
			$persen = '0';
		} else {
		#print "amount = $sum_amount";
		}
		unless ($sum_amount) {$sum_amount = 0;}
		$sum_amount_all += $sum_amount;
		if ($sum_amount_all > 1 and $cvs_target_nominal) {
		$persen_nominal = $sum_amount_all / $cvs_target_nominal * 100;
		my ($new_persen1) = ($persen_nominal =~ /(\d+.\d{2})/);
                $persen_nominal= $new_persen1;
		} else {$persen_nominal = 0;}
		$sum_amount =~ s/(\d)(?=(\d{3})+(\D|$))/$1\./g;
		$sum_amount =~ s/\.000$//g;
		$row->{member_target} =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;
		$row->{member_target} =~ s/0$//g;
		$text_unit2 .= "$_->{keyword} - $sum_amount, ";
		}
		#print "Nominal = $text_unit2";
		#print "jumlah = $sum_amount_all";
		$total = $sum_amount_all;
		$total =~ s/(\d)(?=(\d{3})+(\D|$))/$1\./g;
		$message = "$row->{member_name} $out_ts = $text_unit2 total $text_unit, Rp $total - $persen_nominal %";
	} elsif ($row->{member_type} eq 'SPV'){
		my $spv = $db->query("select member_id, member_name from member where parent_id=?",$row->{member_id});
		my $spv_target = $db->query("select member_target from member where member_id=?",$row->{member_id})->list;
		my $sms_spv="";
		my $persen;
		my $persen_perdana_spv;
		my $new_persen;
		my $total_sale_cvs;
		my $total_target_week;
		my $total_sum_qty_sale;
		while (my $cvs_s = $spv->hash){
			print "member_cvs = $cvs_s->{member_name}";

			# nominal
			$total = $db->query("select sum(-amount) as sum_amount from topup inner join stock_ref using (stock_ref_id) inner join stock_ref_type using(ref_type_id) inner join mutation using (trans_id) where topup.member_id= ? and topup_status='S' and topup_ts >= ? and topup_ts < ?", $cvs_s->{member_id}, $from, $until)->list;
			$target_week = $db->query('select sum(nominal_target) from dompul_target where member_id=?',$cvs_s->{member_id})->list;
			$target_week_perdana = $db->query('select sum(qty_target) from dompul_target where member_id=?',$cvs_s->{member_id})->list;

			#perdana
			$sum_qty_sale = $db->query(
                "select sum(qty_sale) from dompul_sale where member_id=? and ref_type_id=? and sale_ts >= ? and sale_ts < ?",
                $cvs_s->{member_id}, $config::reftypeid, $from, $until
            )->list;
            unless ($sum_qty_sale) {$sum_qty_sale = 0;}
			if ($sum_qty_sale > 1 and $target_week_perdana > 1){
			$persen_perdana_spv = $sum_qty_sale / $target_week_perdana * 100;
			my ($new_persen_perdana_spv) = ($persen_perdana_spv =~ /(\d+.\d{2})/);
                $persen_perdana_spv = $new_persen_perdana_spv;
			} else {$persen_perdana_spv=0;}
            $price = $db->query("select price from pricing inner join stock_ref using(stock_ref_id) where ref_type_id=? limit 1",$config::reftypeid)->list;
			
            if ($sum_qty_sale >= 1){
            $sum_price = $sum_qty_sale * $price;
            }else {$sum_price = 0;}


			$target_week = 0 unless $target_week;
			$total = 0 unless $total;
			print "target week = $target_week\n";
			print "total = $total\n";
			print "price = $sum_price\n";
			#unless ($target_week and $total){$target_week = 0;$total=0;}
			#my $total_all = $total + $sum_price;
			if ($target_week > 1 and $total > 1){
				$persen = $total/ $target_week * 100;
				($new_persen) = ($persen =~ /(\d+.\d{2})/);
				$persen= $new_persen;
			}else{$persen = 0;}
			$total_sale_cvs += $total;	
			$total_target_week += $target_week;	
			$total_sum_qty_sale += $sum_qty_sale;	
			$total_all =~ s/(\d)(?=(\d{3})+(\D|$))/$1\./g;
			$sms_spv .= "$cvs_s->{member_name} : Nominal $total - $persen%, Perdana $sum_qty_sale - $persen_perdana_spv %,";
		}
		my $persen_spv=0;
		my $total_persen_perdana_spv=0;
		if ($total_sum_qty_sale > 1 and $total_target_week > 1){
		$total_persen_perdana_spv = $total_sum_qty_sale / $total_target_week * 100;
		($new_persen) = ($total_persen_perdana_spv =~ /(\d+.\d{2})/);
                $total_persen_perdana_spv = $new_persen;
		} else {$total_persen_perdana_spv = 0;}
		if ($total_sale_cvs > 1 and $total_target_week > 1) {
		$persen_spv = $total_sale_cvs / $total_target_week * 100;
		($new_persen) = ($persen_spv =~ /(\d+.\d{2})/);
		$persen_spv= $new_persen;
		$total_sale_cvs =~ s/(\d)(?=(\d{3})+(\D|$))/$1\./g;}else {$persen_spv=0; $total_sale_cvs=0;}
		$message = $sms_spv.' TOTAL: Nominal '.$total_sale_cvs.' - '.$persen_spv.'%, Perdana '.$total_sum_qty_sale.' - '.$total_persen_perdana_spv.'%';
	} else {
		my $bm_target = $db->query("select member_target from member where member_id=?",$row->{member_id})->list;
		my $bm = $db->query("select member_id, member_name from member where parent_id=?",$row->{member_id});
		my $sms_bm="";
		my $total_sale_spv;
		my $total_sale_qty_spv;
		my $total_target_qty_spv;
		my $persen;
		my $persen_qty_bm;
		my $new_persen;
		my $total;
		while (my $spv_s = $bm->hash){
			print "member_cvs = $spv_s->{member_name}";
			print "member_cvs = $spv_s->{member_id}";
			# nominal
			$total = $db->query("select sum(-amount) as sum_amount from topup inner join stock_ref using (stock_ref_id) inner join stock_ref_type using(ref_type_id) inner join mutation using (trans_id) where topup.member_id in (select member_id from member where parent_id=?) and topup_status='S' and topup_ts >= ? and topup_ts < ?", $spv_s->{member_id}, $from, $until)->list || '';
			print "0000 = $total";
			#my $target_week = $db->query('select member_target from member where member_id=?',$spv_s->{member_id})->list;
			my $target_week = $db->query('select sum(nominal_target) from dompul_target where member_id in (select member_id from member where parent_id=?)',$spv_s->{member_id})->list;

			my $target_week_perdana = $db->query('select sum(qty_target) from dompul_target where member_id in (select member_id from member where parent_id=?)',$spv_s->{member_id})->list;
			#perdana
			my $sum_qty_sale = $db->query(
                "select sum(qty_sale) from dompul_sale where member_id in (select member_id from member where parent_id=?) and ref_type_id=? and sale_ts >= ? and sale_ts < ?",
                $spv_s->{member_id}, $config::reftypeid, $from, $until
            )->list;
            unless ($sum_qty_sale) {$sum_qty_sale = 0;}
            my ($price) = $db->query("select price from pricing inner join stock_ref using(stock_ref_id) where ref_type_id=? limit 1",$config::reftypeid)->list;
			
			my $sum_price;
            if ($sum_qty_sale >= 1){
            $sum_price = $sum_qty_sale * $price;
            }else {$sum_price = 0;}


			$target_week = 0 unless $target_week;
			$target_week_perdana = 0 unless $target_week_perdana;
			$total = 0 unless $total;
			#unless ($target_week and $total){$target_week = 0;$total=0;}
			my $total_all = $total + $sum_price;
			if ($target_week > 1 and $total > 1){
				$persen = $total / $target_week * 100;
				($new_persen) = ($persen =~ /(\d+.\d{2})/);
				$persen= $new_persen;
			}else{$persen = 0;}
			if ($sum_qty_sale > 1 and $target_week_perdana > 1){
				$persen_qty_bm = $sum_qty_sale / $target_week_perdana * 100;
				($new_persen) = ($persen_qty_bm =~ /(\d+.\d{2})/);
                $persen_qty_bm= $new_persen;
			} else {$persen_qty_bm=0;}
			$total_sale_spv += $total;
			$total_sale_qty_spv += $sum_qty_sale;
			$total_target_qty_spv += $target_week_perdana;
			$total_all =~ s/(\d)(?=(\d{3})+(\D|$))/$1\./g;		
			$sms_bm .= "$spv_s->{member_name} : Nominal $total - $persen%, Perdana $sum_qty_sale - $persen_qty_bm%";
		}
		print "bm_target $bm_target";
		my $persen_bm;
		my $persen_total_qty_bm;
		if ($total_sale_spv > 0){
		$persen_bm = $total_sale_spv / $bm_target * 100;
		($new_persen) = ($persen_bm =~ /(\d+.\d{2})/);
		$persen_bm= $new_persen;
		$total_sale_spv =~ s/(\d)(?=(\d{3})+(\D|$))/$1\./g;} else {$total_sale_spv=0; $persen_bm=0;}
		if ($total_sale_qty_spv > 1 and $total_target_qty_spv > 1) {
		$persen_total_qty_bm = $total_sale_qty_spv / $total_target_qty_spv * 100;
		($new_persen) = ($persen_total_qty_bm =~ /(\d+.\d{2})/);
        $persen_total_qty_bm= $new_persen;
		} else {$persen_total_qty_bm=0;}
		$message = $sms_bm.',Total : Nominal '.$total_sale_spv.' - '. $persen_bm.'%, Perdana '.$total_sale_qty_spv.' - '.$persen_total_qty_bm.'%';

	}
		print "total. $total";
		print "sum_qty_sale. $sum_qty_sale";
		print "target_week. $target_week";
		print "total_all. $total_all";
		print "persen. $persen";
		print "sum_price. $sum_price";
		print "message = $message\n";
	
		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^192\./, '127.0.0.1');
		$ua->timeout(10);

		my $url = 'http://127.0.0.1:59194/service/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $smsc_name,
			#modem    => 'modem1',
			text     => $message,
			to       => $row->{username},
			ts       => $out_ts,
		});
		print 'url: ', $url;
		my $resp = $ua->get($url);
		print 'resp: ', $resp->status_line, ' : ', $resp->content;
		my $out_status = $resp->is_success ? 'S' : 'F';


		if ($row->{member_type} eq 'BM'){
		print "additional number";
		my @additional_number = $db->query(
		'select username from additional_user where member_id=? and status="Active"',$row->{member_id})->hashes;
		foreach (@additional_number) {
			$url = 'http://127.0.0.1:59194/service/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $smsc_name,
			#modem    => 'modem1',
			text     => $message,
			to       => $_->{username},
			ts       => $out_ts,
		});
		print 'url: ', $url;
		my $resp = $ua->get($url);
		print 'resp: ', $resp->status_line, ' : ', $resp->content;
		my $out_status = $resp->is_success ? 'S' : 'F';

		}
	}

		sleep 1;
	}

	$db->disconnect;
	sleep 1;
	$a = $a + 1;
	exit;
}

