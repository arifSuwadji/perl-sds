package view::smsc;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub list {
	my ($s,$q,$db,$log) = @_;
	my $site_id = $q->param('site_id');
	my $status = $q->param('status');
	my $list = $s->sql_list('select smsc_id, smsc_name, smsc_type, smsc_status, site_id, site_name from smsc inner join site using(site_id)');
	if($site_id and $status){
		$list = $s->sql_list('select smsc_id, smsc_name, smsc_type, smsc_status, site_id, site_name
					from smsc inner join site using(site_id) where site_id=? and smsc_status=?', $site_id, $status);
	}elsif($site_id){
		$list = $s->sql_list('select smsc_id, smsc_name, smsc_type, smsc_status, site_id, site_name
					from smsc inner join site using(site_id) where site_id=?', $site_id);
	}elsif($status){
		$list = $s->sql_list('select smsc_id, smsc_name, smsc_type, smsc_status, site_id, site_name
					from smsc inner join site using(site_id) where smsc_status=?', $status);
	}
	return {
		list_smsc     => $list,
		status        => $status,
	};
}

sub add_smsc {
	my ($s,$q,$db,$log) = @_;
	return {
		site_option => $s->sql_list('select site_id, site_name from site'),
	};
}

sub edit_smsc {
	my ($s,$q,$db,$log) = @_;
	my $smsc_id = $q->param('id');
	my ($smsc_name, $site_id, $site_name) = $db->query('select smsc_name, site_id, site_name from smsc inner join site using(site_id) where smsc_id=?', $smsc_id)->list;
	return {
		smsc_name => $smsc_name, 
		smsc_id => $smsc_id,
		site_id => $site_id,
		site_name => $site_name,
		site_option => $s->sql_list('select site_id, site_name from site'),
	};
}

1;

