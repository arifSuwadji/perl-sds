package view::transaction;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use config;
use view::stock;

sub list {
	my ($s,$q,$db,$log) = @_;
	# $log->warn('session ref type id = ', $s->{ref_type_id});	
	my $member_id = $q->param('member_id');
	my $member_name = $q->param('member_name')||'';
	my $from = $q->param('from');
	my $sd_name = $s->param('sd_name');
	
	my $result = $db->query('select ref_type_id, ref_type_name from stock_ref_type');
	my @sd_type_options;
	while(my ($ref_type_id, $ref_type_name) = $result->list) {
		push @sd_type_options, { value=>$ref_type_id, display=>$ref_type_name};
	}
	$_->{selected} = $_->{value} eq ($q->param('sd_type_id')||'') ? 1:0 foreach @sd_type_options; 		
	$log->warn($q->param('sd_type_id'), "test");
		
	my @status_options = (
			{value=>'WA', display=>'Waiting Approval'},
			{value=>'WT', display=>'Waiting Token'},
			{value=>'CT', display=>'Confirm Token'},
			{value=>'D', display=>'Drop'},
			{value=>'W', display=>'Waiting'},
			{value=>'P', display=>'Pending'},
			{value=>'F', display=>'Failed'},
			{value=>'S', display=>'Success'},
			{value=>'R', display=>'Reversal'},
			);
	$_->{selected} = $_->{value} eq ($s->param('status')||'') ? 1:0 foreach @status_options;
	
	my $until = $q->param('until');
	my $type = $q->param('type')||'';
	my $keyword = $q->param('keyword')||'';
	my $status = $q->param('status')||'';
	my $admin_name = $q->param('admin_name')||'';
	my $rs_number = $q->param('rs_number')||'';
	my $username = $q->param('username')||'';
	my $outlet_name = $q->param('outlet')||'';

	my $order_by = "ORDER BY topup_id DESC";
	if($config::akses_request){
		$order_by = "ORDER BY exec_ts DESC";
		$order_by = "ORDER BY last_balance ASC" if $keyword;
	}

	# admin_id dalam topup-web dan transaction :
	# - di topup-web sbg pelaku/trigger transaksi
	# - di transaction sbg admnistrator/CS
	#
			
	my $pager;
	# $log->warn($config::$stockbase_admin);
	if ($config::adm_gid eq $s->{adm_gid}) {
	if ($config::stockbase_admin) {
		$log->warn('di dalam stock_base');
		$pager = $s->q_pager(<<"EOS",
SELECT parent.member_name as member_name, trans_id, topup_ts, keyword, ifnull(rs_number, dest_msisdn) as rs_number,
  stock_ref_type.ref_type_name, price,
  type_name as rs_type_name, sd_name, topup_qty, site_name,
  topup_status, ceil(amount) as amount, error_msg, log_msg, outlet_name,
  case topup_status when 'WA' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') when 'F' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') end as approve,
  case payment_gateway when 1 then 'Mandiri Payment' end as payment_type, token_sgo, IF(admin_log.admin_id IS NULL, 'CANVS', admin_name) AS  admin_name
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)
  INNER JOIN stock_ref_type on stock_ref.ref_type_id=stock_ref_type.ref_type_id
  
  LEFT JOIN topup_web using(topup_id)
  LEFT JOIN admin_log using(admin_log_id)
  LEFT JOIN admin using(admin_id)

  LEFT JOIN rs_chip using (rs_id)
  LEFT JOIN outlet using(outlet_id)
  LEFT JOIN rs_type using (rs_type_id)

  LEFT JOIN sd_chip using (sd_id)
  LEFT JOIN site on sd_chip.site_id = site.site_id
  INNER JOIN member on member.member_id=topup.member_id
  INNER JOIN member parent on member.parent_id = parent.member_id
  
  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
  LEFT JOIN topup_sms using (topup_id)
  LEFT JOIN pricing using(stock_ref_id,rs_type_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword like concat('%',?,'%')",
				rs_number => "rs_number = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				site_id => "sd_chip.site_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				sd_type_id => "stock_ref.ref_type_id =?",
				outlet => "outlet_name like concat(?, '%')",
			},
			extra_filter => {
				"sd_chip.ref_type_id=?" => $s->{ref_type_id},
				"stock_ref_type.ref_type_id=?" => 1,
				"(member.member_id = ? or member.parent_id=?)" => $s->{mem_id},
			},
			suffix => 'order by topup_id desc',
			comma => ['topup_qty', 'amount'],
		);
	} else {
		$pager = $s->q_pager(<<"EOS",
SELECT trans_id, topup_ts, keyword, rs_number, stock_ref_type.ref_type_name,
  type_name as rs_type_name, sd_name, site_name, topup_qty, price,
  topup_status, ceil(amount) as amount, member_name, error_msg, log_msg, outlet_name,
  case topup_status when 'WA' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') when 'F' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') end as approve,
  case payment_gateway when 1 then 'Mandiri Payment' end as payment_type, token_sgo, IF(admin_log.admin_id IS NULL, 'CANVS', admin_name) AS  admin_name
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)
  LEFT JOIN topup_web using(topup_id)
  LEFT JOIN admin_log using(admin_log_id)
  LEFT JOIN admin using(admin_id)
  
  INNER JOIN rs_chip using(rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  LEFT JOIN stock_ref_type on sd_chip.ref_type_id=stock_ref_type.ref_type_id
  INNER JOIN site on sd_chip.site_id = site.site_id
  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
  LEFT JOIN pricing using(stock_ref_id,rs_type_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword like concat('%',?,'%')",
				rs_number => "rs_number = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				site_id => "sd_chip.site_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				sd_type_id => "sd_chip.ref_type_id =?",
				outlet => "outlet_name like concat(?, '%')",
				},
			extra_filter => {"sd_chip.site_id=?" => $s->{site_id}},
			suffix => 'order by topup_id desc',
			comma => ['topup_qty', 'amount'],
		);
	}
	} else {
		if ($config::stockbase_admin) {
		$log->warn('di dalam stock_base');
		$pager = $s->q_pager(<<"EOS",
SELECT trans_id, topup_ts, keyword, ifnull(rs_number, dest_msisdn) as rs_number,
  stock_ref_type.ref_type_name, format(price,0) as price,
  type_name as rs_type_name, sd_name, topup_qty, site_name,
  topup_status, ceil(amount) as amount, member_name, error_msg, log_msg, outlet_name,
  case topup_status when 'WA' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') when 'F' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') end as approve,
  case payment_gateway when 1 then 'Mandiri Payment' end as payment_type, token_sgo, last_balance, IF(admin_log.admin_id IS NULL, 'CANVS', admin_name) AS  admin_name, username
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)
  LEFT JOIN topup_web using(topup_id)
  LEFT JOIN admin_log using(admin_log_id)
  LEFT JOIN admin using(admin_id)
  INNER JOIN stock_ref_type on stock_ref.ref_type_id=stock_ref_type.ref_type_id

  LEFT JOIN rs_chip using (rs_id)
  LEFT JOIN outlet using(outlet_id)
  LEFT JOIN rs_type using (rs_type_id)

  LEFT JOIN sd_chip using (sd_id)
  LEFT JOIN site on sd_chip.site_id = site.site_id
  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
  LEFT JOIN topup_sms using (topup_id)
  LEFT JOIN pricing using(stock_ref_id,rs_type_id)

  LEFT JOIN stock_denom using(trans_id,stock_ref_id)
  LEFT JOIN sms USING (sms_id)
  LEFT JOIN user using (user_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword = ?",
				rs_number => "rs_number = ?",
				username => "username = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				site_id => "sd_chip.site_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				sd_type_id => "stock_ref.ref_type_id =?",
				outlet => "outlet_name like concat(?, '%')",
			},
			extra_filter => {"sd_chip.ref_type_id=?" => $s->{ref_type_id},
					"sd_chip.site_id=?" => $s->{site_id},
			},
			suffix => $order_by,
			comma => ['topup_qty', 'amount'],
		);
	} else {
		$pager = $s->q_pager(<<"EOS",
SELECT trans_id, topup_ts, keyword, rs_number, stock_ref_type.ref_type_name,
  type_name as rs_type_name, sd_name, site_name, topup_qty, format(price,0) as price,
  topup_status, ceil(amount) as amount, member_name, error_msg, log_msg, outlet_name,
  case topup_status when 'WA' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') when 'F' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') end as approve,
  case payment_gateway when 1 then 'Mandiri Payment' end as payment_type, token_sgo, IF(admin_log.admin_id IS NULL, 'CANVS', admin_name) AS  admin_name
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)
  LEFT JOIN topup_web using(topup_id)
  LEFT JOIN admin_log using(admin_log_id)
  LEFT JOIN admin using(admin_id)
  
  INNER JOIN rs_chip using (rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  LEFT JOIN stock_ref_type on sd_chip.ref_type_id=stock_ref_type.ref_type_id
  INNER JOIN site on sd_chip.site_id = site.site_id
  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
  LEFT JOIN pricing using(stock_ref_id,rs_type_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword like concat('%',?,'%')",
				rs_number => "rs_number = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				site_id => "sd_chip.site_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				sd_type_id => "sd_chip.ref_type_id =?",
				outlet => "outlet_name like concat(?, '%')",
				},
			extra_filter => {"sd_chip.site_id=?" => $s->{site_id}},
			suffix => 'order by topup_id desc',
			comma => ['topup_qty', 'amount'],
		);
		}
	}

	return {
		r_args => $s->{r}->args,
		list_transaction => $pager->{list},
		nav => $pager->{nav},
		from => $from,
		until => $until,
		keyword => $keyword,
		rs_number => $rs_number,
		username => $username,
		status_options => \@status_options,
		sd_type_options => \@sd_type_options,
		member_name => $member_name,
		admin_name => $admin_name,
		sd_name => $sd_name,
		outlet_name => $outlet_name,
	};
}

