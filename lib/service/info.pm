package service::info;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use service ();


sub change_pin {
	my ($db, $log, $param, $msg) = @_;

	# GP.pinBaru.pinLama
	# pin baru dalam hal ini adalah : $msg->[1]
	$db->query('update user set pin=? where user_id=?', $msg->[1], $param->{user_id});
	my $reply_msg = {sms_outbox=>"pin anda telah ter-update"};
	return $reply_msg;
}

sub report {
        my ($db, $log, $param, $msg) = @_;
	#REP.ddmmyy.pin
	my ($dd,$mm,$yy) = $msg->[1] =~ m/(\d{2})(\d{2})(\d{2})/;
	my $ymd = "20$yy-$mm-$dd";
	my $member_id = $db->query("select member_id from user where user_id=?", $param->{user_id})->list;
	my $text = $db->query("select ifnull(group_concat(sum_keyword),'tidak ada topup sukses pada tanggal tersebut') from (select concat(keyword,' ',sum(topup_qty)) as sum_keyword from topup inner join topup_sms using(topup_id) inner join stock_ref using(stock_ref_id) inner join transaction using (trans_id) where trans_date=? and member_id=? and topup_status='S' group by stock_ref_id) as summary", $ymd, $member_id)->list;
	my $reply_msg = {sms_outbox=>$text};
	return $reply_msg;
}

sub balance {
	my ($db, $log, $param, $msg) = @_;
	#s.pin
	my $balance = $db->query('select member_balance from user inner join member using(member_id) where user_id =?', $param->{user_id})->list;
	$balance =~ s/\.000$//;
	my $reply_msg = {sms_outbox=> "saldo anda saat ini sebesar $balance rupiah"};
	return $reply_msg;
}

sub outlet_balance {
	my ($db, $log, $param, $msg) = @_;

	my ($balance, $plafond) = $db->query('select balance, plafond from user inner join outlet using (outlet_id) where user_id =?', $param->{user_id})->list;
	my $reply_msg = {sms_outbox=> "jumlah tagihan anda saat ini sebesar $balance rupiah, quota: Rp ".($balance + $plafond)};
	return $reply_msg;
}

sub complain {
	my ($db, $log, $param, $msg) = @_;

	return {};
}

sub check_payment {
	my ($db, $log, $param, $msg) = @_;

	my $outlet_id = $param->{outlet_id};
	my @message = split /\./ , $param->{msg};
	my($inv_date,$amount,$status,$trans_date) = $db->query("select inv_date, amount, status, date_format(trans_date,'%d-%m-%Y') from invoice inner join transaction using (trans_id) where outlet_id=? and inv_date <> due_date and inv_date = str_to_date(?,'%d%m%Y')",$param->{outlet_id},$message[1])->list;
	$log->warn("outlet_id : ", $outlet_id || 0 ," invoice date : ", $inv_date || 0 , " amount : ", $amount || 0, " status : ",$status || 0);
	$log->warn("message : ", $param->{msg});
	$log->warn("date : ", $message[1]);
	my $reply_msg = {sms_outbox => "tagihan anda dengan no invoice $outlet_id/$inv_date sebesar Rp. $amount sudah dilunasi tgl. $trans_date.Terima kasih"};
	$reply_msg = {sms_outbox => "tagihan anda dengan no invoice $outlet_id/$inv_date sebesar Rp. $amount belum lunas.Terima kasih"} if $status eq 'Unpaid';
	return $reply_msg;
}

