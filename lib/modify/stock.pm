package modify::stock;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub add_stock_sd_chip {
	my ($s,$q,$db,$log) = @_;
	my $sd_name = $q->param('sd_name')||'';
	my $sd_number = $q->param('sd_number')||'';
	my $sd_type_id = $q->param('sd_type_id')||'';
	my $site_id = $q->param('site_id')||'';
	my $modem = $q->param('modem');
	my $pin = $q->param('pin');
	$db->insert('sd_chip', { 	
				sd_name => $sd_name,  
				sd_number => $sd_number,
				ref_type_id => $sd_type_id,
				site_id => $site_id,
				modem => $modem,
				pin => $pin
			      });
	return '/view/stock/list';
}

sub add_dtl_pkg {
	my ($s, $q, $db, $log) = @_;
	my $pkg_id = $q->param('pkg_id');
	my $stock_ref_id = $q->param('stock_ref_id')||'';
	my $pkg_qty = $q->param('pkg_qty')||'';
	$log->warn($pkg_qty,'test');
	$db->insert('package_detail', {
				pkg_id => $pkg_id,
				stock_ref_id => $stock_ref_id,
				pkg_qty => $pkg_qty,
			});
	return "/view/stock/dtl_pkg?pkg_id=$pkg_id";
}

sub change_status_rs {
        my ($s, $q, $db, $log) = @_;
        my $rs_id = $q->param('rs_id');
	my $sd_id = $q->param('sd_id');
	my $sd_name = $q->param('sd_name');
        my $status;
        if ($q->param('status') eq 'Active') {
                $status = 2;
        } else {
                $status = 1;
        }

        $db->query('update rs_chip set status = ? where rs_id = ?', $status, $rs_id);
        return "/view/stock/detail_stock_sd_chip?id=$sd_id&sd_name=$sd_name";
}

sub add_sd_type {
	my ($s,$q,$db,$log) = @_;
	my $sd_type_name = $q->param('sd_type_name');
	$db->insert('sd_type', { 
				sd_type_name => $sd_type_name,
			    });
	return "/view/stock/list_sd_type";
}

sub add_sd_stock {
        my ($s,$q,$db,$log) = @_;
        my $sd_id = $q->param('sd_id');
        my $sd_name = $q->param('sd_name');
	my $stock_ref_id = $q->param('stock_ref_id');
	my $qty = $q->param('quantity');
	$db->query(
		'replace into sd_stock (sd_id, stock_ref_id, qty) '.
		'values (?,?,?)',
		$sd_id, $stock_ref_id, $qty,
	);
        return "/view/stock/detail_stock_sd_chip?id=$sd_id&sd_name=$sd_name";
}

sub add_stock_ref{
	my ($s,$q,$db,$log) = @_;
	my $stock_ref_name = $q->param('stock_ref_name');
	my $keyword = $q->param('keyword');
	my $max_qty = $q->param('max_qty');
	my $nominal = $q->param('nominal');
	my $ref_type_id = $q->param('ref_type_id');

	#my $price_server = $q->param('price_server');
	#my $price_canvaser = $q->param('price_canvaser');
	$db->insert('stock_ref', { stock_ref_name => $stock_ref_name,
			      keyword => $keyword, max_qty => $max_qty,
			      nominal => $nominal,
			      ref_type_id => $ref_type_id
			    });
	my ($id) = $db->query('select stock_ref_id from stock_ref order by stock_ref_id desc limit 1')->list;
	my $result = $db->query('select rs_type_id from rs_type order by rs_type_id');
	# get stock price
	#$log->warn($ref_type_id);
	while(my ($rs_type_id) = $result->list){
		$log->warn($q->param("$rs_type_id"));
		my $price = $q->param("$rs_type_id");
		$db->insert('pricing', 	{ stock_ref_id =>$id, rs_type_id=>$rs_type_id, price =>$price});
	} 
	
	#$db->insert('pricing', 	{ stock_ref_id =>$id, rs_type_id=>1, price =>$price_server});
	#$db->insert('pricing',	{ stock_ref_id =>$id, rs_type_id=>2, price =>$price_canvaser});
	return "/view/stock/list_stock_ref";
}