sub dompul_list {
	my ($s,$q,$db,$log) = @_;
	# $log->warn('session ref type id = ', $s->{ref_type_id});	
	my $member_id = $q->param('member_id');
	my $member_name = $q->param('member_name')||'';
	my $from = $q->param('from');
	my $sd_name = $s->param('sd_name');
	
	my $result = $db->query('select ref_type_id, ref_type_name from stock_ref_type');
	my @sd_type_options;
	while(my ($ref_type_id, $ref_type_name) = $result->list) {
		push @sd_type_options, { value=>$ref_type_id, display=>$ref_type_name};
	}
	$_->{selected} = $_->{value} eq ($q->param('sd_type_id')||'') ? 1:0 foreach @sd_type_options; 		
	$log->warn($q->param('sd_type_id'), "test");
		
	my @status_options = (
			{value=>'WA', display=>'Waiting Approval'},
			{value=>'W', display=>'Waiting'},
			{value=>'F', display=>'Failed'},
			{value=>'S', display=>'Success'},
			{value=>'R', display=>'Reversal'},
			);
	$_->{selected} = $_->{value} eq ($s->param('status')||'') ? 1:0 foreach @status_options;
	
	my $until = $q->param('until');
	my $type = $q->param('type')||'';
	my $keyword = $q->param('keyword')||'';
	my $status = $q->param('status')||'';
	my $admin_name = $q->param('admin_name')||'';
	my $rs_number = $q->param('rs_number')||'';
	my $outlet_name = $q->param('outlet')||'';


	# admin_id dalam topup-web dan transaction :
	# - di topup-web sbg pelaku/trigger transaksi
	# - di transaction sbg admnistrator/CS
	#
			
	my $pager;
	# $log->warn($config::$stockbase_admin);
	if ($config::stockbase_admin) {
		$log->warn('di dalam stock_base');
		$pager = $s->q_pager(<<"EOS",
SELECT rs_member.member_name as membername, member.member_name as topup_member, trans_id, topup_ts, keyword, ifnull(rs_number, dest_msisdn) as rs_number,
  stock_ref_type.ref_type_name,
  type_name as rs_type_name, sd_name, topup_qty, site_name,
  topup_status, amount, error_msg, log_msg, outlet_name,
  case topup_status when 'WA' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') end as approve
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)
  INNER JOIN stock_ref_type on stock_ref.ref_type_id=stock_ref_type.ref_type_id

  LEFT JOIN rs_chip using (rs_id)
  LEFT JOIN outlet using(outlet_id)
  LEFT JOIN rs_type using (rs_type_id)

  LEFT JOIN sd_chip using (sd_id)
  LEFT JOIN site using (site_id)
  INNER JOIN member on member.member_id=topup.member_id
  LEFT JOIN member rs_member on rs_chip.member_id = rs_member.member_id
  
  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
  LEFT JOIN topup_sms using (topup_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword like concat('%',?,'%')",
				rs_number => "rs_number = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				site_id => "sd_chip.site_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				sd_type_id => "stock_ref.ref_type_id =?",
				outlet => "outlet_name like concat(?, '%')",
			},
			extra_filter => {
			"sd_chip.ref_type_id=?" => $s->{ref_type_id},
			"stock_ref_type.ref_type_id=?" => 1,
			"(member.member_id = ? or member.parent_id=?)" => $s->{mem_id},
			},
			suffix => 'order by topup_id desc',
			comma => ['topup_qty', 'amount'],
		);
	} else {
		$pager = $s->q_pager(<<"EOS",
SELECT trans_id, topup_ts, keyword, rs_number, stock_ref_type.ref_type_name,
  type_name as rs_type_name, sd_name, site_name, topup_qty,
  topup_status, amount, member_name, error_msg, log_msg, outlet_name,
  case topup_status when 'WA' then concat('<input type=checkbox name=topup_id value=',topup_id,'>') end as approve
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)

  INNER JOIN rs_chip using (rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  LEFT JOIN stock_ref_type on sd_chip.ref_type_id=stock_ref_type.ref_type_id
  INNER JOIN site using (site_id)
  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword like concat('%',?,'%')",
				rs_number => "rs_number = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				site_id => "sd_chip.site_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				sd_type_id => "sd_chip.ref_type_id =?",
				outlet => "outlet_name like concat(?, '%')",
				},
			extra_filter => {"sd_chip.site_id=?" => $s->{site_id}},
			suffix => 'order by topup_id desc',
			comma => ['topup_qty', 'amount'],
		);
	}

	return {
		r_args => $s->{r}->args,
		list_transaction => $pager->{list},
		nav => $pager->{nav},
		from => $from,
		until => $until,
		keyword => $keyword,
		rs_number => $rs_number,
		status_options => \@status_options,
		sd_type_options => \@sd_type_options,
		member_name => $member_name,
		admin_name => $admin_name,
		sd_name => $sd_name,
		outlet_name => $outlet_name,
	};
}

