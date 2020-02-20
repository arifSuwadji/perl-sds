package service::topup;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';
use Math::Round qw(nearest);

use config;


sub new {
	my $class = shift;
	my $self  = {};
	my ($db, $log, $param, $rs_number, $attr)
		= @$self{qw/db log param rs_number attr/} = @_;
	bless($self, $class);

	# additional attributes
	$attr->{approval} = 1 unless defined $attr->{approval}; # jk 0 tdk direset default
	$attr->{credit}   = 0 unless defined $attr->{credit}; # defaultnya 0 (cash)
	$attr->{payment_gateway} = 0 unless defined $attr->{payment_gateway}; # payment gateway bank

	# rs_id
	$self->{rs_id} = $db
		-> select('rs_chip', ['rs_id'], {rs_number => $rs_number})
		-> list;

	@$self{qw/outlet_name rs_type_id outlet_type_id/} = $db->query("select outlet_name, rs_type_id, outlet_type_id from rs_chip inner join outlet using (outlet_id) where rs_number = $rs_number")->list;
	$self->{member_name} = $db->select('member',['member_name'], {member_id => $param->{member_id}})->list;
	$self->{reply} = "transfer stock Pulsa Anda ke nomor $rs_number sebesar ";
	$self->{total_price} = 0;

	return $self;
}


# SUB process_one
# ----------------
# returns : error message, empty string means no error
#
sub process_one {
	my ($self, $keyword, $qty, $seq) = @_;

	my ($db, $rs_id, $rs_number, $rs_type_id, $outlet_type_id, $param, $log);
	eval "\$$_ = \$self->{$_}" foreach
		(qw/db rs_id rs_number rs_type_id outlet_type_id param log/);

	my $error_msg = '';

	$self->{reply} .= "$keyword = ";

	# stock reference : axis, dompul, esia, mkios, evoTransf, etc.
	my ($stock_ref_id, $ref_type_id) = $db->select('stock_ref', ['stock_ref_id', 'ref_type_id'], {keyword => $keyword})->list;
	return "keyword tidak valid" unless $stock_ref_id;
	unless ($rs_id or $ref_type_id == 9) {
		return "nomor rs chip yang anda masukkan salah";
	}

	my ($price, $nominal) =  $db->query(
		'select price, nominal from outlet_pricing inner join stock_ref using(stock_ref_id)  where stock_ref_id=? and outlet_type_id=?',
		$stock_ref_id, $outlet_type_id,
	)->list;
	if($config::take_price){
		($price, $nominal) =  $db->query(
			'select price, nominal from pricing inner join stock_ref using(stock_ref_id)  where stock_ref_id=? and rs_type_id=?',
			$stock_ref_id, $rs_type_id,
		)->list;
	}

	$log->warn("outlet type id : ", $outlet_type_id);
	$log->warn("stock ref id : ", $stock_ref_id);
	# quantity
	return "qty tidak valid, silakan ulangi request anda" unless $qty and $qty >0 ;

	if ($nominal) {
		$self->{total_price} += $price * $qty;
	} elsif ($ref_type_id == 9) {
		$self->{total_price} = $qty;
	} else {
		$self->{total_price} += nearest( 0.01, (1-$price/100) * $qty );
	}
	$log->warn("qty=$qty, stock_ref_id=$stock_ref_id, rs_id=$rs_id");
	$self->{reply} .= "$qty,";

	# topup ke rs, stock-ref, dan qty yg sama hrs menunggu 6 jam
	# atau menggunakan sequence yg berbeda
	$seq ||= 1;

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
			$error_msg = "pengisian $keyword ke $rs_number sejumlah $qty telah/sedang dilakukan. tunggu dlm 6 jam utk mengulang";
			die('duplicate topup request found');
		}

		# "TRY" BLOCK BEGINS
		my $topup_status ='';
		$topup_status = 'WA' if $config::waiting_approve and $self->{attr}->{approval};
		# attr->approval default nya = 1

		$db->insert('topup', {
			stock_ref_id => $stock_ref_id,       rs_id     => $rs_id,
			member_id    => $param->{member_id}, topup_qty => $qty,
			topup_status => $topup_status,	     topup_ts     => \['now()'],
			credit       => $self->{attr}->{credit}, payment_gateway => $self->{attr}->{payment_gateway},
		});

		# scr default, sequence terisi: 1 (topup yg pertama, belum diulang)
		my $topup_id = $db->last_insert_id(0,0,0,0);
		$db->insert('topup_sms', {
			topup_id => $topup_id, sms_id => $param->{sms_id},
			sequence => $seq, dest_msisdn => $rs_number,
		});
	};

	# "CATCH" BLOCK BELOW
	if ($@) {
		$self->{log}->warn("transaction aborted: $@");
		$db->rollback();
		return $error_msg if $@ =~ /duplicate topup/;
		return "transaksi $keyword ke $rs_number sejumlah $qty GAGAL. silakan coba kembali.";
	}

	return 0; # 0 means: NO ERROR
}


1;