sub add_rs_chip {
        my ($s,$q,$db,$log) = @_;
        my $sd_id = $q->param('sd_id');
	my $sd_name = $q->param('sd_name');
        my $rs_number = $q->param('rs_number');
	my $outlet = $q->param('outlet_id');
	my $rs_type_id = $q->param('rs_type_id');
	my $member_id = $q->param('member_id');
	$log->warn("insert into rs_chip (sd_id, member_id, rs_number, outlet_id, rs_type_id) values ($sd_id, $member_id, $rs_number, $outlet, $rs_type_id)");
        my ($rs_id) = $db->query('select rs_id from rs_chip where rs_number=?', $rs_number)->list;
	$db->insert('rs_chip', { sd_id => $sd_id, member_id => $member_id, 
                              rs_number => $rs_number, outlet_id => $outlet, rs_type_id => $rs_type_id,
                            }) unless defined($rs_id);
        return "/view/stock/detail_stock_sd_chip?id=$sd_id&sd_name=$sd_name";
}
sub add_price_type {
        my ($s,$q,$db,$log) = @_;
        my $price_type = $q->param('price_type');
        $db->insert('rs_type', {
                                type_name => $price_type,
                            });
        return "/view/stock/price_type";
}
#edit satu satu
sub edit_satu{
        my ($s,$q,$db,$log)=@_;
        my $stock_id = $q->param('sr_id');
        my $type_id = $q->param('rt_id');
        my $price = $q->param('price');
        $s->query('update pricing set price=? where stock_ref_id=? and rs_type_id=?',$price ,$stock_id ,$type_id);
        return "/view/stock/price";
}

sub edit_price{
	my ($s, $q, $db, $log)= @_;
	my @array; 
	my $result = $db->query('select stock_ref_id from stock_ref');
	while (my ($stock_ref_id)=$result->list) {
		my $type_ids = $db->query('select rs_type_id from rs_type');
		while(my($rs_type_id)=$type_ids->list){
		#	push @array, ($stock_ref_id,$rs_type_id);
		my $price = $q->param("$stock_ref_id\_$rs_type_id");
		$log->warn($price);
		
		$s->query("replace into pricing (stock_ref_id,rs_type_id,price) value (?,?,?)",$stock_ref_id, $rs_type_id, $price);
		}
	}

	return "/view/stock/edit_price";
}

sub edit_for_approve {
        my ($s, $q, $db, $log)= @_;
        my @array;
        my $result = $db->query('select stock_ref_id from stock_ref');
        while (my ($stock_ref_id)=$result->list) {
                my $type_ids = $db->query('select rs_type_id from rs_type');
                while(my($rs_type_id)=$type_ids->list){
                #       push @array, ($stock_ref_id,$rs_type_id);
                my $price = $q->param("$stock_ref_id\_$rs_type_id");
                $log->warn($price);
                $s->query("replace into pricing_temporary (stock_ref_id,rs_type_id,price, save_time, price_type) value (?,?,?,now(),'NEW')",$stock_ref_id, $rs_type_id, $price);
                }
        }
        return "/view/stock/edit_for_approve";
}

sub approve_price {
	my ($s, $q, $db, $log) = @_;
	$db->begin();
	foreach my $stock_ref_id ($q->param('stock_ref_id')) {
		foreach my $rs_type_id ($q->param('rs_type_id')) {
			my $price = $q->param("p$stock_ref_id\_$rs_type_id");
			$log->warn($price);
	             
			eval {	
				my $old_price = $db->query("select price from pricing where stock_ref_id=? and rs_type_id=? and price_type='OLD'", $stock_ref_id, $rs_type_id)->list;
				$db->query("replace into pricing (stock_ref_id, rs_type_id, price, price_type, old_price) values (?,?,?,'NEW',?)",$stock_ref_id, $rs_type_id, $price, $old_price) if $price ne '';
				$db->query("delete from  pricing_temporary where stock_ref_id=? and rs_type_id=?", $stock_ref_id, $rs_type_id) if $price ne '';
			};
			if ($@) {
                                $log->warn($@);
                                $db->rollback();
			}
		}
	}
	$db->commit();
	return "/view/stock/approve_price";	
}