sub voucher_list {
    my ($s,$q,$db,$log) = @_;
    my $from = $q->param('from');
    my $until = $q->param('until');
    my $outlet = $q->param('outlet');
    my $pager = $s->q_pager(<<"EOS",
    select sale_id, sale_ts, mb1.member_name as membername, mb2.member_name as member_rs, ref_type_name, qty_sale, rs_number, outlet_name, out_msg 
    from dompul_sale 
    inner join stock_ref_type using (ref_type_id) 
    inner join sms_outbox using (sms_id) 
    inner join rs_chip using (rs_id) 
    inner join outlet using (outlet_id) 
    inner join member mb1 on mb1.member_id = dompul_sale.member_id 
    inner join member mb2 on mb2.member_id = rs_chip.member_id
EOS
    filter => {
        from => "sale_ts >= str_to_date(?,'%d-%m-%Y')",
        until => 'sale_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
        outlet => "outlet_name like concat(?, '%')",
    }
    );
    return {
        list_transaction => $pager->{list},
        nav => $pager->{nav},
        from => $from,
        until => $until,
        outlet => $outlet,
    }
}

sub lock_totalan {
	my ($s,$q,$db,$log) = @_;
		
	my $from = $q->param('from');
	my $until = $q->param('until');
	return {
		from => $from,
		until => $until,
	}
}