sub dompul_sale {
	my ($db, $log, $param, $msg) = @_;

	# DS.nomor.product.qty.pin
	my $reply_msg;
	my $mesg;
	$msg->[1] =~ s/^0/62/ if $msg->[1] =~ /^0/;
	my $rs_number = $db->query("select rs_id from rs_chip where rs_number=?", $msg->[1])->list;
	unless ($rs_number) {
		$mesg = "ro-number tidak terdaftar";
		$reply_msg = {sms_outbox => $mesg};
		return $reply_msg;
	}
	my $outlet = $db->query("select outlet_name from outlet inner join rs_chip using (outlet_id) where rs_id=?", $rs_number)->list;
	my $ref_type_id = $db->query("select ref_type_id from stock_ref_type where ref_type_name=?", $msg->[2])->list;
	#my $res = $db->query ("select ref_type_id, ref_type_name from stock_ref_type where ref_type_id > 11 and ref_type_name like 'Dompul-%'");
	#my @list = $res->hashes;
	unless ($ref_type_id) {
		$mesg = "type product tidak tersedia";
		$reply_msg = {sms_outbox => $mesg};
		return $reply_msg;
	}
	my $member_id = $db->query("select member_id from user where user_id=?", $param->{user_id})->list;
	$mesg = "pencatatan penjualan $msg->[2] ke outlet $outlet sejumlah $msg->[3] telah berhasil";	
	my $sms_id = $db->last_insert_id(0,0,0,0);
	$db->insert('dompul_sale',{
		member_id => $member_id,
		ref_type_id => $ref_type_id,
		qty_sale => $msg->[3],
		rs_id => $rs_number,
		sms_id => $sms_id,
		sale_ts => \['now()'],	 
	});	

	$reply_msg = {sms_outbox => $mesg};
	return $reply_msg;
}
sub reg_perdana {
	my ($db, $log, $param, $msg) = @_;

	# REG.nomor
	my $reply_msg;
	my $mesg;

	$msg->[1] =~ s/^0/62/ if $msg->[1] =~ /^0/;
	my $id = $db->query("select perdana_id from msisdn_perdana where perdana_number=?", $msg->[1])->list;
	unless ($id){
		$mesg = "maaf nomor $msg->[1] tidak terdaftar di system kami";
        $reply_msg = {sms_outbox => $mesg};
        return $reply_msg;
	}
	my $status = $db->query("select status from msisdn_perdana where perdana_id=?", $id)->list;
	if ($status eq 'non-Active'){
		$mesg = "maaf, nomor $msg->[1] sudah ter-Registrasi di System kami";
        	$reply_msg = {sms_outbox => $mesg};
	        return $reply_msg;
	}elsif($status eq 'wait-Response'){
		$mesg = "maaf, nomor $msg->[1] sedang menunggu jawaban operator";
        	$reply_msg = {sms_outbox => $mesg};
	        return $reply_msg;
	}
	$db->query("update msisdn_perdana set status='Approve' where perdana_id=?", $id);
	$mesg = "REG nomor $msg->[1] akan segera kami proses";
	$reply_msg = {sms_outbox => $mesg};
	return $reply_msg;
}

sub sgo_token {
	my ($db, $log, $param, $msg) = @_;
	#CT.notoken.rsnumber.pin

	my $mesg;
	my @msg_count = @$msg;
	my $rs_segment = $#msg_count;
	$rs_segment -= 1;
	$log->warn("rs segment : ", $rs_segment);
	my $rs_number = $msg->[$rs_segment];
	$log->warn("rs number after segment : ", $rs_number);
	$rs_number =~ s/^0/62/ if $rs_number =~ /^0/;
	my $rs_id = $db->query('SELECT rs_id FROM rs_chip WHERE rs_number=?', $rs_number)->list;
	my $token_segment = $#msg_count;
	$token_segment -= 2;
	my $token_sgo = $msg->[$token_segment];
	unless($rs_id){
		$mesg = "no rs tidak terdaftar";
	}else{
		$mesg = "Anda telah melakukan konfirmasi token untuk trx ";
		my $set = 0;
		my $data = $db->query("SELECT topup_id, keyword, topup_qty FROM topup INNER JOIN stock_ref USING(stock_ref_id)
							WHERE rs_id=? AND topup_ts > CURDATE() AND topup_status='CT'", $rs_id);
		while(my $row = $data->hash){
			$set = 1;
			$db->query("UPDATE topup SET token_sgo=? WHERE topup_id=?", $token_sgo, $row->{topup_id});
			$mesg .= "$row->{keyword} : $row->{topup_qty} ";
		}
		if($set){
			$mesg .= "rs $rs_number.Terima Kasih";
		}else{
			$mesg = "Konfirmasi token gagal, trx rs $rs_number tidak ditemukan.Terima kasih";
		}
	}
	
	my $reply_msg = {sms_outbox => $mesg};
	return $reply_msg;
}

1;

