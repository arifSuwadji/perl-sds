#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use Data::Dumper;
use LWPx::ParanoidAgent;
use CGI::Enurl;


my $db = daemon::db_connect();

# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
update transaction set reversal_approve='LOCK_TOTAL' where DATE_SUB(trans_date, INTERVAL 6 DAY)
__eos__

$db->disconnect;

