package view::member;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use config;

sub list {
	my ($s,$q,$db,$log) = @_;
	
	my $from = $q->param('from');
	my $until = $q->param('until');
	my $status = $q->param('status');
	my $type = $q->param('type');
	my $name = $q->param('member_name');
	my $id = $q->param('member_id');
	my $upline = $q->param('upline_name');
	my $username = $q->param('username');
	my $opt = "order by dt_id separator '<hr style=\"border-style:none none dotted;height:1px;padding:2px;margin:4px\">'";
	my $opt1 = "order by ref_type_id separator '<hr style=\"border-style:none none dotted;height:1px;padding:2px;margin:4px\">'";
	my $opt2 = "order by member.member_id separator '<hr style=\"border-style:none none dotted;height:1px;padding:2px;margin:4px\">'";

	my $pager;
	if ($config::adm_gid eq $s->{adm_gid}) {
	$pager = $s->q_pager(<<"EOS",
		select group_concat(ref_type_name $opt1) as rt_name, group_concat(qty_target $opt) as qty_target, member.member_type,		     format(member.member_target,2) as member_target, target_qty, upline.member_name as mname,  member.member_id, 
		member.member_name as name, 
		format(member.member_balance,2) as balance, site_name, member.status from member 
		left join dompul_target using (member_id)
		left join stock_ref_type using (ref_type_id)
		left join site using(site_id) 
		left join member upline on upline.member_id = member.parent_id
EOS
		filter => {
			status => "member.status = ? ",		
			type   => "member.member_type = ? ",
			member_name => "member.member_name = ? ",	
			upline_name => "upline.member_name = ? ",	
			member_id => "member.member_id = ? ",	
			site_id => "site.site_id = ?",
		},
		extra_filter => {
			"member.parent_id = ?" => $s->{mem_id},	
		},
		suffix => 'group by member.member_id'
	);
	} else {
	$pager = $s->q_pager(<<"EOS",
		select group_concat(username $opt2) as username, member.member_type, format(member.member_target,2) as member_target, member.target_qty, upline.member_name as mname,  member.member_id, 
		member.member_name as name, format(member.member_balance,2) as balance, site_name, member.status, date_format(curdate(),'%d-%m-%Y') as detail_date
		from member left join site using(site_id) 
		left join member upline on upline.member_id = member.parent_id
		left join user on user.member_id = member.member_id
EOS
		filter => {
			status => "member.status = ? ",		
			type   => "member.member_type = ? ",
			member_name => "member.member_name = ? ",	
			upline_name => "upline.member_name = ? ",	
			member_id => "member.member_id = ? ",	
			site_id => "site.site_id = ?",
			username => "user.username = ?",
			},
			extra_filter => {"member.site_id=?" => $s->{site_id}},
		suffix => 'group by member.member_id'
		);
	}

	return {
		list_member => $pager->{list},
		nav => $pager->{nav},
		from         => $from,
		until        => $until,
		status       => $status,
		mtype	     => $type,
		member_name  => $name,
		member_id    => $id,
		upline_name  => $upline,
		username     => $username,
	};
}

sub additional_data {
	my ($s,$q,$db,$log) = @_;
	
	my $from = $q->param('from');
	my $until = $q->param('until');
	my $status = $q->param('status') || '';
	my $list = $s->sql_list("select member.member_target, upline.member_name as mname,  member.member_id, member.member_name as name, format(member.member_balance,2) as balance, site_name, member.status from member left join site using(site_id) left join member upline on upline.member_id = member.parent_id where member.status like '$status%'");
	foreach (@$list) {
		$_->{from} = $q->param('from');
		$_->{until} = $q->param('until');
	}
	return {
		list_member => $list,
		from        => $from,
		until       => $until,
		status      => $status,
	};
}


sub add_member {
	my ($s,$q,$db,$log) = @_;
	return {
		list_site => $s->sql_list('select site_id, site_name from site'),
	};
}

sub edit_member {
	my ($s,$q,$db,$log) = @_;
        my $member_id = $q->param('id');
        my $ref_type_name = $s->sql_list("select ref_type_id, ref_type_name from stock_ref_type where ref_type_id > 11 and ref_type_name like 'Dompul%' group by ref_type_id");
		my ($target, $member_name, $member_balance, $site_id, $status, $mname, $type) = $db->query('select member.member_target as target, member.member_name, member.member_balance, member.site_id, member.status, upline.member_name as mname, member.member_type as member_type from member left join member upline on upline.member_id = member.parent_id where member.member_id=?', $member_id)->list;
        my $site_options = $s->sql_list('select site_id, ?=site_id as selected, site_name from site', $site_id);
	return {
                member_name => $member_name,
				mname => $mname,
				target => $target,
                member_balance => $member_balance,
                site_options => $site_options,
                id => $member_id,
				ref_type_name => $ref_type_name,
				cvs => $type eq 'CVS', spv => $type eq 'SPV', bm => $type eq 'BM',
	};
}

