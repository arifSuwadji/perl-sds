package view::admin;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub list {
	my ($s,$q,$db,$log) = @_;
	my $member_id = $q->param('member_id');
	my $list = $s->sql_list('select admin.member_id as member_id, member.member_name as member_name, admin_id, admin_name, adm_gid,adm_group_name, ref_type_name, admin.site_id,site.site_name 
				from admin 
				left join admin_group using(adm_gid) 
				left join member using (member_id) 
				left join site site on site.site_id = admin.site_id 
				left join stock_ref_type using(ref_type_id)
				where admin.member_id=?', $member_id);
	return {
		list_admin => $list,
		member_id => $member_id,
		member_name=> $q->param('member_name'),
	};
}

sub add_admin {
	my ($s, $q, $db, $log) = @_;
	return {
		list_group => $s->sql_list('select adm_gid, adm_group_name from admin_group where adm_gid >= ?', $s->adm_gid),
		member_id => $q->param('member_id'),
		member_name => $q->param('member_name'),
		list_site => $s->sql_list('select site_id,site_name,site_url from site order by site_id'),
		list_admin_stock => $s->sql_list('select ref_type_id,ref_type_name from stock_ref_type order by ref_type_id'),
	};
}

sub edit_admin {
	my ($s,$q,$db,$log) = @_;
	my $admin_id = $q->param('id');
	my ($admin_name,$adm_gid,$site_id,$ref_type_id) = $db->query('select admin_name,adm_gid,site_id,ref_type_id from admin where admin_id=?', $admin_id)->list;
	return {
		admin_name => $admin_name, 
		id => $admin_id,
		member_id => $q->param('member_id'),
		member_name => $q->param('member_name'),
		list_group_option => $s->sql_list("select adm_gid, $adm_gid=adm_gid as selected, adm_group_name from admin_group where adm_gid >= ?", $s->adm_gid),
		list_site_name => $s->sql_list("select site_id, site_name, site_id=? as selected from site", $site_id),
		list_admin_stock => $s->sql_list("select ref_type_id, ref_type_name, ref_type_id=? as selected from stock_ref_type", $ref_type_id),
	};
}

sub edit_admin_page {
	my ($s,$q,$db,$log) = @_;
	my $group_id = $q->param('group_id');
	my $group_name = $q->param('group_name');
	my %page;
	foreach(qw/transaction topup member rs_chip admin outlet stock sms smsc sms_rs aktivasi invoice setting/){
		$page{$_} = $s->sql_list(<<'EOS',
		select page.page_id,path,adm_gid as checked from page
		left join page_map as map on map.page_id = page.page_id and map.adm_gid=?
		where path like concat('%/',?,'/%')
EOS
		$group_id,$_,
		);
	}

	return{
		group_id => $group_id,
		group_name => $group_name,
		%page,
	};
}

sub edit_password {
	my ($s,$q,$db,$log) = @_;
	my $admin_id = $q->param('id');
	my ($admin_name,$adm_gid,$site_id) = $db->query('select admin_name,adm_gid,site_id from admin where admin_id=?', $admin_id)->list;
	my $session_id ;
	my $explain;
	if($s->adm_gid == 1){$session_id = 1}elsif($s->adm_id == $admin_id){$session_id = 1}else{$explain = "Can't Access!!! You can change your password"};
	return {
		admin_name => $admin_name, 
		id => $admin_id,
		session_id => $session_id,
		member_id => $q->param('member_id'),
		member_name => $q->param('member_name'),
		explain => $explain,
	};
}

1;

