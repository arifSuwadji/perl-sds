package view::outlet;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use config;

sub list {
	my ($s,$q,$db,$log) = @_;
	my $outlet_id = $q->param('outlet_id')||'';
	my $site_id = $q->param('site_id')||'';
	my $site_name = '';
	$site_name = $db->query("select site_name from site where site_id = ?", $site_id)->list if $site_id;
	my $pager = $s->q_pager(<<"EOS",
		select outlet_id, outlet_name, address, district, sub_district, pos_code, owner, username as mobile_phone, pin, type_name, format(plafond,0) as plafond, 
		format(balance,0) as balance, date_format(curdate(),'%d-%m-%Y') as date_from, date_format(curdate(),'%d-%m-%Y') as until, member_name, outlet.status
from outlet 
		left join rs_chip using(outlet_id)
		left join member using (member_id)
		inner join outlet_type using (outlet_type_id)
		left join user using (outlet_id)
EOS
	
	filter => {
		outlet_name => "outlet_name like concat(?,'%')",
		rs_number => "rs_number like concat(?,'%')",
		member_name => "member_name like concat(?,'%')",
		status => "outlet.status like concat(?,'%')",
		sub_district => "sub_district like concat(?,'%')",
		},
	extra_filter => {"member.site_id=?" => $s->{site_id},
			"outlet.district=?" => $site_name},
	suffix => 'group by outlet_id',
	);
	
	my $member_opt = $s->sql_list(<<"EOS", 
	select member_name from member where status='Active' 
EOS
	);
	return {
		list_outlet => $pager->{list},
		nav => $pager->{nav},
		outlet_id => $outlet_id,
		outlet_name => $q->param('outlet_name')||'',
		rs_number => $q->param('rs_number')||'',
		member_opt => $member_opt,
		member_name => $q->param('member_name') || '',
		status => $q->param('status') || '',
		sub_district => $q->param('sub_district') || '',
		birth_date => $q->param('birth_date') || '',
		district => $site_name,
	};
}

sub add_outlet {
	my ($s,$q,$db,$log) = @_;
	
	my $opt_type = $s->sql_list(<<"EOS",
		select outlet_type_id, type_name from outlet_type
EOS
	);
	
	return {
		opt_type => $opt_type,
		birth_date => $q->param('birth_date') || '',
	};
}

sub edit_outlet {
	my ($s,$q,$db,$log) = @_;
	my $outlet_id = $q->param('id');
	my ($outlet_name, $address, $district, $sub_district, $pos_code, $owner, $mobile_phone, $outlet_type_id, $type_name, $plafond, $status, $birth_date) = $db->query("select outlet_name, address, district, sub_district, pos_code, owner, username as mobile_phone, outlet_type_id, type_name, plafond, outlet.status, date_format(birth_date,'%d-%m-%Y') from outlet inner join outlet_type using (outlet_type_id) left join user using (outlet_id) where outlet_id=?", $outlet_id)->list;
	my $opt_type = $s->sql_list(<<"EOS",
		select outlet_type_id, type_name from outlet_type
EOS
);
	my $ro = $s->q_pager(<<"EOS",
select outlet_id, rs_id, sd_name, sd_number, rs_number,rs_chip_type
from rs_chip inner join sd_chip using(sd_id)
EOS
		filter => {
			id => 'outlet_id=?',
		},
		extra_filter => {
			"sd_chip.ref_type_id=?" => $s->{ref_type_id},
		},
	);

	return {
		outlet_name => $outlet_name,
		address => $address,
		district => $district,
		sub_district => $sub_district,
		pos_code => $pos_code,
		owner => $owner,
		mobile_phone => $mobile_phone,
		outlet_id => $outlet_id,
		outlet_type_id => $outlet_type_id,
		type_name => $type_name,
		plafond => $plafond,
		opt_type => $opt_type,
		status => $status,
		birth_date => $birth_date,
		ro_list => $ro->{list},
		ro_nav => $ro->{nav},
	};
}

