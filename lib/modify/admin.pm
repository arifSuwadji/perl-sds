package modify::admin;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use Digest::MD5 'md5_hex';

sub add_admin {
	my ($s,$q,$db,$log) = @_;
	my $admin_name = $q->param('admin_name')||'';
	my $admin_password1 = $q->param('admin_password1')||'';
	my $admin_password2 = $q->param('admin_password2')||'';
	my $adm_gid = $q->param('adm_gid')||'';
	my $member_id = $q->param('member_id');
	my $member_name = $q->param('member_name');
	my $admin_site = $q->param('admin_site') || undef;
	my $ref_type_id = $q->param('ref_type_id') || undef;
	$log->warn("admin site : ", $admin_site || '' );
	if ($admin_password1 eq $admin_password2) {
		my ($admin_id) = $db->query('select admin_id from admin where admin_name=?', $admin_name)->list;
		$db->insert('admin', { 	admin_name => $admin_name,
				       	admin_password=> md5_hex($admin_password1),
				       	adm_gid => $adm_gid,
				       	member_id=> $member_id,
					site_id => $admin_site,
					ref_type_id => $ref_type_id,
				      }) unless $admin_id;
	}
	return "/view/admin/list?member_id=$member_id&member_name=$member_name";
}

sub edit_admin {
	my ($s, $q, $db, $log) = @_;
	my $admin_name = $q->param('admin_name')||'';
	my $member_id = $q->param('member_id');
	my $admin_id = $q->param('admin_id');
	my $member_name = $q->param('member_name');
	my $adm_gid = $q->param('adm_gid');
	my $site_id = $q->param('site_id') || undef;
	my $ref_type_id = $q->param('ref_type_id') || undef;
	
	$db->query('update admin set admin_name=?,adm_gid=?,site_id=?, ref_type_id=? where admin_id=?',$admin_name,$adm_gid,$site_id,$ref_type_id,$admin_id);
	
	return "/view/admin/list?member_id=$member_id&member_name=$member_name";
}

sub delete {
	my ($s, $q, $db, $log) = @_;
	my $admin_id = $q->param('id');
	my $member_id = $q->param('member_id');
	my $member_name = $q->param('member_name');
	$s->query('delete from admin where admin_id=?',$admin_id);
	return "/view/admin/list?member_id=$member_id&member_name=$member_name";
}

sub edit_admin_page{
	my ($s, $q, $db, $log) = @_;
	my $group_id = $q->param('group_id');
	my $group_name = $q->param('group_name');
	my @page_id = $q->param('page_id');
	$log->warn("group_id ", $group_id || "kosong", " group_name ", $group_name || "kososng");
	$log->warn("page_id ", join('_',@page_id));
	
	$db->query("delete from page_map where adm_gid=?",$group_id);
	foreach(@page_id){
		$db->query("insert into page_map values(?,?)", $group_id,$_);
	}
	return "/view/admin/edit_admin_page?group_id=$group_id&group_name=$group_name";
}
	
sub edit_password {
	my ($s, $q, $db, $log) = @_;
	my $member_id = $q->param('member_id');
	my $member_name = $q->param('member_name');
	my $admin_id = $q->param('admin_id');
	my $admin_password1 = $q->param('admin_password1')||'';
	my $admin_password2 = $q->param('admin_password2')||'';
	if($admin_password1 eq $admin_password2) {
		my $md5= md5_hex($admin_password1);
		$log->warn($md5);
		$db->query('update admin set admin_password=? where admin_id=?',$md5, $admin_id);
	}
	
	return "/view/admin/list?member_id=$member_id&member_name=$member_name";
}

1;
