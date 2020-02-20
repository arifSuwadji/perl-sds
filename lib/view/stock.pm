package view::stock;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use config;

sub filter_type {
	my $s = shift;

	my $where = ''; my @bind = ();
	my $type = $s->{ref_type_id};
	if ($type) {
		$where = "where ref_type_id=?";
		@bind = ($type);
	}
	return ($where, @bind);
}

sub site_bind {
	my $s = shift;

	my $where = ''; my @bind = ();
	my $site = $s->{site_id};
	if($site){
		$where = "where site_id=?";
		@bind = ($site);
	}
	return ($where, @bind);
}
sub list {
	my ($s,$q,$db,$log) = @_;
	my $site_id = $q->param('site_id');
	my ($where, @bind) = site_bind($s);
	unless($where){
		unless($site_id){
		}else{
		$where = 'where site_id=?';
		@bind = ($site_id);
		}
	}
	my $list;

    	if ($config::adm_gid eq $s->{adm_gid}) {
        $list = $s->sql_list(<<"EOS",
select sd_id, sd_name, sd_number, ref_type_name as sd_type_name,
  site_name, modem as modem_name, pin, ref_type_id
from sd_chip
  inner join stock_ref_type using (ref_type_id)
  inner join site using (site_id) 
where ref_type_id=1
EOS
    );
	} else {

	$list = $s->sql_list(<<"EOS", @bind
select sd_id, sd_name, sd_number, ref_type_name as sd_type_name,
  site_name, modem as modem_name, pin, ref_type_id
from sd_chip
  inner join stock_ref_type using (ref_type_id)
  inner join site using (site_id)
$where
EOS
	);
	}
	return {
		list_stock_sd_chip => $list,
	};
}

sub list_sd_type {
	my ($s,$q,$db,$log) = @_;
	return {
		list_sd_type => $s->sql_list('select sd_type_id, sd_type_name from sd_type'),
	}
}

sub list_modem {
	my ($s, $q, $db, $log) = @_;
		return {
		list_modem =>$s->sql_list('select modem_id, modem_name from modem'),
	}
}

sub list_site {
	my ($s,$q,$db,$log) = @_;
	return {
		list_site => $s->sql_list('select site_id, site_name, site_url from site'),
	}
}

sub list_stock_ref {
	my ($s,$q,$db,$log) = @_;

	my $pager = $s->q_pager('select stock_ref_id, stock_ref_name, keyword, max_qty, nominal from stock_ref',
		extra_filter => {
			'stock_ref_id <> ?' => 10,
			'ref_type_id = ?' => $s->{ref_type_id},
		},
		suffix => 'order by stock_ref_name'
	);

	return {
		list_stock_ref =>  $pager->{list},
		rs_type => $s->sql_list('select type_name from rs_type'),
	}
}
sub price{
		my ($s,$q,$db,$log) = @_;
		my $type = $s->sql_list('select type_name from rs_type order by rs_type_id');
		my $count_type = $s->sql_list('select count(*) as jumlah from rs_type');
		my $type_name = $s->sql_list('select stock_ref_name from stock_ref');
		my @sql;
		my $res = $s->sql_list("select stock_ref_id, stock_ref_name, concat(\'<td>\',group_concat(\'<a href=/view/stock/editsatu?sr=\',stock_ref_id,\'&rt=\',rs_type_id,\'>\',ifnull(price,\'\')order by rs_type_id separator \'</a></td><td>\'),\'</a></td>\')as p from stock_ref inner join rs_type left join pricing using(stock_ref_id, rs_type_id)group by stock_ref_id order by stock_ref_name");
		my $ref_id = $db->query('select stock_ref_id from pricing group by stock_ref_id');
		
		$log -> warn($res);
	return{
		rs_type => $type,
		count => $count_type,
		ref_name => $type_name,
		list => $res
	};
	}