sub double_list {
	my ($s,$q,$db,$log) = @_;
		
	my $member_id = $q->param('member_id');
	my $member_name = $q->param('member_name')||'';
	my $from = $q->param('from');
	my $sd_name = $s->param('sd_name');
		
	my @status_options = (
			{value=>'W', display=>'Waiting'},
			{value=>'F', display=>'Failed'},
			{value=>'S', display=>'Success'},
			{value=>'R', display=>'Reversal'},
			);
	$_->{selected} = $_->{value} eq ($q->param('status')||'') ? 1:0 foreach @status_options;

	my $until = $q->param('until');
	my $type = $q->param('type')||'';
	my $keyword = $q->param('keyword')||'';
	my $status = $q->param('status')||'';
	my $admin_name = $q->param('admin_name')||'';
	my $rs_number = $q->param('rs_number')||'';

	

	# admin_id dalam topup-web dan transaction :
	# - di topup-web sbg pelaku/trigger transaksi
	# - di transaction sbg admnistrator/CS
	#
	my $pager2;
	my $pager;
	if ($config::stockbase_admin) {
		$pager = $s->q_pager(<<"EOS",
SELECT count(rs_id) as count, rs_id, group_concat(trans_id) as atrans_id, group_concat(topup_ts separator '<hr>') as atopup_ts, group_concat(keyword separator '<hr>') as akeyword, rs_number
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)

  INNER JOIN rs_chip using (rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  INNER JOIN site using (site_id)

  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword like concat('%',?,'%')",
				rs_number => "rs_number = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				ref_type_id => "sd_chip.ref_type_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				outlet_id => "rs_chip.outlet_id = ?",

			},
			extra_filter => {"sd_chip.ref_type_id=?" => $s->{ref_type_id}},
			suffix => 'group by (rs_id) order by topup_id desc',
			comma => ['topup_qty', 'amount'],
		);
	} else {
		$pager = $s->q_pager(<<"EOS",
SELECT count(rs_id) as count, rs_id, group_concat(trans_id) as atrans_id, group_concat(topup_ts separator '<hr>') as atopup_ts, group_concat(keyword separator '<hr>') as akeyword, rs_number
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)

  INNER JOIN rs_chip using (rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  INNER JOIN site using (site_id)

  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
EOS
		filter => {
			from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
			until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
			type => "trans_type = ?",
			keyword=> "keyword like concat('%',?,'%')",
			rs_number => "rs_number = ?",
			status => "topup_status = ?",
			member_name => "member_name like concat('%',?,'%')",
			admin_name => "admin_name like concat('%',?,'%')",
			rs_type_id => "rs_chip.rs_type_id = ?",
			site_id => "sd_chip.site_id = ?",
			sd_name => "sd_name like concat('%',?,'%')",
			outlet_id => "rs_chip.outlet_id = ?",

		},
		extra_filter => {"sd_chip.site_id=?" => $s->{site_id}},
		suffix => 'group by (rs_id) order by topup_id desc',
			comma => ['topup_qty', 'amount'],
		);
	}
	$log->warn(ref $pager->{list});
	my @array = @{$pager->{list}};	
	my @array2;	
	my @array3;
	for (my $i=0;$i<scalar(@array);$i++) {
		unless ($array[$i]->{count} > 1) {
			$log->warn('rs_number terdeteksi hanya sekali');
			delete($array[$i]);
		} else {
			my $hashref = $array[$i];
			my @keyword = split /<hr>/, $hashref->{akeyword};
			$log->warn('@keyword :',@keyword);
			my $key = join(',', @keyword);
			$log->warn($key);
			
			my $rs_id = $hashref->{rs_id};
			$log->warn($rs_id);
			if ($config::stockbase_admin) {			
			$pager2 = $s->q_pager(<<"EOS",
SELECT count(keyword) as count, rs_id, group_concat(trans_id) as atrans_id, group_concat(topup_ts separator '<hr>') as atopup_ts, group_concat(keyword separator '<hr>') as akeyword, rs_number,
  group_concat(type_name separator '<hr>') as ars_type_name, group_concat(sd_name separator '<hr>') as asd_name, group_concat(site_name separator '<hr>') as asite_name, group_concat(topup_qty separator '<hr>') as atopup_qty,
  group_concat(topup_status separator '<hr>') as atopup_status, group_concat(amount separator '<hr>') as aamount, group_concat(member_name separator '<hr>') as amember_name, group_concat(error_msg separator '<hr>') as aerror_msg, group_concat(log_msg separator '<hr>') as alog_msg, group_concat(outlet_name separator '<hr>') as aoutlet_name
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)

  INNER JOIN rs_chip using (rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  INNER JOIN site using (site_id)

  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword like concat('%',?,'%')",
				rs_number => "rs_number = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				site_id => "sd_chip.site_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				outlet_id => "rs_chip.outlet_id = ?",
			},
			extra_filter => {"sd_chip.ref_type_id=?" => $s->{ref_type_id}},
			suffix => " and rs_id = '$rs_id' group by (stock_ref_id) order by topup_id desc",
			comma => ['topup_qty', 'amount'],
			);
			
		} else {		
			$pager2 = $s->q_pager(<<"EOS",
SELECT count(keyword) as count, rs_id, group_concat(trans_id) as atrans_id, group_concat(topup_ts separator '<hr>') as atopup_ts, group_concat(keyword separator '<hr>') as akeyword, rs_number,
  group_concat(type_name separator '<hr>') as ars_type_name, group_concat(sd_name separator '<hr>') as asd_name, group_concat(site_name separator '<hr>') as asite_name, group_concat(topup_qty separator '<hr>') as atopup_qty,
  group_concat(topup_status separator '<hr>') as atopup_status, group_concat(amount separator '<hr>') as aamount, group_concat(member_name separator '<hr>') as amember_name, group_concat(error_msg separator '<hr>') as aerror_msg, group_concat(log_msg separator '<hr>') as alog_msg, group_concat(outlet_name separator '<hr>') as aoutlet_name
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)

  INNER JOIN rs_chip using (rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  INNER JOIN site using (site_id)

  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
EOS
			filter => {
				from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
				until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
				type => "trans_type = ?",
				keyword=> "keyword like concat('%',?,'%')",
				rs_number => "rs_number = ?",
				status => "topup_status = ?",
				member_name => "member_name like concat('%',?,'%')",
				admin_name => "admin_name like concat('%',?,'%')",
				rs_type_id => "rs_chip.rs_type_id = ?",
				site_id => "sd_chip.site_id = ?",
				sd_name => "sd_name like concat('%',?,'%')",
				outlet_id => "rs_chip.outlet_id = ?",
			},
			suffix => " and rs_id = '$rs_id' group by (stock_ref_id) order by topup_id desc",
			comma => ['topup_qty', 'amount'],
			);
		}
			
			$log->warn(ref $pager2->{list});
		        @array2 = @{$pager2->{list}};

	        	for (my $i=0;$i<scalar(@array2);$i++) {
        	        	unless ($array2[$i]->{count} > 1) {
                	        	$log->warn('keyword terdeteksi hanya sekali');
	                        	delete($array2[$i]);
					next;
	        	        }	
				push @array3, $array2[$i];	
			}
		
		}

	}
	my $i=1;
	
	for(my $i=0; $i< scalar(@array3); $i++) {
		$array3[$i]->{_seq} = $i+1;
	}
	
	return {
		r_args => $s->{r}->args,
		list_transaction => \@array3, #$pager2->{list},# \@array, #$pager->{list},
		#nav => $pager2->{nav},
		from => $from,
		until => $until,
		keyword => $keyword,
		rs_number => $rs_number,
		status_options => \@status_options,
		member_name => $member_name,
		admin_name => $admin_name,
		sd_name => $sd_name,
	};
}