sub edit_price_type {
        my ($s, $q, $db, $log) = @_;
        my $type_name = $q->param('price_type')||'';
        my $id = $q->param('id')||'';
        $s->query('update rs_type set type_name=? where rs_type_id=?',$type_name, $id);
        return '/view/stock/price_type';
}
sub delete_price_type {
        my ($s,$q,$db,$log) = @_;
        my $id = $q->param('id');
        $db->query('delete from rs_type where rs_type_id=?', $id);
        return "/view/stock/price_type";
}
sub delete_rs_chip {
	my ($s,$q,$db,$log) = @_;
        my $sd_id = $q->param('sd_id');
        my $sd_name = $q->param('sd_name');
        my $rs_id = $q->param('rs_id');
        $db->query('delete from rs_chip where rs_id=?', $rs_id);
        return "/view/stock/detail_stock_sd_chip?id=$sd_id&sd_name=$sd_name";
}

sub edit_stock_sd_chip {
	my ($s, $q, $db, $log) = @_;
	my $sd_name = $q->param('sd_name')||'';
	my $modem   = $q->param('modem')||'';
	my $pin     = $q->param('pin')||'';
	my $sd_id   = $q->param('sd_id');

	$db->update('sd_chip',
		{sd_name=>$sd_name, modem=>$modem, pin=>$pin},
		{sd_id=>$sd_id}
	);
	return '/view/stock/list';
}

sub edit_list_package {
        my ($s, $q, $db, $log) = @_;
	my $pkg_name = $q->param('pkg_name')||'';
        my $pkg_id   = $q->param('pkg_id');

        $db->update('package',
                {pkg_name=>$pkg_name},
                {pkg_id=>$pkg_id}
        );
        return "/view/stock/list_package?id=$pkg_id&pkg_name=$pkg_name";
}

sub delete_list_package {
	my ($s,$q,$db,$log) = @_;
	my $pkg_id = $q->param('id');
	$db->query('delete from package where pkg_id=?',$pkg_id);
	return "/view/stock/list_package?id=$pkg_id";
}

sub edit_detail_package {
	my($s, $q, $db, $log) = @_;
        my $pkg_qty = $q->param('pkg_qty')||'';
        my $pkg_id   = $q->param('pkg_id');
	my $stock_ref_id = $q->param('stock_ref_id');
	my $pkg_name = $q->param('pkg_name');
        $db->update('package_detail',
               {pkg_qty=>$pkg_qty},
               {pkg_id=>$pkg_id,stock_ref_id=>$stock_ref_id}
        );
        return "/view/stock/dtl_pkg?pkg_id=$pkg_id";

}

sub delete_detail_package {
	my($s,$q,$db,$log) = @_;
	my $pkg_qty = $q->param('id')||'';
	my $stock_ref_id = $q->param('stock');
	my $pkg_id = $q->param('pkg');
	my $pkg_name = $q->param('name');
	$db->query("delete from package_detail where pkg_id=$pkg_id and stock_ref_id=$stock_ref_id and pkg_qty=$pkg_qty");
	return "/view/stock/dtl_pkg?pkg_id=$pkg_id";
}

