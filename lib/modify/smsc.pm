package modify::smsc;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub add_smsc {
	my ($s,$q,$db,$log) = @_;
	my $smsc_name = $q->param('smsc_name')||'';
	my $site_id = $q->param('site_id');
	$db->insert('smsc', { smsc_name => $smsc_name, site_id => $site_id,
			      });
	return '/view/smsc/list';
}

sub edit_smsc {
	my ($s, $q, $db, $log) = @_;
	my $smsc_name = $q->param('smsc_name')||'';
	my $smsc_id = $q->param('smsc_id');
	my $site_id = $q->param('site_id');
	$db->query('update smsc set smsc_name=?,site_id=? where smsc_id=?',$smsc_name,$site_id, $smsc_id);
	return '/view/smsc/list';
}

sub delete {
	my ($s, $q, $db, $log) = @_;
	my $smsc_id = $q->param('id');
	$s->query('delete from smsc where smsc_id=?',$smsc_id);
	return '/view/smsc/list';
}

sub change_status {
	my ($s, $q, $db, $log) = @_;
	my $smsc_id = $q->param('smsc_id');
	my $smsc_status = $q->param('smsc_status');
	my $site_id = $q->param('site_id');
	my $status = 'non-active' if $smsc_status eq 'active';
	$status = 'active' if $smsc_status eq 'non-active';
	$db->query('update smsc set smsc_status=? where smsc_id=?', $status, $smsc_id);
	return "/view/smsc/list?site_id=$site_id";
}

sub change_type {
	my ($s, $q, $db, $log) = @_;
	my $smsc_id = $q->param('smsc_id');
	my $smsc_type = $q->param('smsc_type');
	my $site_id = $q->param('site_id');
	my $type = 'center' if $smsc_type  eq 'sender';
	$type = 'sender' if $smsc_type eq 'center';
	$db->query('UPDATE smsc SET smsc_type=? WHERE smsc_id=?', $type, $smsc_id);
	return "/view/smsc/list?site_id=$site_id";
}
	
1;