sub new_topup {
	my ($s, $q, $db, $log) = @_;

	my ($where, @bind) = view::stock::filter_type($s);
	my $keyword_list = $s->sql_list('select stock_ref_id, keyword from stock_ref '.$where, @bind);
	my $package_list = $s->sql_list('select pkg_id, pkg_name from package');
	my $error = $q->param('error');
	return {
		list_keyword => $keyword_list,
		list_package => $package_list,
		error => $error,
	}
}

sub dep_list {
	my ($s, $q, $db, $log) = @_;
	my $from  = $q->param('from');
	my $until = $q->param('until');
	my $member_name = $q->param('member_name');
	my $trans_id = $q->param('trans_id');
	my $pager;
	if ($config::adm_gid eq $s->{adm_gid}) {
	$pager = $s->q_pager(<<"__eos__",
SELECT trans_id, member_name, amount, balance, trans_date, trans_time,
  admin_name, out_ts, username, out_msg, out_status, smsc_name
FROM deposit_web
  INNER JOIN transaction using (trans_id)
  INNER JOIN mutation using (trans_id)
  INNER JOIN member using (member_id)

  INNER JOIN admin_log using (admin_log_id)
  INNER JOIN admin on admin.admin_id=admin_log.admin_id

  INNER JOIN user using (user_id)
  LEFT JOIN sms_outbox using (out_ts, user_id)
  LEFT JOIN smsc on sms_outbox.smsc_id=smsc.smsc_id
__eos__
		# bisa diextend utk deposit approval :
		# - admin_log mengandung admin_id --> admin yg melakukan entry
		# - transaction juga ada admin_id --> yg meng approve

		filter => {
			from => "trans_date >= str_to_date(?,'%d-%m-%Y')",
			until => "trans_date <= str_to_date(?,'%d-%m-%Y')",
			member_name => "member_name =?",
			trans_id => "trans_id=?",
		},
		extra_filter => {
				"(member.member_id = ? or member.parent_id=?)" => $s->{mem_id},
			},

		suffix => 'order by admin_log_id desc',
	);
	} else {
	$pager = $s->q_pager(<<"__eos__",
SELECT trans_id, member_name, amount, balance, trans_date, trans_time,
  admin_name, out_ts, username, out_msg, out_status, smsc_name
FROM deposit_web
  INNER JOIN transaction using (trans_id)
  INNER JOIN mutation using (trans_id)
  INNER JOIN member using (member_id)

  INNER JOIN admin_log using (admin_log_id)
  INNER JOIN admin on admin.admin_id=admin_log.admin_id

  INNER JOIN user using (user_id)
  LEFT JOIN sms_outbox using (out_ts, user_id)
  LEFT JOIN smsc on sms_outbox.smsc_id=smsc.smsc_id
__eos__
		# bisa diextend utk deposit approval :
		# - admin_log mengandung admin_id --> admin yg melakukan entry
		# - transaction juga ada admin_id --> yg meng approve

		filter => {
			from => "trans_date >= str_to_date(?,'%d-%m-%Y')",
			until => "trans_date <= str_to_date(?,'%d-%m-%Y')",
			member_name => "member_name =?",
			trans_id => "trans_id=?",
			site_id => "member.site_id = ?",
		},
		suffix => 'order by admin_log_id desc',
	);

	}
	return {
		r_args => $s->{r}->args,
		from => $from, 
		until => $until,
		list => $pager->{list}, 
		nav => $pager->{nav}, 
		member_name => $member_name, 
		trans_id => $trans_id,
	}
}