sub edit_dompul_name {
	my ($s, $q, $db, $log) = @_;
    my $id = $q->param('id');
    my $m_id = $q->param('member_id');
    my $ref_type_name = $s->sql_list("select ref_type_id, ref_type_name from stock_ref_type where ref_type_id=?",$id);
	
	return {
	id => $id,
	m_id => $m_id,
	rt_name => $ref_type_name,
	};
}

sub detail_member {
	my ($s, $q, $db, $log) = @_;
	my $member_id = $q->param('id');
	my $rs_number = $q->param('rs_number');
	my $outlet_name = $q->param('outlet_name');
	my $member_name = $q->param('member_name');
	my $member_type = $q->param('type') || '';
	my $detail = $s->sql_list('select user_id, username, pin, status from user where member_id=?',$member_id);
	my @array1 = @$detail;
	foreach (@array1) {
		$_->{member_id} = $member_id;
		$_->{member_name} = $member_name;
	}
	my $list = $s->q_pager(<<"EOS",
select rs_id, rs_number, outlet_id, outlet_name,type_name
from rs_chip
  inner join sd_chip using (sd_id)
  left join rs_type using(rs_type_id)
  inner join outlet using(outlet_id)
EOS
		filter => {
			id => 'member_id = ?',
			rs_number => "rs_number =?",
			outlet_name => "outlet_name =?",
		},
		extra_filter => {
			'ref_type_id = ?' => $s->{ref_type_id},
		},
	);

	return {
		list_user => $detail,
		list_rs_chip=> $list->{list},
		nav => $list->{nav},
		rs_number => $rs_number,
		outlet_name => $outlet_name,
		member_name => $member_name,
		member_id => $member_id,
		member_type => $member_type,
		bm => $member_type eq "BM",
		type_options=>$s->sql_list('select rs_type_id, type_name from rs_type'),
		# rs_chip_options => $s->sql_list('select rs_id, rs_number from rs_chip where member_id is null'),
	};
}

sub mutation {
        my($s, $q, $db, $log) = @_;
        my $member_id = $s->param('id');
        my $from = $s->param('from');
        my $until = $s->param('until');
        my ($member_name, $balance) = $db->query('select member_name, format(member_balance,2) member_balance from member where member_id=?', $member_id)->list;
      my $pager = $s->q_pager(<<"EOS",
select trans_date, trans_time, trans_id, 
  if(amount<0, format(-amount,2), null) as debet, 
  if(amount>0, format(amount, 2), null) as kredit,
  format(balance,2) as balance, trans_type
from mutation 
  inner join transaction using (trans_id) 
EOS
		filter => {
			from => "trans_date >= str_to_date(?,'%d-%m-%Y')",
			until => "trans_date <= str_to_date(?,'%d-%m-%Y')",
			id => "mutation.member_id = ?",
		},
		suffix => 'order by trans_id desc',
         );
         return {
         	mutation => $pager->{list},
                nav => $pager->{nav},
                r_args => $s->{r}->args,
		from => $from,
		until => $until,
		balance => $balance,
               	member_name => $member_name,
		member_id => $member_id,
         }
}

sub set_target_period {
	my($s, $q, $db, $log) = @_;
	my $from = $q->param('from');
	my $until = $q->param('until');

	return {
		from => $from,
		until => $until,
		last_target => $s->sql_list("select date_format(from_date, '%d-%m-%Y') as from_date, date_format(until_date, '%d-%m-%Y') as until_date from target_period where period_status='open'"),
	}	
}

sub detail_target {
    my($s, $q, $db, $log) = @_;
    my $name = $q->param('member_name');
    my $id = $q->param('member_id');

      my $pager = $s->q_pager(<<"EOS",
    select member_id, member_name, outlet_id, outlet_name, day, qty_target, nominal_target from dompul_target inner join member using (member_id) inner join outlet using (outlet_id)
EOS
        filter => {
            member_id => 'member_id=?',
        }
    );
    return {
        list => $pager->{list},
        nav => $pager->{nav},
        id => $id,
		name => $name,
    }
}
sub additional_list {
    my($s, $q, $db, $log) = @_;
    my $id = $q->param('member_id');
    my $error = $q->param('error');
    my $detail = $s->sql_list('select member_id, member_name, add_user_id, username, pin, additional_user.status from additional_user inner join member using (member_id) where member_id=?',$id);
    my $name = $s->query('select member_name from member where member_id=?',$id)->list;
    return {
        list => $detail, membername => $name, id => $id, error => $error,
    }
}

1;