sub edit_sd_stock {
	my ($s, $q, $db, $log) = @_;
	my $sd_name = $q->param('sd_name')||'';
	my @qty = $q->param('add_qty');
	my $sd_id = $q->param('sd_id');
	my @sd_stock_id = $q->param('sd_stock_id');
	my @stock_ref_id = $q->param('stock_ref_id');
	my $ref_type_id = $q->param('ref_type_id');
	
	for(my $i=0; $i < scalar(@sd_stock_id); $i++){
		$log->warn("sd stock id ke $i: ", $sd_stock_id[$i], "	add qty ke $i : ", $qty[$i], " stock ref id ke $i: ", $stock_ref_id[$i]);
		$db->begin();
		my $b_qty = $db->query('select qty from sd_stock where sd_stock_id=? for update',$sd_stock_id[$i])->list;
		$b_qty = 0 unless ($b_qty);
		$log->warn("b qty : ", $b_qty);
		$qty[$i] = 0 unless ($qty[$i]);
		$log->warn("qty : ",$qty[$i]);
		my $trx_qty = $qty[$i]+$b_qty;
		$log->warn("trx qty : ",$trx_qty);
		$db->query('update sd_stock set qty=? where sd_stock_id=?',$trx_qty ,$sd_stock_id[$i]) if $sd_stock_id[$i] and $qty[$i] != 0;
		$db->insert('sd_stock',{
				sd_id			=> $sd_id,
				stock_ref_id	=> $stock_ref_id[$i],
				qty				=> $qty[$i],
				admin_id		=> $s->adm_id,
			}) unless $sd_stock_id[$i];
		my $s_s_id = $sd_stock_id[$i];
		$s_s_id = $db->last_insert_id(0,0,0,0) unless $sd_stock_id[$i];
		$db->insert('stock_mutation',{
				sm_ts => \['now()'],
				sd_stock_id => $s_s_id,
				trx_qty =>$qty[$i],
				stock_qty => $trx_qty,
				}) if $qty[$i] != 0;
		$db->commit();
	}
    return "/view/stock/detail_stock_sd_chip?id=$sd_id&ref_type_id=$ref_type_id&sd_name=$sd_name";
}

sub approve_manager{
	my ($s, $q, $db, $log) = @_;
	
	my $sd_id = $q->param('sd_id');
	my $ref_type_id = $q->param('ref_type_id');
	my $sd_name = $q->param('sd_name');
	my @sd_stock_id = split ',', $q->param('sd_stock_id');
	my @stock_ref_id = split ',', $q->param('stock_ref_id');
	my @qty = split ',', $q->param('qty');
	my $count_stock = $q->param('count_stock');
	
	for(my $i=0; $i < $count_stock; $i++){
		$sd_stock_id[$i] = 0 unless ($sd_stock_id[$i]);
		$qty[$i] = 0 unless ($qty[$i]);
		$log->warn("sd stock id ke $i : ", $sd_stock_id[$i], " stock ref_id ke $i : ", $stock_ref_id[$i], " qty ke $i : ", $qty[$i]);
		$db->query('update sd_stock set qty_tmp =?, admin_id = ?, sd_stock_ts = now() where sd_stock_id=?', $qty[$i], $s->adm_id, $sd_stock_id[$i]) if $sd_stock_id[$i] and $qty[$i] != 0;
		$db->insert('sd_stock',{
			sd_id			=> $sd_id,
			stock_ref_id	=> $stock_ref_id[$i],
			qty_tmp			=> $qty[$i],
			admin_id		=> $s->adm_id,
			sd_stock_ts		=> \'NOW()',
		}) unless $sd_stock_id[$i];
	}
	return "/view/stock/detail_stock_sd_chip?id=$sd_id&ref_type_id=$ref_type_id&sd_name=$sd_name";
}

