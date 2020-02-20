package daemon;
use strict;
use warnings;

use config;

use DBIx::Simple ();
use SQL::Abstract ();
use POSIX ();

sub db_connect {
	my $db = DBIx::Simple->connect(@config::db_conn, {RaiseError => 1, AutoCommit => 1});
	$db->abstract = SQL::Abstract->new();
	return $db;
}

sub warn {
	my (@list) = @_;
	print STDERR "[", POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime()), "] ", @list;
}


1;