###edit price satu persatu###
#
sub editsatu{ my ($s, $q, $db, $log)=@_;
		my $stock_ref_id = $q->param('sr');
		my $rs_type_id = $q->param('rt');
		my $list = $s->sql_list('select pricing.stock_ref_id, stock_ref_name, pricing.rs_type_id, type_name, price from pricing left join stock_ref on stock_ref.stock_ref_id=pricing.stock_ref_id left join rs_type on rs_type.rs_type_id=pricing.rs_type_id where pricing.stock_ref_id=? and pricing.rs_type_id=?',$stock_ref_id ,$rs_type_id);
		return{
			list => $list,
		};
		
	}
#### edit secara berbarengan
sub edit_price { #untuk semuanya diubah menjadi list Price
	my ($s,$q,$db,$log) = @_;
	my $type = $s->sql_list('select type_name from rs_type order by rs_type_id');
	my $count_type = $s->sql_list('select count(*) as jumlah from rs_type');
	my $type_name = $s->sql_list('select stock_ref_name from stock_ref');
	my @sql;

	my ($where, @bind) = filter_type($s);
	my $res = $s->sql_list(<<"EOS", @bind
select stock_ref_id, stock_ref_name, rs_type_id,
  concat(\'<td>\',
    group_concat(\'<input type=text name=\"\',stock_ref_id,\'_\',rs_type_id, \'\" value=\"\',ifnull(price,\'\')
      order by rs_type_id
      separator \'\"></td><td>\'
    ),
    \'\"></td>\'
  )as p
from stock_ref
  inner join rs_type
  left join pricing using(stock_ref_id, rs_type_id)
$where
group by stock_ref_id order by stock_ref_id, rs_type_id
EOS
);
                my $ref_id = $db->query('select stock_ref_id from stock_ref');
		my $rs_type_id = $db->query('select rs_type_id from rs_type');
		$log -> warn($res);
        return{
                rs_type => $type,
                count => $count_type,
                ref_name => $type_name,
                list => $res,
		ref_id => $ref_id,
		rs_type_id => $rs_type_id,
        };
}

