#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;

my $db = daemon::db_connect();

# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
delete from pricing_temporary where date(save_time) <> date(now())
__eos__

$db->disconnect;

