package modify;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use DBIx::Simple ();
use SQL::Abstract ();

use session ();

use Apache2::Const -compile => qw(:common);
use Apache2::Request ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Upload ();

sub handler {
	my $r = shift;

	my $q   = Apache2::Request->new($r);
	my $db  = DBIx::Simple->connect('DBI:mysql:sds_alintas;host=localhost', 'root', '', {RaiseError => 1, AutoCommit => 1});
	my $s   = session->new($r, $q, $db);
	my $log = $s->log();

	#$log->warn("uri: ", $r->uri);
	if ($r->uri eq '/modify/login') {
		$s->login();
		$r->headers_out->add('Location' => $q->param('url'));
		return Apache2::Const::REDIRECT;
	}

	unless ($s->{adm_id}) {
		$log->warn("adm id tidak ditemukan");
		$r->print('<script language="javascript">history.back()</script>');
		return Apache2::Const::OK;
	}

	if ($r->uri eq '/modify/logout') {
		$db->query("update admin set session_id=NULL where admin_id=?", $s->{adm_id});
                $r->headers_out->add('Location' => $q->param('url'));
		return Apache2::Const::REDIRECT;
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
	$s->{adm_log_id} = $db->last_insert_id(0,0,0,0);

	# subref: \&web::product::list;
	my ($subref) = ($r->uri =~ /^\/([\w\W]+)/);  # /pos/modify/voucher/list
	$subref =~ s/\//::/g;  # pos::modify::voucher::list
	#$log->warn("subref after substitution: ", $subref);

	# package
	my ($package) = ($subref =~ /([\w:]+)::\w+$/);
	#$log->warn("package: ", $package);

	eval "require $package";
	if ($@) {
		$log->warn($@);
		return Apache2::Const::NOT_FOUND;
	}
	$subref = eval '\&'.$subref;
	#$log->warn("subref is now a code ref");

	my $ret = eval{ &$subref($s, $q, $db, $log) };
	# utk bb: eval{ &$subref($s, $r, $q, $db, $log) };
	#$log->warn("code ref executed");

	if ($@) {
		# an error occured, or there are some errors
		$log->warn($@);
		return Apache2::Const::SERVER_ERROR;
	}

	unless ($ret and $ret =~ /^\//) {
		$log->warn("the sub for ", $r->uri, " doesn't return an uri");
		return Apache2::Const::SERVER_ERROR;
	}

	$r->headers_out->add('Location' => $ret);
	return Apache2::Const::REDIRECT;
}


1;