sub new_deposit {
	return {}
}

sub detail {
	my ($s, $q, $db, $log) = @_;
	my $trans_id = $q->param('trans_id');
	my $approv = $q->param('approv')||0;
	my $lock = $q->param('lock')||0;
	my $admin_group = $q->param('group_id');

	my $result = $db->query(<<"EOS",
select transaction.trans_id, topup_status, rs_number, sd_name, transaction.reversal_approve,
   topup_status not in ('D', 'R') as reversible, log_msg,
   transaction.trans_date, transaction.trans_time, ifnull(log_msg,0) as no_reply,
   concat(rev.trans_date, ' ', rev.trans_time, ', by ', admin_name) as reversal,
   topup_ts, exec_ts, local_ts, topup_id,
   (date_sub(transaction.trans_date, interval 1 day) = date_sub(date(now()), interval 1 day)) as not_uniqable
from transaction 
   inner join topup using (trans_id)
   left join rs_chip using(rs_id)
   left join sd_chip using(sd_id)
   left join sd_log using (log_id)
   left join transaction as rev on rev.trans_ref=transaction.trans_id
   left join admin on admin.admin_id=rev.admin_id
where transaction.trans_id =?
EOS
		$trans_id);
	my $hash_ref = $result->hash;
	unless($hash_ref->{reversal_approve} and $hash_ref->{reversal_approve} eq 'LOCK_TOTAL'){
		if ($s->adm_gid==3) {
			if ($hash_ref->{reversal_approve} eq 'APPROVE') {
				$hash_ref->{reversal_status} = 1;
				$hash_ref->{uniq} = 0;
			} 
			if ($hash_ref->{reversal_approve} eq 'LOCK') {
				$hash_ref->{reversal_status} = 0;
				$hash_ref->{uniq} = 0;
			}
			if ($hash_ref->{reversal_approve} eq '') {
				if (($hash_ref->{reversible} eq 1) and ($hash_ref->{not_uniqable} eq 1)) {
					# status P, S. tanggal sekarang
					$hash_ref->{reversal_status} = 1;
					$hash_ref->{uniq} = 0;
				} elsif (($hash_ref->{reversible} eq 0) and ($hash_ref->{not_uniqable} eq 1)) {
					# status D, R tanggal sekarang
					$hash_ref->{reversal_status} = 0;
					$hash_ref->{uniq} = 0;
				} elsif (($hash_ref->{reversible} eq 1) and ($hash_ref->{not_uniqable} eq 0)) {
					# status P, S tanggal kemarin dst.
					$hash_ref->{reversal_status} = 0;
					$hash_ref->{uniq} = 1;
				} elsif (($hash_ref->{reversible} eq 0) and ($hash_ref->{not_uniqable} eq 0)) {
					# status D, R tanggal kemarin
					$hash_ref->{reversal_status} = 0;
					$hash_ref->{uniq} = 0;
				}
			}
		} elsif ($s->adm_gid ==2) {
			# lock dan lock reversal
			# $lock = 1 -> need lock
			# $lock = 2 -> lock_reversal
			if ($hash_ref->{reversible} eq 1) {
				if ($hash_ref->{reversal_approve} eq '') {
					$hash_ref->{locked} = 1; 
					$hash_ref->{reversal_status} = 1;
				} elsif ($hash_ref->{reversal_approve} eq 'LOCK') {
					$hash_ref->{lock_reversal} = 1;
				} elsif ($hash_ref->{reversal_approve} eq 'NEED_APPROVE') {
					$hash_ref->{need_approve} = 1;
				}
			}
			$hash_ref->{no_reply} = 0;
		} elsif($s->adm_gid == 1){
			#best admin reversal
			if($hash_ref->{reversible} and $hash_ref->{reversible} eq 1){
				#best admin status
				$hash_ref->{reversal_status} = 1;
			}
		}
	}
	$log->warn('adm_gid ',$s->adm_gid);

	my $sms = $db->query(<<"EOS",
select trans_id, topup_id, sms_id, sms_int, sms_time, sms_localtime, out_msg, out_ts, user.username
from transaction 
	inner join topup using (trans_id) 
	inner join topup_sms using(topup_id) 
	inner join sms using (sms_id) 
	inner join sms_outbox using (sms_id) 
	inner join user on user.user_id = sms.user_id 
	where trans_id = ?
EOS
	$trans_id);
	
	my $sms_result = $sms->hash;
	
	return { %$hash_ref, %$sms_result} if $sms_result;
	return $hash_ref;
}