sub view_outlet {
	my ($s,$q,$db,$log) = @_;
	my $outlet_id = $q->param('id');
	my ($outlet_name, $address, $district, $sub_district, $pos_code, $owner, $mobile_phone, $outlet_type_id, $type_name, $plafond, $status, $birth_date, $nominal_quota, $nominal_quota_format, $balance_nominal, $qty_quota, $qty_quota_format, $balance_qty) = $db->query("select outlet_name, address, district, sub_district, pos_code, owner, username as mobile_phone, outlet_type_id, type_name, format(plafond,0), outlet.status, date_format(birth_date,'%d-%m-%Y'), nominal_quota, format(nominal_quota,0), format(balance_nominal,0), qty_quota, format(qty_quota,0), format(balance_qty,0) from outlet inner join outlet_type using (outlet_type_id) left join user using (outlet_id) where outlet_id=?", $outlet_id)->list;
	my $ro = $s->q_pager(<<"EOS",
select rs_id, sd_name, sd_number, rs_number,rs_chip_type, ref_type_id
from rs_chip inner join sd_chip using(sd_id)
EOS
		filter => {id => 'outlet_id=?',},
		extra_filter => {
			'outlet_id=?' =>  $outlet_id,
			"sd_chip.ref_type_id=?" => $s->{ref_type_id},
		},
	);
	my $where = "where outlet_id=$outlet_id";
	$where .= " and stock_ref.ref_type_id= $s->{ref_type_id}" if $s->{ref_type_id};
	my $detail = $s->sql_list("select outlet_quota_id, stock_ref_id, stock_ref_name, quota, format(ifnull(quota,0),0) as quota_format
from stock_ref 
join outlet 
left join outlet_quota using (outlet_id,stock_ref_id)
$where");
	my $count_stock	= $db->query("select count(*) from stock_ref join outlet left join outlet_quota using (outlet_id,stock_ref_id) $where")->list;
	return {
		outlet_name => $outlet_name,
		address => $address,
		district => $district,
		sub_district => $sub_district,
		pos_code => $pos_code,
		owner => $owner,
		mobile_phone => $mobile_phone,
		outlet_id => $outlet_id,
		ro_list => $ro->{list},
		ro_nav => $ro->{nav},
		outlet_type_id => $outlet_type_id,
		type_name => $type_name,
		plafond => $plafond,
		status => $status,
		birth_date => $birth_date,
		list_product => $detail,
		outlet_id => $outlet_id,
		ref_type_id => $s->{ref_type_id},
		count_stock => $count_stock,
		nominal_quota => $nominal_quota,
		nominal_quota_format => $nominal_quota_format,
		balance_nominal => $balance_nominal,
		qty_quota => $qty_quota,
		qty_quota_format => $qty_quota_format,
		balance_qty => $balance_qty,
	};
}

sub detail_rs {
	my($s,$q,$db,$log) = @_;

	my $rs_id = $q->param('rs_id');
	my $ref_type_id = $q->param('ref_type_id');
	my $rs_number = $q->param('rs_number');
	my $detail = $s->sql_list(<<"__eos__", $rs_id,$ref_type_id);
select rs_stock_id, stock_ref_id, stock_ref_name, quota, format(ifnull(quota,0),0) as quota_format
from stock_ref
join rs_chip 
left join rs_stock using (rs_id,stock_ref_id)
where rs_id = ? and stock_ref.ref_type_id= ?
__eos__

	my $count_stock	= $db->query("select count(*) from stock_ref join rs_chip left join rs_stock using (rs_id,stock_ref_id) where rs_id = ? and stock_ref.ref_type_id= ?", $rs_id, $ref_type_id)->list;
	my ($rs_nominal_quota, $rs_nominal_quota_format, $rs_balance_nominal, $rs_qty_quota, $rs_qty_quota_format, $rs_balance_qty) =  $db->query('select rs_nominal_quota, format(rs_nominal_quota,0), format(rs_balance_nominal,0), rs_qty_quota, format(rs_qty_quota,0), format(rs_balance_qty,0) from rs_chip where rs_id=?',$rs_id)->list;
	return {
		list_product => $detail,
		rs_number => $rs_number,
		rs_id => $rs_id,
		ref_type_id => $ref_type_id,
		count_stock => $count_stock,
		rs_nominal_quota => $rs_nominal_quota,
		rs_nominal_quota_format => $rs_nominal_quota_format,
		rs_balance_nominal => $rs_balance_nominal,
		rs_qty_quota => $rs_qty_quota,
		rs_qty_quota_format => $rs_qty_quota_format,
		rs_balance_qty => $rs_balance_qty,
	};
}

sub outlet_type {
	my($s,$q,$db,$log) = @_;

	my $header = $s->sql_list(<<"EOS",
		select type_name, period from outlet_type order by period,outlet_type_id
EOS
	);
	my $res;
	if ($config::adm_gid eq $s->{adm_gid}) {
	$res = $s->sql_list(<<"EOS",
		select outlet_type_id, type_name, period, stock_ref_name, stock_ref_id,
	concat(\'<td align="right">\',
    group_concat(ifnull(format(price,2),0)
      order by period,outlet_type_id
      separator \'\</td><td align="right">\'
    ),
    \'\</td>\'
  )as price
	
from stock_ref
		join outlet_type
		left join outlet_pricing using (outlet_type_id, stock_ref_id)
		where ref_type_id=1
		group by stock_ref_id
		order by id_serial
EOS
	);

	} else {		
	$res = $s->sql_list(<<"EOS",
		select outlet_type_id, type_name, period, stock_ref_name, stock_ref_id,
	concat(\'<td align="right">\',
    group_concat(ifnull(format(price,2),0)
      order by period,outlet_type_id
      separator \'\</td><td align="right">\'
    ),
    \'\</td>\'
  )as price
	
from stock_ref
		join outlet_type
		left join outlet_pricing using (outlet_type_id, stock_ref_id)
		group by stock_ref_id
		order by id_serial
EOS
	);
	}
	my $t_name = $s->sql_list(<<"EOS"
		select outlet_type_id, type_name from outlet_type
EOS
	);
	
	my $product = $s->sql_list(<<"EOS",
		select stock_ref_id, stock_ref_name from stock_ref
EOS
	);

	my $o_type = $s->sql_list(<<"EOS",
		select outlet_type_id, type_name, period from outlet_type order by period
EOS
);
	my $count = $db->query("select count(*) from outlet_type")->list;
	return{
		head	=> $header,
		list	=> $res,
		t_name	=> $t_name,
		product	=> $product,
		o_type	=> $o_type,
		count	=> $count,
	};
}

sub edit_outlet_type{
	my($s,$q,$db,$log) = @_;
	
	my $id_stock = $q->param('id_stock');
	my $ref_name = $q->param('ref_name');
	my $res = $s->sql_list(<<"EOS",
		select stock_ref_id, ifnull(price,0) as price, outlet_type_id, type_name
from stock_ref
	join outlet_type
	left join outlet_pricing using (outlet_type_id, stock_ref_id)
	where stock_ref_id = $id_stock
EOS
);
	
	return{
		list 		=> $res,
		ref_name	=> $ref_name,
	};
}

sub mutation{
	my($s,$q,$db,$log) = @_;
	
	my $from = $s->param('from');
	my $until = $s->param('until');
	my $outlet_id = $s->param('id');
	
	my ($outlet_name, $plafond, $balance) = $db->query('select outlet_name, format(plafond,2), format(balance,2) outlet from outlet where outlet_id=?', $outlet_id)->list;

	my $res = $s->q_pager(<<"EOS",
		select format(outlet_mutation.balance,2) as balance, if(mutation < 0,format(-mutation,2),0) as debit, if(mutation > 0,format(mutation,2),0) as credit, 
		transaction.trans_id, trans_date, trans_time, trans_type, concat(invoice.outlet_id,'/',inv_date) as invoice_number
from invoice
		inner join outlet using (outlet_id)
		left join outlet_mutation using (outlet_id)
		inner join transaction transaction on transaction.trans_id = outlet_mutation.trans_id
EOS
	filter => {
		id	=> 'invoice.outlet_id = ?',
		from => "trans_date >= str_to_date(?,'%d-%m-%Y')",
		until => "trans_date <= str_to_date(?,'%d-%m-%Y')",

	},
	suffix => 'group by trans_id order by debit,trans_id desc',
	);
		
	return{
		mutation => $res->{list},
		nav => $res->{nav},
		from => $from,
		until => $until,
		outlet_id => $outlet_id,
		outlet_name => $outlet_name,
		balance => $balance,
		max_credit => $plafond,
	};
}

1;

