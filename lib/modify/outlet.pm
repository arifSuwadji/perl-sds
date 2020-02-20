package modify::outlet;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub add_outlet {
	my ($s,$q,$db,$log) = @_;
	my $outlet_name = $q->param('outlet_name')||'';
	my $address = $q->param('address')||'';
	my $district = $q->param('district')||'';
	my $sub_district = $q->param('sub_district')||'';
	my $poscode = $q->param('pos_code')||'';
	my $owner = $q->param('owner')||'';
	my $mobilephone = $q->param('mobile_phone')||'';
	my $outlet_type_id = $q->param('opt_type');
	my $plafond = $q->param('plafond');
	my $birth_date = join '-', reverse split '-', $q->param('birth_date') || '';

	$db->insert('outlet', { outlet_name => $outlet_name,
				address => $address,
				district => $district,
				sub_district => $sub_district,
				pos_code => $poscode,
				owner => $owner,
				outlet_type_id => $outlet_type_id,
				plafond => $plafond,
				birth_date => $birth_date,
			      });
	my $outlet_id = $db->last_insert_id(0,0,0,0);
	$db->insert('user',{
		outlet_id => $outlet_id,
		username  => $mobilephone,
		pin       => '1234',
		status    => 'Active',
	}) if $mobilephone;
	return "/view/outlet/list?outlet_name=$outlet_name";
}
sub edit_outlet{
 my ($s,$q,$db,$log) = @_;
        my $outlet_name = $q->param('outlet_name')||'';
        my $address = $q->param('address')||'';
        my $district = $q->param('district')||'';
        my $sub_district = $q->param('sub_district')||'';
        my $poscode = $q->param('pos_code')||'';
        my $owner = $q->param('owner')||'';
        my $mobilephone = $q->param('mobile_phone')||'';
        my $outlet_id = $q->param('outlet_id');
		my $outlet_type_id = $q->param('opt_type');
		my $plafond = $q->param('plafond');
		my $birth_date = join '-', reverse split '-', $q->param('birth_date');
		my $status = $q->param('status');
	$log->warn(" oultet_id=$outlet_id");
	$db->query('update outlet set outlet_name=?, address=?, district=?, sub_district=?, pos_code=?, owner=?, outlet_type_id=?, plafond=?, status=?, birth_date=? where outlet_id=?', $outlet_name, $address, $district, $sub_district, $poscode, $owner, $outlet_type_id, $plafond, $status, $birth_date, $outlet_id);

	my $user = $db->query("select user_id from user where outlet_id = ?", $outlet_id)->list;
	unless($user){
		$db->insert('user',{
			outlet_id => $outlet_id,
			username  => $mobilephone,
			pin       => '1234',
			status    => 'Active',
		});
		return "/view/outlet/list?outlet_name=$outlet_name";
	}
	
	$db->update('user',{
			username => $mobilephone,
		},
		{
			outlet_id => $outlet_id,
		}
	);
	return "/view/outlet/list?outlet_name=$outlet_name";
}
sub delete{
	my ($s,$q,$db,$log) = @_;
	my $outlet_id = $q->param('id');
	$db->query('delete from outlet where outlet_id=?', $outlet_id);
return '/view/outlet/list';
}

sub outlet_type {
	my ($s,$q,$db,$log) = @_;
	
	# Add Type
	if($q->param('op') eq 'Add_Type'){
		$db->insert('outlet_type', {
			type_name	=> $q->param('type_name'),
			period		=> $q->param('period'),
		});
	}

	# Add Price Per Product
	if($q->param('op') eq 'Add_Price'){
		$db->insert('outlet_pricing',{
			stock_ref_id	=> $q->param('id_product'),
			price			=> $q->param('price'),
			outlet_type_id	=> $q->param('id_type'),
		});
	}
	
	# Delete outlet type
	$log->warn("outlet_type_id : ", $q->param('o_t_id'));
	if($q->param('op') eq 'Delete'){
		$db->delete('outlet_type', {
			outlet_type_id => $q->param('o_t_id'),
		});
	}
	return '/view/outlet/outlet_type';
}

sub edit_outlet_type {
	my ($s,$q,$db,$log) = @_;
	
	my @price = $q->param('price');
	my @o_t_id = $q->param('o_t_id');
	my $id_stock = $q->param('id_stock');
	$log->warn('id stock : ', $id_stock);

	# delete outlet pricing
	$db->delete('outlet_pricing',{
		stock_ref_id	=> $id_stock,
	});
	
	# insert outlet pricing
	for(my $i=0; $i < scalar(@o_t_id); $i++){
		$log->warn(" price ke $i : ", $price[$i], " outlet type id ke $i : ", $o_t_id[$i]);
		$db->insert('outlet_pricing',{
			stock_ref_id	=> $id_stock,
			price			=> $price[$i],
			outlet_type_id	=> $o_t_id[$i],
		});
	}
	
	return '/view/outlet/outlet_type';
}

