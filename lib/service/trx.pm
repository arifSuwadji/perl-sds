package service::trx;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use service ();
use daemon::trx();
use service::topup ();
use Math::Round qw(nearest);

sub topup {
	my ($db, $log, $param, $msg) = @_;
	
	my $response;
	
	my $rs_number = $msg->[2];
        $rs_number =~ s/0/62/ if $rs_number =~ /^0/;

	# bukan topup owner free
	unless ($config::topup_owner_free) {

		# free canvaser
		if ($config::free_canvaser) {
	               $param->{member_id} = $db->query("select member_id from rs_chip where rs_number =?", $rs_number)->list;
        	}
		# biasa
		$response = _topup($db, $log, $param, $msg, $rs_number);
		return $response;
	}
 	
	# jika free canvasser maka mutasi atau pemotongan saldo sesuai member yang melakukan sms
	# jadi tanpa harus merubah member id berdasarkan rs chip (config = 1)
	unless($config::mutation_by_sms){ # config = 0
		$param->{member_id} = $db->query("select member_id from rs_chip where rs_number =?", $rs_number)->list;
	}

	# topup owner free
	$response = _topup($db, $log, $param, $msg, $rs_number);
	return $response;	
}

sub _topup { 
	my ($db, $log, $param, $msg, $rs_number) = @_;	
	# XL5.100.0817.pin.2
	# service::trx ini adalah bagian dari messaging gtw, bukan bagian dari trx/core proc,
	# jadi rolenya hanya sebatas memasukkan ke topup queue (table topup)
	# topup_id, rs_id, member_id, stock_ref_id, topup_qty
	# selebihnya (cek saldo, stock availability, etc.) diolah oleh core proc

	my $topup = service::topup->new($db, $log, $param, $rs_number, {approval => 0});

	# keyword & qty argument for method process_one
	my $keyword = $msg->[0];
	my $qty = $msg->[1]; $qty =~ s/[\-\D]//g; # there might be spaces,commas,etc.

	# topup ke rs, stock-ref, dan qty yg sama hrs menunggu 6 jam
	# atau menggunakan sequence yg berbeda
	my $seq = $msg->[4] || 1;

	# execute method process_one
	my $error_msg =	$topup->process_one($keyword, $qty, $seq);
	return {sms_outbox => $error_msg} if $error_msg;

	my $reply_msg = {};
	$reply_msg->{sms_outbox_rs} = "transfer stock Pulsa Anda ke nomor $topup->{rs_number} sebesar $keyword=$qty total $topup->{total_price} telah berhasil di proses oleh $topup->{member_name}. Terima Kasih";
	$reply_msg->{rs_id} = $topup->{rs_id};
	return $reply_msg;
}

sub multi_c {
	my ($db, $log, $param, $msg) = @_;
	return multi($db, $log, $param, $msg, {credit => 1});
}

sub sgo_mandiri {
	my ($db, $log, $param, $msg) = @_;
	# "TM.S20.10.AS5.5.0812345678.1234.087827181711"
	my $hp_outlet = pop(@$msg);
	$hp_outlet =~ s/0/62/ if $hp_outlet =~ /^0/;
	return multi($db, $log, $param, $msg, {payment_gateway => 1, hp_outlet => $hp_outlet});
}

