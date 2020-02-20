#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;

my $db = daemon::db_connect();

# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
update pricing set old_price=NULL
__eos__

$db->disconnect;