sub edit_for_approve { #untuk accounting doang
                my ($s,$q,$db,$log) = @_;
                my $type = $s->sql_list('select type_name from rs_type order by rs_type_id');
                my $count_type = $s->sql_list('select count(*) as jumlah from rs_type');
                my $type_name = $s->sql_list('select stock_ref_name from stock_ref');
                my @sql;
	my ($where, @bind) = filter_type($s);
	my $res = $s->sql_list(<<"EOS", @bind
select stock_ref_id, stock_ref_name, rs_type_id,  concat(\'<td>\',group_concat(\'<input type=text name=\"\',stock_ref_id,\'_\',rs_type_id, \'\" value=\"\',ifnull(price,\'\')order by rs_type_id  separator \'\"></td><td>\'),\'\"></td>\')as p from stock_ref inner join rs_type left join pricing_temporary using(stock_ref_id, rs_type_id)
$where
group by stock_ref_id order by stock_ref_id, rs_type_id
EOS
);
                my $ref_id = $db->query('select stock_ref_id from stock_ref');
                my $rs_type_id = $db->query('select rs_type_id from rs_type');
                $log -> warn($res);
        return{
                rs_type => $type,
                count => $count_type,
                ref_name => $type_name,
                list => $res,
                ref_id => $ref_id,
                rs_type_id => $rs_type_id,
        };
}


sub approve_price { #untuk best admin
	my ($s,$q,$db,$log) = @_;
	my %price; my @rs_type;
	my $type = $s->sql_list('select rs_type_id, type_name from rs_type order by rs_type_id');
	# $type = [{rs_type_id=> , $type_name=> },{}}]
	my @array = @{$type};
	foreach (@array) {
		my $rs_type_id = $_->{rs_type_id};
		push @rs_type, $rs_type_id;
		my $result = $db->query("select stock_ref_id, price from pricing_temporary where price_type='OLD' and rs_type_id=?", $rs_type_id); 
		
		while (my ($stock_ref_id, $price) = $result->list) {
			$price{$stock_ref_id} = {} unless defined $price{$stock_ref_id};
			$price{$stock_ref_id}->{$rs_type_id} = $price;
		}
	}
	my ($i, @product) = (0, ());;

	my ($where, @bind) = filter_type($s);
	my $result2 = $db->query(<<"EOS", @bind);
select stock_ref_id, keyword, stock_ref_name from stock_ref $where
EOS
	while(my ($stock_ref_id, $keyword, $stock_ref_name) = $result2->list) {
		my @rs_type_price; ++$i;
		foreach(@rs_type) {
			my $value = defined($price{$stock_ref_id}) ? $price{$stock_ref_id}->{$_} : undef;
			push @rs_type_price, {name => "$stock_ref_id\_$_", value => $value};
		}
		push @product, {keyword => $stock_ref_name, stock_ref_id => $stock_ref_id, seq => $i, rs_type_price => \@rs_type_price};
	}
	
	my $count_type = $s->sql_list('select count(*) as jumlah from rs_type');
        my $type_name = $s->sql_list('select stock_ref_name from stock_ref');
        my @sql;
        my $ref_id = $db->query('select stock_ref_id from stock_ref');
        my $rs_type_id = $db->query('select rs_type_id from rs_type');
        return{
                rs_type => $type,
                count => $count_type,
                ref_name => $type_name,

                product => \@product,
                ref_id => $ref_id,
                rs_type_id => $rs_type_id,
        };
}

sub add_price {
        my ($s, $q, $db, $log) = @_;
	my $stock_ref = $s->sql_list('select stock_ref_id, stock_ref_name from stock_ref order by stock_ref_name');
	my $rs_type = $s->sql_list('select rs_type_id, type_name from rs_type order by type_name');
        return {
		stock_ref => $stock_ref,
		rs_type => $rs_type,
        };
}

sub price_type{
	my ($s,$q,$db,$log) = @_;
		
                my ($type, $type_id) = $s->sql_list('select type_name, rs_type_id from rs_type');
	return{
	rs_type => $type,
	rs_type_id => $type_id,
	};
	}

sub add_price_type {
        my ($s, $q, $db, $log) = @_;
        return {
        };
}
sub edit_price_type{
	my ($s,$q,$db,$log) = @_;
	my $id = $q->param('id');
        my $type = $s->sql_list('select type_name, rs_type_id from rs_type where rs_type_id=?',$id);
        return{
        rs_type => $type,
	rs_type_id => $id,
        };

}


sub delete_price_type{
	return{};
}
sub dompul_disc {
	my ($s, $q, $db, $log) = @_;
	my $dompul_discount = $db->query('select config_value from config where config_id=1')->list;
	return {
		dompul_discount => $dompul_discount,
	};
}

sub add_stock_sd_chip {
	my ($s, $q, $db, $log) = @_;
	return {
		type_options => $s->sql_list('select ref_type_id sd_type_id, ref_type_name sd_type_name from stock_ref_type'),
		site_options => $s->sql_list('select site_id, site_name from site'),
	};
}

sub add_type {
	return {}
}

sub add_stock_ref {
	my ($s, $q, $db, $log) = @_;
	return {
		#type_options => $s->sql_list('select mem_type, type_name from member_type'),
		price_type => $s->sql_list('select rs_type_id, type_name from rs_type '),
		stock_ref_type => $s->sql_list('select ref_type_id,ref_type_name from stock_ref_type'),
	};
}

sub edit_type {
	my ($s,$q,$db,$log) = @_;
	my $sd_type_id = $q->param('id');
	my ($type_name) = $db->query('select sd_type_name from sd_type where sd_type_id=?', $sd_type_id)->list;
	return {
		sd_type_id => $sd_type_id,
		sd_type_name=>$type_name,
	};
}

sub edit_modem {
	my ($s,$q,$db,$log) = @_;
	my $modem_id = $q->param('modem_id');
	my ($modem_name) = $db->query('select modem_name from modem where modem_id=?', $modem_id)->list;
	return {
		modem_id => $modem_id,
		modem_name=>$modem_name,
	};
}

sub edit_site {
	my ($s,$q,$db,$log) = @_;
	my $site_id = $q->param('id');
	my ($site_name, $site_url) = $db->query('select site_name, site_url from site where site_id=?', $site_id)->list;
	return {
		site_id => $site_id,
		site_name=>$site_name,
		site_url=>$site_url, 
	};
}

sub edit_stock_ref {
        my ($s,$q,$db,$log) = @_;
        my $stock_ref_id = $q->param('id');
        my ($stock_ref_name, $keyword, $max_qty,$nominal) = $db->query('select stock_ref_name, keyword, max_qty, nominal from stock_ref where stock_ref_id=?', $stock_ref_id)->list;
        #my ($price_server) = $db->query('select price from pricing where rs_type_id=1 and stock_ref_id=?', $stock_ref_id)->list;
	#my ($price_canvaser) = $db->query('select price from pricing where rs_type_id=2 and stock_ref_id=?', $stock_ref_id)->list;
	return {
                stock_ref_name => $stock_ref_name,
                keyword => $keyword,
		max_qty => $max_qty,
		nominal => $nominal,
                #price_server=> $price_server,
		#price_canvaser=> $price_canvaser,
		stock_ref_id => $stock_ref_id,
        };
}

sub edit_stock_sd_chip {
	my ($s,$q,$db,$log) = @_;
	my $sd_id = $q->param('id');
	my $attr = $db->query(
		'select sd_id, sd_name, modem, pin from sd_chip where sd_id=?',
		$sd_id)->hash;
	return $attr;
}

sub edit_list_package {
        my ($s,$q,$db,$log) = @_;
        my $pkg_id = $q->param('id');
        my $attr = $db->query(
                'select pkg_id, pkg_name from package where pkg_id=?',
                $pkg_id)->hash;
        return $attr;
}

sub edit_detail_package {
        my ($s,$q,$db,$log) = @_;
        my $pkg_qty = $q->param('id');
        my $attr = $db->query(
                'select pkg_id,stock_ref_id,pkg_qty,keyword,pkg_name  from package_detail inner join stock_ref using(stock_ref_id) inner join package using(pkg_id) where pkg_qty=?',
                $pkg_qty)->hash;
        return $attr;
}

sub edit_rs_chip {
        my ($s,$q,$db,$log) = @_;
        my $sd_id = $q->param('sd_id');
	my $sd_name = $q->param('sd_name');
	my $rs_id = $q->param('rs_id');
	my $ref_type_id = $q->param('ref_type_id');
        my ($rs_outlet_id, $rs_number, $outlet_id, $outlet_name, $rs_type_id, $member_id) = $db->query('select rs_outlet_id, rs_number, rs_chip.outlet_id, outlet_name, rs_type_id, member_id from rs_chip left join outlet on outlet.outlet_id=rs_chip.outlet_id where rs_id=?', $rs_id)->list;
	my $rs_type_options = $s->sql_list("select rs_type_id, $rs_type_id=rs_type_id as selected, type_name from rs_type ") if (defined($rs_type_id));
	my $outlet_options = $s->sql_list("select outlet_id, $outlet_id=outlet_id as selected, outlet_name from outlet ") if (defined($outlet_id));
        
	my $sd_chip_options = $s->sql_list("select sd_id, $sd_id=sd_id as selected, sd_name from sd_chip") if (defined($sd_id));
	my $member_options = $s->sql_list("select member_id, $member_id=member_id as selected, member_name from member") if (defined($member_id));
	my $res_outlet = $s->sql_list("select outlet_id, outlet_name from outlet order by outlet_id");
	
	return {
                sd_id => $sd_id,
                sd_name=>$sd_name,
                rs_number => $rs_number,
		rs_id => $rs_id,
		rs_outlet_id => $rs_outlet_id,
		rs_type_options => $rs_type_options,
		outlet_options => $outlet_options,
		outlet_name => $outlet_name,
		outlet_id => $outlet_id,
		sd_chip_options => $sd_chip_options,
		member_options => $member_options,
		ref_type_id => $ref_type_id,
		res_outlet => $res_outlet,
        };
}

sub detail_rs_chip {
	my ($s, $q, $db, $log) = @_;
	my $rs_id = $q->param('rs_id');
	my $rs_name = $q->param('rs_name');
	my $detail = $s->sql_list('select qty, stock_ref_name, keyword from rs_stock inner join stock_ref using (stock_ref_id) where rs_id=?',$rs_id);
	return {
		list_product => $detail,
		rs_name => $rs_name,
	};
}

sub detail_stock_sd_chip {
	my ($s, $q, $db, $log) = @_;
	my $sd_id = $q->param('id');
	my $rs_number = $q->param('rs_number');
	my $outlet_name = $q->param('outlet_name');
	my $ref_type_id = $q->param('ref_type_id');
	my $status = $q->param('status');
	my $sd_name = $s->query("select sd_name from sd_chip where sd_id=?", $sd_id)->list; # $q->param('sd_name');
	my $detail = $s->sql_list(<<"__eos__", $sd_id,$ref_type_id);
		select sd_stock_id, stock_ref_id, stock_ref_name, format(ifnull(qty,0),0) as qty, format(ifnull(quota,0),0) as quota
from stock_ref 
		join sd_chip 
		left join sd_stock using (sd_id,stock_ref_id) 
		where sd_id=? and stock_ref.ref_type_id=?
__eos__
	my $list = $s->q_pager('select rs_id, rs_number, outlet_id, outlet_name, type_name, rs_chip.status, rs_chip.sd_id as sd_id, sd_name, ref_type_id from rs_chip left join rs_type using(rs_type_id) inner join sd_chip using (sd_id) inner join outlet using(outlet_id)',
	filter => {
		id => 'sd_id=?',
		rs_number => 'rs_number =?',
		outlet_name => 'outlet_name =?',
		status => 'status = ?',
		},
	); 
	
	my @array = @{$list->{list}};
#	foreach (@array) {
#		$_->{sd_id} = $sd_id;
#		$_->{sd_name} = $sd_name;
#	}
		
	return {
		list_product => $detail,
		stock_ref_options=> $s->sql_list('select stock_ref_id, stock_ref_name from stock_ref order by stock_ref_id'),
		list_rs_chip => $list->{list},
		nav => $list->{nav},
		rs_number => $rs_number,
		outlet_name => $outlet_name,
		sd_name => $sd_name,
		sd_id => $sd_id,
		count_stock	=> $db->query("select count(*) from stock_ref join sd_chip left join sd_stock using (sd_id,stock_ref_id) where sd_id=? and stock_ref.ref_type_id=?",$sd_id,$ref_type_id)->list,
		ref_type_id => $ref_type_id,
		type_options => $s->sql_list('select rs_type_id, type_name from rs_type'),
		select_outlet_names => $s->sql_list('select outlet_id, outlet_name from outlet order by outlet_name'),
		member => $s->sql_list('select member_id,member_name from member order by member_name'),
		status => $status,
	};
}

sub edit_sd_stock {
	my ($s, $q, $db, $log) = @_;
	my $sd_id = $q->param('sd_id');
	my $sd_name = $q->param('sd_name');
	my $stock_ref_id = $q->param('stock_ref_id');
	my $error = $q->param('error');
	my ($sd_stock_id, $stock_ref_name, $qty) = $db->query('select sd_stock_id, stock_ref_name, qty from sd_stock inner join stock_ref using(stock_ref_id) where sd_id=? and stock_ref_id=?', $sd_id, $stock_ref_id)->list;
	
	return {
		sd_stock_id => $sd_stock_id,
		stock_ref_name => $stock_ref_name,
		stock_ref_id => $stock_ref_id,
		qty => $qty,
		sd_name => $sd_name,
		sd_id => $sd_id,
		error => $error,
	};
}

sub stock_mutation {
	my ($s, $q, $db, $log) = @_;
	my $from = $q->param('from');
	my $until = $q->param('until');
	my $stock_ref_name = $q->param('stock_ref_name'); 
	my $sd_name = $q->param('sd_name'); 
	my $pager;
	if ($config::adm_gid eq $s->{adm_gid}) {
	$pager = $s->q_pager(<<"EOS",
select sd_id, sd_name, sd_number, sm_ts, stock_ref_name, if(trx_qty>=0,trx_qty,0) as sin, if(trx_qty<=0,trx_qty,0) as sout, stock_qty,
sd_chip.ref_type_id
from stock_mutation
inner join sd_stock using(sd_stock_id)
inner join stock_ref using (stock_ref_id)
left join topup using (trans_id)
inner join sd_chip using (sd_id)
EOS
		filter => {
			from => "sm_ts >= str_to_date(?,'%d-%m-%Y')",
			until => "sm_ts < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day)",
			stock_ref_name => "stock_ref_name like concat('%',?,'%')",
			sd_name => "sd_name =?",
		},
		extra_filter => {"stock_ref.ref_type_id=?" => 1},
		suffix => 'order by sm_ts DESC',
		comma => [qw/sin sout stock_qty/],
	);
	} else {
	$pager = $s->q_pager(<<"EOS",
select sd_id, sd_name, sd_number, sm_ts, stock_ref_name, if(trx_qty>=0,trx_qty,0) as sin, if(trx_qty<=0,trx_qty,0) as sout, stock_qty,
sd_chip.ref_type_id
from stock_mutation
inner join sd_stock using(sd_stock_id)
inner join stock_ref using (stock_ref_id)
left join topup using (trans_id)
inner join sd_chip using (sd_id)
EOS
		filter => {
			from => "sm_ts >= str_to_date(?,'%d-%m-%Y')",
			until => "sm_ts < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day)",
			stock_ref_name => "stock_ref_name like concat('%',?,'%')",
			sd_name => "sd_name =?",
			site_id => "sd_chip.site_id = ?",
		},
		extra_filter => {"site_id=?" => $s->{site_id}},
		suffix => 'order by sm_ts DESC',
		comma => [qw/sin sout stock_qty/],
	);

	}
	return {
		r_args => $s->{r}->args,
		list => $pager->{list},
        nav => $pager->{nav},
        from => $from,
        until => $until,
		stock_ref_name => $stock_ref_name,
		sd_name => $sd_name,
	};
}
sub update_sd_stock{
	my ($s, $q, $db, $log) = @_;
        my $sd_id = $q->param('sd_id');
        my $sd_name = $q->param('sd_name');
        my $stock_ref_id = $q->param('stock_ref_id');
        my ($sd_stock_id, $stock_ref_name, $qty) = $db->query('select sd_stock_id, stock_ref_name, qty from sd_stock inner join stock_ref using(stock_ref_id) where sd_id=? and stock_ref_id=?', $sd_id, $stock_ref_id)->list;

        return {
                sd_stock_id => $sd_stock_id,
                stock_ref_name => $stock_ref_name,
                qty => $qty,
                sd_name => $sd_name,
                sd_id => $sd_id,
        };

}

sub list_package {
	my ($s, $q, $db, $log) = @_;
        my $pkg_id = $q->param('pgk_id');
        my $pkg_name = $q->param('pkg_name');
	my $pager = $s->q_pager('select pkg_id, pkg_name from package');
	return{
		list =>$pager->{list},
		nav => $pager->{nav}, 
		};
	}
sub add_pkg{
	return{};
}

sub dtl_pkg {
	my ($s, $q, $db, $log) = @_;
	my $pkg_id = $q->param('pkg_id');
	my $list = $s->sql_list('select pkg_name, keyword, pkg_qty,stock_ref_id,pkg_id from package_detail inner join package using (pkg_id) inner join stock_ref using(stock_ref_id) where pkg_id = ?', $pkg_id);
	my $list_stock = $s->sql_list('select stock_ref_id, keyword from stock_ref');
	return {
		list_detail => $list,
		list_stock => $list_stock,
		pkg_id => $q->param('pkg_id'),
		pkg_name => $db->query('select pkg_name from package where pkg_id=?', $q->param('pkg_id'))->list,
	}
}

sub approve_stock {
	my ($s, $q, $db, $log) = @_;
	
	my $from = $q->param('from');
	my $until = $q->param('until');
	my $where = site($s,'approve');
	
	my $res = $s->sql_list(<<"EOS",
		select sd_name, stock_ref_name, qty_tmp, admin_name, sd_stock_ts, sd_stock_id
from sd_stock
		inner join sd_chip using (sd_id)
		inner join stock_ref using (stock_ref_id)
		inner join admin using (admin_id)
		where sd_stock_ts >= str_to_date('$from','%d-%m-%Y') and sd_stock_ts < date_add(str_to_date('$until','%d-%m-%Y'), interval 1 day)
		and qty_tmp <> 0 $where
		order by sd_stock_ts desc
EOS
	);
	
	return {
		list	=> $res,
		from 	=> $from,
        until 	=> $until,
	}
}

sub site {
	my $s = shift;
	my $desc = shift;

	my $where = '';
	my $site = $s->{site_id};
	if($site){
		if($desc eq 'approve'){
			$where = "and sd_chip.site_id=$site";
		}else{
			$where = "and site_id=$site";
		}
	}
	return $where;
}

sub total_stock{
	my ($s, $q, $db, $log) = @_;
	
	my $from = $q->param('from');
	my $until = $q->param('until');
	my $opt = "order by stock_ref_id separator '<hr style=\"border-style:none none dotted;height:1px;padding:1px;margin:2px\">'";
	my $where = site($s,'total');
	my $res;
	if ($config::adm_gid eq $s->{adm_gid}) {
	$res = $s->sql_list(<<"EOS",
		select sd_stock_id, sd_id, sd_name, stock_ref_name, sum(if(trx_qty > 0,trx_qty,0)) as stock_in, sum(if(trx_qty < 0, trx_qty, 0)) as stock_out,
		qty as total_stock, qty - sum(if(trx_qty > 0,trx_qty,0) + if(trx_qty < 0, trx_qty, 0)) as prev_stock 
from sd_stock
		inner join stock_ref using (stock_ref_id)
		inner join sd_chip using (sd_id)
		left join stock_mutation using (sd_stock_id)
		where stock_ref.ref_type_id=1 and sm_ts >= str_to_date('$from','%d-%m-%Y') and sm_ts < date_add(str_to_date('$until','%d-%m-%Y'), interval 1 day)
		group by sd_id,sd_stock_id
EOS
);
	} else {
	$res = $s->sql_list(<<"EOS",
		select sd_stock_id, sd_id, sd_name, stock_ref_name, sum(if(trx_qty > 0,trx_qty,0)) as stock_in, sum(if(trx_qty < 0, trx_qty, 0)) as stock_out,
		qty as total_stock, qty - sum(if(trx_qty > 0,trx_qty,0) + if(trx_qty < 0, trx_qty, 0)) as prev_stock 
from sd_stock
		inner join stock_ref using (stock_ref_id)
		inner join sd_chip using (sd_id)
		left join stock_mutation using (sd_stock_id)
		where sm_ts >= str_to_date('$from','%d-%m-%Y') and sm_ts < date_add(str_to_date('$until','%d-%m-%Y'), interval 1 day)
		$where
		group by sd_id,sd_stock_id
EOS
);
	}
	return{
		list	=> $res,
		from	=> $from,
		until	=> $until,
	}
}

1;
