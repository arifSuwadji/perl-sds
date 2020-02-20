package view;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use POSIX ();
use CGI::Enurl;
use DBIx::Simple ();
use SQL::Abstract ();
use HTML::Template ();

use session ();

use Apache2::Request ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(:common);

my $base_name = 'sds';

sub block {
	# block : blok barat, blok timur, blok A1, blok D5...
	my ($s, $path, $depth) = @_;
	$depth ||= 0;
	return (Apache2::Const::FORBIDDEN) if $depth > 10;

	my $r   = $s->{r};
	my $log = $s->log();

	$log->warn(" "x$depth, "view path: ", $path);
	my $subref = 'view/'.$path;  # /view/voucher/list
	$subref =~ s/\//::/g;  # view::voucher::list
	$log->warn(" "x$depth, "subref after substitution: ", $subref);

	# package
	my ($package) = ($subref =~ /([\w:]+)::\w+$/);
	$log->warn(" "x$depth, "package: ", $package);

	eval "require $package";
	if ($@) {
		$log->warn(" "x$depth, $@);
		return (Apache2::Const::NOT_FOUND);
	}

	$subref = eval '\&'.$subref;
	#$log->warn("subref is now a code ref");

	my $ret = eval{ &$subref($s, $s->q, $s->db, $log) };
	# utk bb: eval{ &$subref($s, $r, $q, $db, $log) };
	#$log->warn("code ref executed");

	if ($@) {
		# an error occured, or there are some errors
		$log->warn(" "x$depth, $@);
		return (Apache2::Const::SERVER_ERROR);
	}

	my $ref = ref $ret;
	unless ($ref and $ref eq 'HASH') {
		$log->warn("the sub for ", $r->uri, " doesn't return a hashref");
		return (Apache2::Const::SERVER_ERROR);
	}
	unless ($s->adm_gid == 1) {
		if( $path eq 'stock/approve_price') {
			$path = 'stock/kosong';
		}
	}
	# unless ($s->adm_gid == 2) {
	if ($path eq 'stock/edit_for_approve') {
		if ($s->adm_gid == 3) {	
			$path = 'stock/kosong';
		}
	}
	#}

	my $tpl = eval{ HTML::Template->new(
		filename => "/home/software/$base_name/tpl/$path.html",
		die_on_bad_params => 0,
		loop_context_vars => 1,
	)};
	if ($@) {
		$log->warn($@);
		return (Apache2::Const::NOT_FOUND);
	}
	$ret->{_ymd} = common::today();
	
	$tpl->param(%$ret);

	# scan tmpl_var INCL:/...
	my @list = $tpl->query();
	foreach (@list) {
		my $type = $tpl->query(name => $_);
		next if $type ne 'VAR' or $_ !~ /^incl:/;
		$log->warn(" "x$depth, "VARS: ", $_, ", type: ", $type);
		my $path = $_; $path =~ s/^incl:\/*//;
		my ($code, $content) = block($s, $path, $depth+1);
		$tpl->param($_ => $content);
	}

	# for LATER optmization, $tpl->output can be replaced by its reference
	return (Apache2::Const::OK, $tpl->output);
}

sub handler {
	my $r = shift;

	unless($r->uri =~ /\/view\/([\w\W]+)/){
		return "/view/admin/list";
	}

	my $q = Apache2::Request->new($r);
	#my $db = DBIx::Simple->connect("DBI:mysql:$base_name;host=localhost", 'root', '', {RaiseError => 1, AutoCommit => 1});
	my $db = DBIx::Simple->connect("DBI:mysql:sds_alintas;host=localhost", 'root', '', {RaiseError => 1, AutoCommit => 1});
	$db->abstract = SQL::Abstract->new();

	# session
	my $s = session->new($r, $q, $db);
	unless ($s->{adm_id}) {
		my $tpl = HTML::Template->new(
		    filename => "/home/software/$base_name/tpl/login.html",
		    die_on_bad_params => 0,
		);
		
		my $param = {url=>$r->unparsed_uri};
		if ($r->unparsed_uri =~ m/(transaction\/list)$/ || $r->unparsed_uri =~ m/(transaction\/dep_list)$/ || $r->unparsed_uri =~ m/(sms\/list)$/ || $r->unparsed_uri =~ m/(transaction\/double_list)$/ ||$r->unparsed_uri =~ m/(transaction\/lock_totalan)$/) {
			#$r->print('OK');
			#return Apache2::Const::OK;
			$param->{url} = $r->unparsed_uri.'?from='.common::today().'&until='.common::today();
		} elsif ($r->unparsed_uri=~ m/(from=&until=)$/) {
			my ($url) = $param->{url} =~ /(^[\w\W]+)from=&until=/;
			$param->{url} = $url.'from='.common::today().'&until='.common::today(); 
		}
		$tpl->param(%$param);
		
		$r->print($tpl->output);
		return Apache2::Const::OK;
	}

	############## WE ARE iN A VALID SESSION ########################
	# ACM temporarily inactive
	return Apache2::Const::NOT_FOUND unless $s->{pg_id};
	return Apache2::Const::FORBIDDEN unless $s->{allowed};

	#################### MAKE ADMIN LOG ########################
	my ($t, $args) = split /\?/, $r->unparsed_uri;
	#my $ip = $db->query("select inet_aton(?)",$r->connection->remote_ip)->list;
	my $ip = $db->query("select inet_aton(?)",'127.0.0.1')->list;
	$db->insert('admin_log',{
		admin_id     => $s->{adm_id},
		page_id      => $s->{pg_id},
		admin_log_ts => \'NOW()',
		args         => $args,
		ip           => $ip,
	});

	# subref: \&web::product::list;
	my ($path) = ($r->uri =~ /\/view\/([\w\W]+)/);
	my ($code, $content) = block($s, $path);
	$r->print($content) if $content;
	return $code;
}


1;

