package modify::transaction;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use CGI::Enurl;
use common::util();
use daemon::trx;
use common();
use LWP::UserAgent;
use config;

sub inject {
        my ($s, $q, $db, $log) = @_;

	# transaksi tidak bisa dilakukan tanpa trx hp, sebelumnya kalo pake trxhp dianggap topup owner free
	# ini sebelumnya :
	# unless ($q->param('hp_sales')) {	
	#	my $return = _inject($s, $q, $db, $log);
        #        return $return;
        # }

	my $today = common::today();
	my $rs_number = $q->param('rs_number');
        $rs_number =~ s/0/62/ if $rs_number =~ /^0/;
        my $rs_id = $db->query(
       	        'select rs_id from rs_chip where rs_number=?', $rs_number,
        )->list
       	        ||return "/view/transaction/new_topup?error=rs+number+invalid";
	my $member_id_rs = $db->query('select member_id from rs_chip where rs_number=?',$rs_number)->list;
	my $hp_sales = $q->param('hp_sales');
	unless ($hp_sales){
		$hp_sales = $config::system_owner_username;
	} 
        $hp_sales =~ s/0/62/ if $hp_sales =~ /^0/ ;
        my $member_id_sales = $db->query('select member_id from user where username=?',$hp_sales)->list;
	
   	return "/view/transaction/new_topup?error=maaf,+trx+hp+tidak+boleh+kosong" if $hp_sales eq '';
    unless ($config::topup_web_empty){    
	if($member_id_rs != $member_id_sales){
                return "/view/transaction/new_topup?error=rs+number+$rs_number+bukan+outlet+dari+member+$hp_sales";
        }
	}
	my $pilihan = {};
	$pilihan->{product} = $q->param('product');
	$pilihan->{pkg_id} = $q->param('pkg_id');

	my $qty = $q->param('qty');

	# topup owner free
	if ($config::topup_owner_free) {
		my $member_id_admin = $db->query('select member_id from admin where admin_id =?', $s->adm_id )->list;
		unless ($member_id_admin == 1) {
			return "/view/transaction/new_topup?error=maaf+anda+bukan+system+owner";
		}
		# cek site
		my ($site_id_sd, $site_name) = $db->query("select site_id,site_name from rs_chip inner join sd_chip using(sd_id) inner join site using(site_id) 
                                        where rs_number=?", $rs_number)->list;
	        unless($s->{site_id}){
        	        $s->{site_id} = $site_id_sd;
	        }
			unless($config::topup_web_empty){
        	if($site_id_sd != $s->{site_id}){
                	return "/view/transaction/new_topup?error=stock+rs+number+$rs_number+hanya+diisi+admin+$site_name";
	        }}
		# cek ref type id
		my ($ref_type_id, $ref_type_name) = $db->query("select ref_type_id, ref_type_name from rs_chip inner join sd_chip using(sd_id) inner join stock_ref_type using(ref_type_id) where rs_number=?", $rs_number)->list;

		# asign, or, and match ref_type_id if stockbase_admin is set
	        if ($config::stockbase_admin) {
			unless($s->{ref_type_id}){
                        $s->{ref_type_id} = $site_id_sd;
	                }
					unless($config::topup_web_empty){
        	        if($ref_type_id != $s->{ref_type_id}){
                	        return "/view/transaction/new_topup?error=stock+rs+number+$rs_number+hanya+diisi+admin+$ref_type_name";
               		}}
		}

		# transaksi
		_transaksi($db, $log, $hp_sales, $pilihan, $rs_number, $qty);
	} 
	# non topup owner free 
	else {
		# cek member
		unless($config::topup_web_empty){
		if($member_id_rs != $member_id_sales){
        		return "/view/transaction/new_topup?error=rs+number+$rs_number+bukan+outlet+dari+member+$hp_sales";
	        }}
		#cek site
		my ($site_id_sd,$site_name) = $db->query("select site_id,site_name from rs_chip inner join sd_chip using(sd_id) inner join site using(site_id) 
                                        where rs_number=?", $rs_number)->list;
	        unless($s->{site_id}){
        	        $s->{site_id} = $site_id_sd;
	        }
			unless ($config::topup_web_empty){
        	if($site_id_sd != $s->{site_id}){
                	return "/view/transaction/new_topup?error=stock+rs+number+$rs_number+hanya+diisi+admin+$site_name";
	        }}
		
		#cek ref_type_id
		my ($ref_type_id, $ref_type_name) = $db->query("select ref_type_id, ref_type_name from rs_chip inner join sd_chip using(sd_id) inner join stock_ref_type using(ref_type_id) where rs_number=?", $rs_number)->list;
              
		# asign, or, and match ref_type_id if stockbase_admin is set
	        if ($config::stockbase_admin) {
			unless($s->{ref_type_id}){
                        $s->{ref_type_id} = $site_id_sd;
	                }
					unless ($config::topup_web_empty){
        	        if($ref_type_id != $s->{ref_type_id}){
                	        return "/view/transaction/new_topup?error=stock+rs+number+$rs_number+hanya+diisi+admin+$ref_type_name";
               		}}
		}

		# transaksi 
		_transaksi($db, $log, $hp_sales, $pilihan, $rs_number, $qty);
	}
	return "/view/transaction/list?from=$today&until=$today";
}

sub _transaksi {
	my ($db, $log, $msisdn, $pilihan, $rs_number, $qty) = @_; 
	
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);

	my $smsc =  $db->query("select smsc_id, smsc_name from smsc where smsc_status='active' order by rand() limit 1")->list;
	
	# pr hanya mencari pin berdasarkan $msisdn
	my ($pin) = $db->query("select pin from user where username=? and status='Active'", $msisdn)->list;

	my $ts;
	if (defined $pilihan->{product}) {
       		my $ref_id = $pilihan->{product};

		$ts = common::now("%Y-%m-%d %H:%M:%S");
		my @ts = split (/\ /,$ts);
		$ts = join ('+',@ts);
               	my $keyword = $db->query("select keyword from stock_ref where stock_ref_id = ?", $ref_id)->list;
                my $url = "msisdn=$msisdn&msg=$keyword\.$qty\.$rs_number\.$pin&ts=$ts&smsc=$smsc";
		$log->warn("GET : http://localhost:8181/service?$url");
       	        my $response = $ua->get("http://localhost:8181/service?$url");
	
		if ($response->is_success) {
		     $log->warn($response->decoded_content);  # or whatever
		} else {
		     $log->warn($response->status_line);
		}
		sleep 1;
	}
	
	if (defined $pilihan->{pkg_id}) {
                my $pkg_id = $pilihan->{pkg_id};
       	        my $result = $db->query('select stock_ref_id, pkg_qty from package_detail where pkg_id=?', $pkg_id);
		while (my ($stock_ref_id, $pkg_qty) = $result->list) {
			$ts = common::now();
	       		my @ts = split (/\ /,$ts);
        	        $ts = join ('+',@ts);
       	        	my $keyword = $db->query("select keyword from stock_ref where stock_ref_id = ?", $stock_ref_id)->list;
                       	
			my $url = "msisdn=$msisdn&msg=$keyword\.$pkg_qty\.$rs_number\.$pin&ts=$ts&smsc=$smsc";
                        
			$log->warn("GET : http://localhost:8181/service?$url");
                	my $response = $ua->get("http://localhost:8181/service?$url");
       	        
			if ($response->is_success) {
        	       		$log->warn($response->decoded_content);  # or whatever
			} else {
        			$log->warn($response->status_line);
	        	}
			sleep 1;
		}
	}
}

# gak kepake jadinya sub _inject ini
sub _inject {
	my ($s, $q, $db, $log) = @_;
	my $today = common::today();
	# Memasukkan sampai ke queue storage (table topup)
	# ------------------------------------------------

	# member id
        my $member_id = $db->query(
                'select member_id from admin where admin_id=?', $s->adm_id,
        )->list
                ||return "/view/transaction/new_topup?error=check+member";
	
	# rs id
        my $rs_number = $q->param('rs_number');
        $rs_number =~ s/0/62/ if $rs_number =~ /^0/;
        my $rs_id = $db->query(
                'select rs_id from rs_chip where rs_number=?', $rs_number,
        )->list
                ||return "/view/transaction/new_topup?error=rs+number+invalid";
	
	#check rs number with member
	my $member_id_rs = $db->query('select member_id from rs_chip where rs_number=?',$rs_number)->list;
	my $hp_sales = $q->param('hp_sales');
	$hp_sales =~ s/0/62/ if $hp_sales =~ /^0/ ;
	my $member_id_sales = $db->query('select member_id from user where username=?',$hp_sales)->list;
	return "/view/transaction/new_topup?error=maaf,+trx+hp+tidak+boleh+kosong" if $hp_sales eq '';
	if($member_id_rs != $member_id_sales){
		return "/view/transaction/new_topup?error=rs+number+$rs_number+bukan+outlet+dari+member+$hp_sales";
	}
	
	#site_id of sd_chip and site_id of admin valid or invalid
	my ($site_id_sd,$site_name) = $db->query("select site_id,site_name from rs_chip inner join sd_chip using(sd_id) inner join site using(site_id) 
					where rs_number=?", $rs_number)->list;
	unless($s->{site_id}){
		$s->{site_id} = $site_id_sd;
	}
	
	if($site_id_sd != $s->{site_id}){
		return "/view/transaction/new_topup?error=stock+rs+number+$rs_number+hanya+diisi+admin+$site_name";
	}
	
	# topup qty
        my $qty = $q->param('qty');
	
	# stock ref-id
	if ($q->param('product')) {
		my $ref_id = $q->param('product');
	
		# validation 6 haurs interval
		my ($count) = $db->query("select count(*) from topup where topup_status in ('', 'W', 'P', 'S') and stock_ref_id=? and rs_id=? and topup_qty=? and topup_ts >= (DATE_SUB(now(), INTERVAL 6 hour))", $ref_id, $rs_id, $qty)->list;
		return "/view/transaction/list?from=$today&until=$today" if($count>0);
		
		$db->begin();
		$db->insert('topup', {
			member_id => $member_id, stock_ref_id => $ref_id,
			topup_qty => $qty,	 rs_id => $rs_id,
			topup_ts  => \['now()'],
		});
		my $top_id = $db->last_insert_id(0,0,0,0);
		$db->insert('topup_web', {topup_id=>$top_id, admin_log_id=>$s->{adm_log_id}});
		$db->commit();
        }
		
	if ($q->param('pkg_id')) {
		my $pkg_id = $q->param('pkg_id');
	        my $result = $db->query('select stock_ref_id, pkg_qty from package_detail where pkg_id=?', $pkg_id);
		while (my ($stock_ref_id, $pkg_qty) = $result->list) {
			my $topup_qty = $pkg_qty * $qty;

                	$db->begin();
	                $db->insert('topup', {
        	                member_id => $member_id, stock_ref_id => $stock_ref_id,
                	        topup_qty => $topup_qty,       rs_id => $rs_id,
                        	topup_ts  => \['now()'],
	                });
        	        my $top_id = $db->last_insert_id(0,0,0,0);
                	$db->insert('topup_web', {topup_id=>$top_id, admin_log_id=>$s->{adm_log_id}});
	                $db->commit();
			sleep 1;
		}
	}
	return "/view/transaction/list?from=$today&until=$today";
}

sub deposit {
        my ($s, $q, $db, $log) = @_;

	# this web admin interface is part of messaging gtw
	# which is responsible only to record deposit queue (table deposit)

	my $adm_id = $s->adm_id;
	$log->warn("adm_id: ", $adm_id);

	# paradigm change : bukan khusus system owner (mem_id=1),
	# tetapi khusus untuk para admin
	my $no_hp_tujuan = $q->param('no_hp');

	my ($user_id,$member_id) = $db->query(
		'select user_id, member_id from user where username=?', $no_hp_tujuan,
	)->list;
	return '/view/transaction/new_deposit?error=not+valid+no_hp' unless $user_id;
	return '/view/transaction/new_deposit?error=no_hp+invalid' unless $member_id;

	my $nominal = $q->param('amount')||return '/view/transaction/new_deposit?error=insert+nominal';
	$nominal = 1000*$nominal;	

	$db->begin();
	$db->insert('deposit_web',
		{admin_log_id => $s->{adm_log_id}, user_id => $user_id, dep_amount => $nominal}
	);
	$db->commit();

	return "/view/member/list?status=Active&username=$no_hp_tujuan";
}

sub reversal {
	
	my ($s, $q, $db, $log) = @_;
	my $trans_id = $q->param('trans_id');
	my $no_reply = $q->param('no_reply')||0;
	my $ops = $q->param('op');
	$log->warn("trans_id = $trans_id, no reply = $no_reply, ops = $ops");
	$db->begin;
	eval {
		my $trx = daemon::trx->new($db);
		$trx->reversal($trans_id, $s->adm_id, $no_reply, $ops, $log);
	};
	if ($@) {
		$log->warn($@);
		$db->rollback;
	}
	else {
		$db->commit;
	}


	return "/view/transaction/detail?trans_id=$trans_id";
}
sub reversal_uniq {

	my ($s, $q, $db, $log) = @_;
	my $trans_id = $q->param('trans_id');
	my $group = $s->adm_gid;
	
	# reversal unique
	# cek adm_gid nya apabila selain 2(accounting) maka gak update menjadi need approve
	unless ($group == 2) {
		$db->query("update transaction set reversal_approve='NEED_APPROVE' where trans_id = ?", $trans_id);
        }
	
	return "/view/transaction/detail?trans_id=$trans_id&group_id=$group";
}
sub lock_reversal {

	my ($s, $q, $db, $log) = @_;
	my $trans_id = $q->param('trans_id');
	my $group = $s->adm_gid;
	my $op = $q->param('op');	
	
	if ($group eq 2) {
		# jika $lock = 1 berarti menuju lock reversal	
		# jika $lock = 2 berarti sudah di lock gak ada update
		if ($op eq 'LOCK') {
			$db->query("update transaction set reversal_approve='LOCK' where trans_id=?", $trans_id);
		}
		if ($op eq 'LOCK REVERSAL') {
		}
		if ($op eq 'NEED APPROVE') {
			$db->query("update transaction set reversal_approve='APPROVE' where trans_id=?", $trans_id);
		}	
	}
	
	# reversal_approve bisa 'LOCK','APPROVE', dan default ''
	return "/view/transaction/detail?trans_id=$trans_id&group_id=$group";
}


sub lock_totalan {

	my ($s, $q, $db, $log) = @_;
	my $group = $s->adm_gid;
	$log->warn('group ', $group);
	my $from = $q->param('from');	
	my $until = $q->param('until');  
	$db->begin();
	eval { 
		if ($group == 1) { 
			$db->query("update transaction set reversal_approve='LOCK_BEST' where trans_date >= str_to_date(?,'%d-%m-%Y') and trans_date <= str_to_date(?,'%d-%m-%Y')", $from, $until);
		$log->warn("update transaction set reversal_approve='LOCK_BEST' where trans_date >= str_to_date('$from','%d-%m-%Y') and trans_date <= str_to_date('$until','%d-%m-%Y')");
		}
	};
	if ($@) {
		$log->warn($@);
		$db->rollback();
	}
	$log->warn("commit");
	$db->commit();
	# 'LOCK','APPROVE', dan default '', 'LOCK_BEST', 'LOCK_TOTAL'
	return "/view/transaction/lock_totalan?from=$from&until=$until";
}

sub approve {
	my ($s, $q, $db, $log) = @_;
	
	my @topup_id = $q->param('topup_id');
	my $date = common::today;
	my $op = $q->param('op');
	my $topup_status = '';
	$topup_status = 'W' if $op eq 'Retry';
	my $status = 'WA';
	$status = 'W' if $op eq 'Retry';
	$log->warn("topup_id : ", @topup_id);
	
	foreach(@topup_id){
		$db->query("update topup set topup_status=? where topup_id=?",$topup_status, $_);
	}

	return "/view/transaction/list?from=$date&until=$date&keyword=&site_id=0&sd_name=&sd_type_id=0&outlet_id=0&rs_number=&member_name=&status=$status&admin_name=&rs_type_id=0";
}

sub transfer {
	my ($s, $q, $db, $log) = @_;

	my $adm_id = $s->adm_id;
	$log->warn("adm_id: ", $adm_id);

	my $no_hp_tujuan = $q->param('no_hp');

	my ($user_id,$user_member_id) = $db->query(
		'select user_id, member_id from user where username=?', $no_hp_tujuan,
	)->list;
	return '/view/transaction/new_transfer?error=not+valid+no_hp' unless $user_id;

	my $nominal = $q->param('amount')||return '/view/transaction/new_transfer?error=insert+nominal';
	$nominal = 1000*$nominal;

	$db->begin();
	
	# Mengurangi saldo member yang melakukan transfer
	my $adm_member_id = $db->query('select member_id from admin where admin_id=?',$adm_id)->list;
	my $trx = daemon::trx->new($db);
	my $member = $trx->lock_member($adm_member_id);
	
	$trx->trx('tran');
	$trx->mutation(-$nominal,$member);

	# Menambah saldo member yang menerima transfer
	$member = $trx->lock_member($user_member_id);
	
	$trx->trx('tran');
	$trx->mutation($nominal,$member);
	
	$db->commit();

	return "/view/transaction/list";
}


1;