sub add_quota{
	my ($s, $q, $db, $log) = @_;
	
	my $sd_id = $q->param('sd_id');
	my $ref_type_id = $q->param('ref_type_id');
	my $sd_name = $q->param('sd_name');
	my @sd_stock_id = split ',', $q->param('sd_stock_id');
	my @stock_ref_id = split ',', $q->param('stock_ref_id');
	my @qty = split ',', $q->param('qty');
	my $count_stock = $q->param('count_stock');
	
	for(my $i=0; $i < $count_stock; $i++){
		$sd_stock_id[$i] = 0 unless ($sd_stock_id[$i]);
		$qty[$i] = 0 unless ($qty[$i]);
		$log->warn("sd stock id ke $i : ", $sd_stock_id[$i], " stock ref_id ke $i : ", $stock_ref_id[$i], " qty ke $i : ", $qty[$i]);
		$db->query('update sd_stock set quota =? where sd_stock_id=?', $qty[$i], $sd_stock_id[$i]) if $sd_stock_id[$i] and $qty[$i] > 0;
		$db->insert('sd_stock',{
			sd_id       	=> $sd_id,
			stock_ref_id	=> $stock_ref_id[$i],
			quota       	=> $qty[$i],
			admin_id    	=> $s->adm_id,
			sd_stock_ts 	=> \'NOW()',
		}) unless $sd_stock_id[$i];
	}
	return "/view/stock/detail_stock_sd_chip?id=$sd_id&ref_type_id=$ref_type_id&sd_name=$sd_name";
}

sub approve_stock {
	my ($s, $q, $db, $log) = @_;
	
	my $from = $q->param('from'); 
	my $until = $q->param('until'); 
	my @ap_stock = $q->param('ap_stock');
	foreach(@ap_stock){
		my($qty, $sd_stock_id) = split '_', $_;
		$db->begin();
		my $b_qty = $db->query('select qty from sd_stock where sd_stock_id=? for update',$sd_stock_id)->list;
		$log->warn($b_qty);
		$qty=0 unless ($qty);
		my $trx_qty = $qty+$b_qty;
		$db->query('update sd_stock set qty=?, qty_tmp=0 where sd_stock_id=?',$trx_qty ,$sd_stock_id);
		$db->insert('stock_mutation',{
				sm_ts => \['now()'],
				sd_stock_id => $sd_stock_id,
				trx_qty =>$qty,
				stock_qty => $trx_qty,
				});
		$db->commit();
	}
	
	return "/view/stock/approve_stock?from=$from&until=$until";
}

sub edit_rs_chip {
	my ($s, $q, $db, $log) = @_;
        my $sd_name = $q->param('sd_name');
	my $sd_id = $q->param('sd_id');
	my $rs_outlet_id = $q->param('rs_outlet_id');
        my $rs_id = $q->param('rs_id');
	my $rs_number = $q->param('rs_chip');
	my $outlet = $q->param('outlet_id');
	my $rs_type_id = $q->param('rs_type_id');
	my $move_sd_id = $q->param('move_sd_id');
	my $member_id = $q->param('member_id');
	my $ref_type_id = $q->param('ref_type_id');
	$db->query('update rs_chip set rs_number=?, outlet_id=?, rs_type_id=?, sd_id=?, member_id=?, rs_outlet_id=? where rs_id=?', $rs_number, $outlet, $rs_type_id,$move_sd_id, $member_id, $rs_outlet_id, $rs_id);
	return "/view/stock/detail_stock_sd_chip?id=$sd_id&ref_type_id=$ref_type_id&sd_name=$sd_name";	
}

sub delete_sd_stock {
        my ($s, $q, $db, $log) = @_;
        my $sd_name = $q->param('sd_name');
        my $sd_id = $q->param('sd_id');
        my $sd_stock_id = $q->param('sd_stock_id');
        $s->query('delete from sd_stock where sd_stock_id=?', $sd_stock_id);
        return "/view/stock/detail_stock_sd_chip?id=$sd_id&sd_name=$sd_name";
}

sub edit_type {
	my ($s, $q, $db, $log) = @_;
	my $sd_type_name = $q->param('sd_type_name')||'';
	my $sd_type_id = $q->param('sd_type_id')||'';
	$s->query('update sd_type set sd_type_name=? where sd_type_id=?',$sd_type_name, $sd_type_id);
	return '/view/stock/list_sd_type';
}