sub multi {
	my ($db, $log, $param, $msg, $attr) = @_;
	$attr->{credit} ||= 0;
	$attr->{payment_gateway} ||= 0;
	$attr->{hp_outlet} ||=0;

	# "M.S20.10.AS5.5.0812345678.1234"
	# $msg->[0] : M
	# $msg->[1] : S20
	# $msg->[2] : 10
	# ...

	# remove pin
	my $response;
	
	pop(@$msg);

	# rs number
	my $rs_number = pop(@$msg);
	$rs_number =~ s/0/62/ if $rs_number =~ /^0/;

	#insert no hp outlet - trx sgo mandiri
	if($attr->{hp_outlet} ne 0){
		my $outlet_id = $db->query("SELECT outlet_id FROM rs_chip WHERE rs_number =?", $rs_number)->list;
		my $find_outlet_id = $db->query("SELECT outlet_id FROM user WHERE username=?", $attr->{hp_outlet})->list;
		unless($find_outlet_id){
			$db->insert('user',{
				outlet_id => $outlet_id,  username  => $attr->{hp_outlet},
				pin       => '1234',      status    => 'Active',
			});
		}
	}

	# bukan topup owner free
	unless ($config::topup_owner_free) {
		# free canvaser
		if ($config::free_canvaser) {
	               $param->{member_id} = $db->query("select member_id from rs_chip where rs_number =?", $rs_number)->list;
        	}
		# biasa
		$response = _multi($db, $log, $param, $msg, $rs_number, $attr);
		return $response;
	}
	
	# jika free canvasser maka mutasi atau pemotongan saldo sesuai member yang melakukan sms
	# jadi tanpa harus merubah member id berdasarkan rs chip (config = 1)
	unless($config::mutation_by_sms){ # config = 0
		$param->{member_id} = $db->query("select member_id from rs_chip where rs_number =?", $rs_number)->list;
	}

	# topup owner free
	$response = _multi($db, $log, $param, $msg, $rs_number, $attr);
	return $response;
}

sub _multi {
	my ($db, $log, $param, $msg, $rs_number, $attr) = @_;

	my $topup = service::topup->new($db, $log, $param, $rs_number,
		{credit => $attr->{credit}, payment_gateway => $attr->{payment_gateway}} );

	my $reply_msg = {};

	# remove keyword from message array
	shift(@$msg);

	$db->begin();

	# eat them, one by one... errr sorry, i meant two by two.
	while (@$msg) {

		# FIRST SHIFT : product keyword
		my $keyword = shift(@$msg);

		# SECOND SHIFT : quantity
		my $qty = shift(@$msg);

		my $error_msg =	$topup->process_one($keyword, $qty);
		return {sms_outbox => $error_msg} if $error_msg;
	}

	$db->commit();

	if ($config::waiting_approve){
		$topup->{reply} .= "total $topup->{total_price} masih menunggu approval. Terima Kasih";
		$reply_msg->{sms_outbox} = $topup->{reply}; 
		$reply_msg->{rs_id} = $topup->{rs_id};
		return $reply_msg;
	}

	$topup->{reply} .= "total $topup->{total_price} telah berhasil diproses oleh $topup->{member_name}. Terima Kasih";
	$reply_msg->{sms_outbox_rs} = $topup->{reply};
	$reply_msg->{rs_id} = $topup->{rs_id};

	return $reply_msg;
}

sub multi_two{
	my ($db, $log, $param, $msg) = @_;
	
	my $response;
	
	#keyword product from sms
	my @keyword;
	my $n = scalar(@$msg);
	for(0 .. $n-1){
		if(@$msg[$_] =~ m/(X|x)/g){
			push @keyword,@$msg[$_];
		}
		if(@$msg[$_] =~ m/(X|x)/g){
			push @keyword,@$msg[$_];
		}
	}
	my $count_keyword = scalar(@keyword);
	$log->warn("keyword product from sms : ", @keyword , " count : ", $count_keyword);
	
	#keyword product from db
	my $keyword_db = $db->query("select group_concat(keyword) as keyword from stock_ref where stock_ref_name like 'XL%'")->list;
	my @keyword_db = split /,/,$keyword_db;
	my $count_keyword_db = scalar(@keyword_db);
	$log->warn("keyword product from db : ", @keyword_db , " count : ", $count_keyword_db);
	
	my $reply_msg = {};
	
	if($count_keyword != $count_keyword_db){
		$reply_msg->{sms_outbox} = "keyword produk tidak lengkap";
		return $reply_msg;
	}

	# remove pin
	pop(@$msg);
	
	# rs number
	my $rs_number = pop(@$msg);
	$rs_number =~ s/0/62/ if $rs_number =~ /^0/;
	
	# bukan topup owner free
	unless ($config::topup_owner_free) {
		# free canvaser
		if ($config::free_canvaser) {
	               $param->{member_id} = $db->query("select member_id from rs_chip where rs_number =?", $rs_number)->list;
        	}
		# biasa
		$response = _multi_two($db, $log, $param, $msg, $rs_number);
		return $response;
	}
	# topup owner free
	$param->{member_id} = $db->query("select member_id from rs_chip where rs_number =?", $rs_number)->list;
	$response = _multi_two($db, $log, $param, $msg, $rs_number);
	return $response;	
}

