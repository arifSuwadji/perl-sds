package misc;
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


sub handler {
	my $r = shift;
	
	my $q = Apache2::Request->new($r);
	my $db = DBIx::Simple->connect('DBI:mysql:sds;host=localhost', 'root', '', {RaiseError => 1, AutoCommit => 1});
	$db->abstract = SQL::Abstract->new();
	# session
	my $s = session->new($r, $q, $db);
	unless ($s->{adm_id}) {
		$r->print('<script languange="javascript">history.back()</script>');
		return Apache2::Const::OK;
	}

	############## WE ARE iN A VALID SESSION ########################

	# subref: \&misc::transaction::list;
	my ($subref) = ($r->uri =~ /^\/([\w\W]+)\.(xls|pdf)/);  # /misc/transaction/list
	$subref =~ s/\//::/g;  # misc::transaction::list
	my $log = $s->log();
	$log->warn("subref after substitution: ", $subref);

	# package
	my ($package) = ($subref =~ /([\w:]+)::\w+$/);
	$log->warn("package: ", $package);

	eval "require $package";
	$subref = eval '\&'.$subref;
	#$log->warn("subref is now a code ref");

	my $ret = eval{ &$subref($s) };
        if ($@) {
		$log->warn($@);
		return Apache2::Const::SERVER_ERROR;
	}
	$r->content_type($ret->[1]||'text/plain');
        $r->print($ret->[0]||'');
        return Apache2::Const::OK;
}

1;