sub edit_modem {
	my ($s, $q, $db, $log) = @_;
	my $modem_name = $q->param('modem_name');
	my $modem_id = $q->param('modem_id');
	$s->query('update modem set modem_name=? where modem_id=?',$modem_name, $modem_id);
	return '/view/stock/list_modem';
}

sub edit_list_package {
        my ($s, $q, $db, $log) = @_;
        my $pkg_name = $q->param('pkg_name');
        my $pkg_id = $q->param('pkg_id');
        $s->query('update package set pkg_name=? where pkg_id=?',$pkg_name, $pkg_id);
        return '/view/stock/list_package';
}


sub edit_site {
	my ($s, $q, $db, $log) = @_;
	my $site_name = $q->param('site_name')||'';
	my $site_url = $q->param('site_url')||'';
	my $site_id = $q->param('site_id');
	$s->query('update site set site_name=?, site_url=? where site_id=?',$site_name, $site_url, $site_id);
	return '/view/stock/list_site';
}

sub dompul_disc_update {
	my ($s, $q, $db, $log) = @_;
	my $dompul_discount = $q->param('config_value');
	$s->query('update config set config_value=? where config_id=1', $dompul_discount);
	return '/view/stock/dompul_disc';
}

sub edit_stock_ref {
        my ($s, $q, $db, $log) = @_;
        my $stock_ref_name = $q->param('stock_ref_name')||'';
        my $keyword = $q->param('keyword')||'';
        #my $price_server = $q->param('price_server')||'';
	my $nominal = $q->param('nominal')||'';
	$log->warn("nominal =", $nominal);
	#my $price_canvaser = $q->param('price_canvaser')||'';
	my $max_qty = $q->param('max_qty');
        my $stock_ref_id = $q->param('stock_ref_id');
        
	$db->query('update stock_ref set stock_ref_name=?, keyword=?, max_qty=?,nominal=? where stock_ref_id=?',$stock_ref_name, $keyword, $max_qty, $nominal, $stock_ref_id);
	
	#$db->query('update pricing set price=? where stock_ref_id=? and rs_type_id=1', $price_server, $stock_ref_id);
	#$db->query('update pricing set price=? where stock_ref_id=? and rs_type_id=2', $price_canvaser, $stock_ref_id);
	
	return '/view/stock/list_stock_ref';
}

sub delete {
	my ($s, $q, $db, $log) = @_;
	my $sd_id = $q->param('id')||'';
	$s->query('delete from sd_chip where sd_id=?',$sd_id);
	return '/view/stock/list';
}

sub delete_site {
	my ($s, $q, $db, $log) = @_;
	my $site_id = $q->param('id')||'';
	$s->query('delete from site where site_id=?',$site_id);
	return '/view/stock/list_site';
}

sub delete_type {
	my ($s, $q, $db, $log) = @_;
	my $sd_type_id = $q->param('id')||'';
	$s->query('delete from sd_type where sd_type_id=?',$sd_type_id);
	return '/view/stock/list_sd_type';
}

sub delete_modem {
	my ($s, $q, $db, $log) = @_;
	my $modem_id = $q->param('modem_id');
	$s->query('delete from modem where modem_id=?',$modem_id);
	return '/view/stock/list_modem';
}

sub delete_stock_ref {
        my ($s, $q, $db, $log) = @_;
        my $stock_ref_id = $q->param('id')||'';
        $s->query('delete from pricing where stock_ref_id=?', $stock_ref_id);
	$s->query('delete from topup_request where stock_ref_id=?',$stock_ref_id);
	$s->query('delete from stock_ref where stock_ref_id=?',$stock_ref_id);
        return '/view/stock/list_stock_ref';
}

sub add_pkg{
	my ($s,$q,$db,$log) = @_;
        my $pkg_name = $q->param('pkg_name');
        $db->insert('package', {
                                pkg_name => $pkg_name,
                            });
        return "/view/stock/list_package";

}
#sub discount_dompul {
#	my ($s, $q, $db, $log) = @_;
#	
#	return '/view/stock/discount_dompul';
#
#}

1;