sub topup_report {
	my ($s, $q, $db, $log) = @_;
	my $status_hidden = $q->param('status_hidden')||'S';
		$log->warn($status_hidden,' status');
	my $from = $q->param('from')||'';
	my $until = $q->param('until')||'';
	my $keyword = $q->param('keyword')||'';
	my $rs_number = $q->param('rs_number')||'';
	my $member_name = $q->param('member_name')||'';
	$log->warn($member_name, ' member name');
	my $admin_name = $q->param('admin_name')||'';
	my $sd_name = $q->param('sd_name')||'';
	my $site_id = $q->param('site_id')||'';
	
	my $result;# = $s->q_pager($query,
	my $query;
	if ($config::adm_gid eq $s->{adm_gid}) {
		if ($s->{adm_gid} == 1) {
		$query = "select keyword, sum(topup_qty) as keyword_sukses, sum(amount) as keyword_amount from transaction inner join mutation using(trans_id) left join topup using(trans_id) inner join stock_ref using(stock_ref_id) inner join rs_chip using(rs_id) left join sd_chip using(sd_id) inner join member on mutation.member_id = member.member_id left join admin on transaction.admin_id=admin.admin_id";
		} else {
		$query = "select keyword, sum(topup_qty) as keyword_sukses from transaction inner join mutation using(trans_id) left join topup using(trans_id) inner join stock_ref using(stock_ref_id) inner join rs_chip using(rs_id) left join sd_chip using(sd_id) inner join member on mutation.member_id = member.member_id left join admin on transaction.admin_id=admin.admin_id";
		}

		$result = $s->q_pager($query,
			filter => {
				status_hidden => 'topup.topup_status=?',
				from => "transaction.trans_date >= str_to_date(?,'%d-%m-%Y')",
				until => "transaction.trans_date <= str_to_date(?,'%d-%m-%Y')",
				keyword => "stock_ref.keyword like concat('%',?,'%')",
				rs_number => "rs_chip.rs_number = ?",
				member_name => "member.member_name like concat('%',?,'%')",
				admin_name => "admin.admin_name like concat('%',?,'%')",
				sd_name => "sd_chip.sd_name like concat('%',?,'%')",
			},
			suffix => 'group by stock_ref_id',
			extra_filter => {
				'sd_chip.ref_type_id=?' => $s->{ref_type_id},
				'stock_ref.ref_type_id=?' => 1,
			},
		);

	} else {
	    if($config::topup_report_for_suryalaya){
		$query = "select member_name, sd_name, keyword, sum(topup_qty) as keyword_sukses, sum(amount) as keyword_amount
from transaction
inner join mutation using(trans_id)
left join topup using(trans_id)
inner join stock_ref using(stock_ref_id)
inner join rs_chip using(rs_id)
left join sd_chip using(sd_id)
inner join member on mutation.member_id = member.member_id
left join admin on transaction.admin_id=admin.admin_id";

		$result = $s->q_pager($query,
			filter => {
				status_hidden => 'topup.topup_status in (?)',
				from => "transaction.trans_date >= str_to_date(?,'%d-%m-%Y')",
				until => "transaction.trans_date <= str_to_date(?,'%d-%m-%Y')",
				keyword => "stock_ref.keyword like concat('%',?,'%')",
				rs_number => "rs_chip.rs_number = ?",
				member_name => "member.member_name like concat('%',?,'%')",
				admin_name => "admin.admin_name like concat('%',?,'%')",
				sd_name => "sd_chip.sd_name like concat('%',?,'%')",
			},
			suffix => 'group by member.member_id,sd_chip.sd_id,stock_ref_id order by member.member_id,sd_chip.sd_id,stock_ref_id asc',
			extra_filter => {'sd_chip.ref_type_id=?' => $s->{ref_type_id},
					"sd_chip.site_id=?" => $s->{site_id},
			},
		);
	    }else{
		if ($s->{adm_gid} == 1) {
			$query = "select keyword, sum(topup_qty) as keyword_sukses, sum(-amount) as keyword_amount from transaction inner join mutation using(trans_id) left join topup using(trans_id) inner join stock_ref using(stock_ref_id) inner join rs_chip using(rs_id) left join sd_chip using(sd_id) inner join member on mutation.member_id = member.member_id left join admin on transaction.admin_id=admin.admin_id";
		} else {
			$query = "select keyword, sum(topup_qty) as keyword_sukses from transaction inner join mutation using(trans_id) left join topup using(trans_id) inner join stock_ref using(stock_ref_id) inner join rs_chip using(rs_id) left join sd_chip using(sd_id) inner join member on mutation.member_id = member.member_id left join admin on transaction.admin_id=admin.admin_id";
		}

		$result = $s->q_pager($query,
			filter => {
				status_hidden => 'topup.topup_status=?',
				from => "transaction.trans_date >= str_to_date(?,'%d-%m-%Y')",
				until => "transaction.trans_date <= str_to_date(?,'%d-%m-%Y')",
				keyword => "stock_ref.keyword like concat('%',?,'%')",
				rs_number => "rs_chip.rs_number = ?",
				member_name => "member.member_name = ?",
				admin_name => "admin.admin_name like concat('%',?,'%')",
				sd_name => "sd_chip.sd_name like concat('%',?,'%')",
				site_id => "sd_chip.site_id = ?",
			},
			suffix => 'group by stock_ref_id',
			extra_filter => {'sd_chip.ref_type_id=?' => $s->{ref_type_id}},
		);
	    }
	}

	my @array;
	my $total = 0;
	foreach (@{$result->{list}}) {
		$_->{keyword_amount} = 0 unless $_->{keyword_amount};
		$_->{keyword_amount} =~ s/\.\d+$//;
		my $amount = $_->{keyword_amount}||'0';
		$total = $total + $amount;
		$_->{keyword_amount} =~ s/\d{1,3}(?=(\d{3})+(?!\d))/$&,/g;
		$_->{keyword_sukses} =~ s/\d{1,3}(?=(\d{3})+(?!\d))/$&,/g;
	}
	$total =~ s/\d{1,3}(?=(\d{3})+(?!\d))/$&,/g;
	my $site_name = 'ALL';
	$site_name = $db->query("select site_name from site where site_id = ?", $s->{site_id})->list if $s->{site_id};
	$site_name = $db->query("select site_name from site where site_id = ?", $site_id)->list if $site_id;
	return {
		r_args => $s->{r}->args,
		list_report => $result->{list},
		nav => $result->{nav},
		total => $total,
		from => $from,
		until => $until,
		keyword => $keyword,
		rs_number => $rs_number,
		member_name => $member_name,
		admin_name => $admin_name,
		site_name => $site_name,
	}
}

sub new_transfer{
	return{}
}

1;

