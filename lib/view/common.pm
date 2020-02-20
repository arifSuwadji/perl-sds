package view::common;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use POSIX ();
use CGI::Enurl;


sub footer {
	my ($s, $q, $db, $log) = @_;

	return {};
}

sub header {
	my ($s, $q, $db, $log) = @_;

		my $count = $db->query("select count(*) from sd_stock where qty_tmp <> 0")->list;
		my $adm_gid_5 = $s->{adm_gid} == 5 ;
		my $date = POSIX::strftime('%d-%m-%Y', CORE::localtime);
		$date =~ s/^\d+/01/;

	return {
		username => $s->{username},
		url => enurl($s->{r}->unparsed_uri),
		now => POSIX::strftime('%b %d, %Y %H:%M:%S', CORE::localtime),
		fymd => $date,
		ymd => POSIX::strftime('%d-%m-%Y', CORE::localtime),
		_url => enurl($s->{r}->unparsed_uri),
		stock_ref_type => $s->{ref_type_id},
		count => $count,
		adm_gid_5 => $adm_gid_5,
	};
};

sub site {
	my ($s, $q, $db, $log) = @_;

	my @site_options;
	my $result2 = $db->query('select site_id, site_name from site');
	while (my ($site_id, $site_name) = $result2->list) {
		push @site_options, {value=>$site_id, display=>$site_name};
	}
	$_->{selected} = $_->{value} eq ($q->param('site_id')||'') ? 1:0 foreach @site_options;

	return {site_options => \@site_options}
}

sub rs_type {
	my ($s, $q, $db, $log) = @_;

	my @rs_type_options;
	my $result = $db->query('select rs_type_id, type_name from rs_type');
	while (my ($rs_type_id, $type_name) = $result->list) {
		push @rs_type_options, {value=>$rs_type_id, display=>$type_name};
	}
	$_->{selected} = $_->{value} eq ($q->param('rs_type_id')||'') ? 1:0 foreach @rs_type_options;

	return {rs_type_options => \@rs_type_options}
}

sub outlet {
	my ($s, $q, $db, $log) = @_;

	my @outlet_options;
	my $result3 = $db->query('select outlet_id, outlet_name from outlet');
	while (my ($outlet_id, $outlet_name) = $result3->list) {
		push @outlet_options, {value=>$outlet_id, display=>$outlet_name};
	}
	$_->{selected} = $_->{value} eq ($q->param('outlet_id')||'') ? 1:0 foreach @outlet_options;


	return {outlet_options => \@outlet_options}
}


1;