sub _multi_two {
	my ($db, $log, $param, $msg, $rs_number) = @_;

	my $topup = service::topup->new($db, $log, $param, $rs_number);

	my $reply_msg = {};

	# remove keyword from message array
	shift(@$msg);

	# eat them, one by one... errr sorry, i meant two by two.
	while (@$msg) {
		# FIRST SHIFT : product keyword
		my $keyword = shift(@$msg);
	
		# SECOND SHIFT : quantity
		my $qty = shift(@$msg);

		my $error_msg =	$topup->process_one($keyword, $qty);
		return {sms_outbox => $error_msg} if $error_msg;
	}

	$db->commit();
	$topup->{reply} .= "total $topup->{total_price} masih menunggu approval. Terima Kasih";
	$reply_msg->{sms_outbox} = $topup->{reply};
	$reply_msg->{rs_id} = $topup->{rs_id};

	return $reply_msg;
}

sub transfer {
	my ($db, $log, $param, $msg) = @_;
	#format = TD.nomor.nominal.pin [Transfer Downline]
	my $reply_msg;
	my $mesg;	
	my $no_hp_tujuan = $msg->[1];
	my $adm_member_id = $db->query('select member_id from user where user_id=?',$param->{user_id})->list;
	my ($user_id,$user_member_id, $parent_id) = $db->query(
		'select user_id, member_id, parent_id from member inner join user using(member_id) where username=?', $no_hp_tujuan,
	)->list;
	unless ($user_id) {
		$mesg = "number tidak terdaftar";
		$reply_msg = {sms_outbox => $mesg};
		return $reply_msg;
	}
	if ($parent_id ne $adm_member_id) {
		$mesg = "nomor bukan downline anda";
		$reply_msg = {sms_outbox => $mesg};
		return $reply_msg;
	}
	my $nominal = $msg->[2];
	#$nominal = 1000*$nominal;
	my $balance = $db->query('select member_balance from user inner join member using(member_id) where user_id =?', $param->{user_id})->list;
	$balance =~ s/\.000$//;
	if ($balance < $nominal) {
		$mesg = "saldo anda Rp.$balance tidak mencukupi untuk transfer sejumlah $nominal ke downline anda";
		$reply_msg = {sms_outbox => $mesg};
		return $reply_msg;

	}
	$db->begin();
	
	# Mengurangi saldo member yang melakukan transfer
	my $trx = daemon::trx->new($db);
	my $member = $trx->lock_member($adm_member_id);
	
	$trx->trx('tran');
	$trx->mutation(-$nominal,$member);

	my $last_balance = $db->query('select member_balance from user inner join member using(member_id) where user_id =?', $param->{user_id})->list;
	# Menambah saldo member yang menerima transfer
	$member = $trx->lock_member($user_member_id);
	
	$trx->trx('tran');
	$trx->mutation($nominal,$member);
	
	$db->commit();
	$mesg = "transfer sejumlah $nominal ke $no_hp_tujuan telah berhasil, saldo akhir $last_balance";	
	$reply_msg = {sms_outbox => $mesg};
	return $reply_msg;
}

1;
