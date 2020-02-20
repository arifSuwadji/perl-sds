#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use config;
use daemon;

my $db = daemon::db_connect();

$db->begin();
eval {
	$db->query("UPDATE outlet SET balance_nominal=0, balance_qty=0");
	$db->query("UPDATE rs_chip SET rs_balance_nominal=0, rs_balance_qty=0");
};

if($@){
	daemon::warn('error : '.$@);
	$db->rollback();
}
$db->commit();