sub serial{
	my ($s,$q,$db,$log) = @_;
	
	my $stock_ref_id = $q->param('up_down') || 'empty';
	$log->warn("stock ref id : ", $stock_ref_id);
	my ($id_serial, $stock_ref_name) = $db->query("select id_serial, stock_ref_name from stock_ref where stock_ref_id=?", $stock_ref_id)->list;
	my $new_serial = $id_serial + 1 if $q->param('down');
	$new_serial = $id_serial - 1 if $q->param('up');
	$log->warn("new serial : ", $new_serial);
	$log->warn("stock_ref_name : ", $stock_ref_name);
	# Menggusur
	$db->update('stock_ref',{
		id_serial => $new_serial,
	},
	{
		stock_ref_id => $stock_ref_id,
	});
	
	my $order = "order by stock_ref_id asc limit 1" if $q->param('up');
	$order = "order by stock_ref_id desc limit 1" if $q->param('down');
	
	my ($found_stock_ref_id,$found_stock_ref_name) = $db->query("select stock_ref_id, stock_ref_name from stock_ref where id_serial=? $order", $new_serial)->list;
	$log->warn("stock_ref_id found : ", $found_stock_ref_id);
	$log->warn("found stock ref name : ", $found_stock_ref_name);
	return "/view/outlet/outlet_type" if $stock_ref_name eq $found_stock_ref_name;
	my $found_serial = $new_serial + 1 if $found_stock_ref_id and $q->param('up');
	$found_serial = $new_serial - 1 if $found_stock_ref_id and $q->param('down');
	$log->warn("serial found : ", $found_serial);
	# digusur
	$db->update('stock_ref',{
		id_serial => $found_serial,
	},
	{
		stock_ref_id => $found_stock_ref_id,
	});

	return "/view/outlet/outlet_type";
}

sub add_quota_outlet{
	my ($s, $q, $db, $log) = @_;
	
	my $outlet_id = $q->param('outlet_id');
	my $ref_type_id = $q->param('ref_type_id');
	my @outlet_quota_id = $q->param('outlet_quota_id');
	my @stock_ref_id = $q->param('stock_ref_id');
	my @qty = $q->param('add_qty');
	my @available_qty = $q->param('available_qty');
	my $count_stock = $q->param('count_stock');
	my $op = $q->param('op');

	if($op eq 'Add Quota'){
		for(my $i=0; $i < $count_stock; $i++){
			$outlet_quota_id[$i] = 0 unless ($outlet_quota_id[$i]);
			$qty[$i] = 0 unless ($qty[$i]);
			$available_qty[$i] = 0 unless($available_qty[$i]);
			my $last_qty = $available_qty[$i] + $qty[$i];
			$db->query('update outlet_quota set quota =? where outlet_quota_id=?', $last_qty, $outlet_quota_id[$i]) if $outlet_quota_id[$i] and $qty[$i] ne 0;
			$db->insert('outlet_quota',{
				outlet_id      	=> $outlet_id,
				stock_ref_id	=> $stock_ref_id[$i],
				quota       	=> $last_qty,
			}) unless $outlet_quota_id[$i];
		}
	}elsif($op eq 'Add Nominal'){
		my $add_nominal = $q->param('add_nominal');
		my $available_nominal = $q->param('available_nominal');
		$add_nominal = 0 unless $add_nominal;
		$available_nominal = 0 unless $available_nominal;
		my $last_nominal = $available_nominal + $add_nominal;
		$db->query('update outlet set nominal_quota=? where outlet_id=?', $last_nominal, $outlet_id) if $add_nominal ne 0;
	}elsif($op eq 'Add Qty'){
		my $add_qty_all = $q->param('add_qty_all');
		my $available_qty_all = $q->param('available_qty_all');
		$add_qty_all = 0 unless $add_qty_all;
		$available_qty_all = 0 unless $available_qty_all;
		my $last_qty_all = $available_qty_all + $add_qty_all;
		$db->query('UPDATE outlet SET qty_quota=? where outlet_id=?', $last_qty_all, $outlet_id) if $add_qty_all ne 0;
	}
	return "/view/outlet/view_outlet?id=$outlet_id";
}

sub add_quota_rs{
	my($s, $q, $db, $log) = @_;

	my $rs_id = $q->param('rs_id');
	my $rs_number = $q->param('rs_number');
	my $ref_type_id = $q->param('ref_type_id');
	my $count_stock = $q->param('count_stock');
	my @rs_stock_id = $q->param('rs_stock_id');
	my @stock_ref_id = $q->param('stock_ref_id');
	my @qty = $q->param('add_qty');
	my @available_qty = $q->param('available_qty');
	my $op = $q->param('op');

	if($op eq 'Add Quota'){
		for(my $i=0; $i < $count_stock; $i++){
			$rs_stock_id[$i] = 0 unless ($rs_stock_id[$i]);
			$qty[$i] = 0 unless ($qty[$i]);
			$available_qty[$i] = 0 unless($available_qty[$i]);
			my $last_qty = $available_qty[$i] + $qty[$i];
			$db->query('update rs_stock set quota =? where rs_stock_id=?', $last_qty, $rs_stock_id[$i]) if $rs_stock_id[$i] and $qty[$i] ne 0;
			$db->insert('rs_stock',{
				rs_id       	=> $rs_id,
				stock_ref_id	=> $stock_ref_id[$i],
				quota       	=> $last_qty,
			}) unless $rs_stock_id[$i];
		}
	}elsif($op eq 'Add Nominal'){
		my $add_nominal = $q->param('add_nominal');
		my $available_nominal = $q->param('available_nominal');
		$add_nominal = 0 unless $add_nominal;
		$available_nominal = 0 unless $available_nominal;
		my $last_nominal = $available_nominal + $add_nominal;
		$db->query('update rs_chip set rs_nominal_quota=? where rs_id=?', $last_nominal, $rs_id) if $add_nominal ne 0;
	}elsif($op eq 'Add Qty'){
		my $add_qty_all = $q->param('add_qty_all');
		my $available_qty_all = $q->param('available_qty_all');
		$add_qty_all = 0 unless $add_qty_all;
		$available_qty_all = 0 unless $available_qty_all;
		my $last_qty_all = $available_qty_all + $add_qty_all;
		$db->query('UPDATE rs_chip SET rs_qty_quota=? where rs_id=?', $last_qty_all, $rs_id) if $add_qty_all ne 0;
	}

	return "/view/outlet/detail_rs?rs_id=$rs_id&ref_type_id=$ref_type_id&rs_number=$rs_number";
} 

1;
