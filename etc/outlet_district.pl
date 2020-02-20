#!/usr/bin/perl -w

use strict;

use Mojolicious::Lite;
use DBIx::Lite;
use Data::Dumper;

my $schema = DBIx::Lite::Schema->new;
$schema->table('outlet')->autopk('outlet_id');
$schema->table('member')->autopk('member_id');
$schema->table('sd_chip')->autopk('sd_id');
$schema->table('site')->autopk('site_id');
$schema->table('rs_type')->autopk('rs_type_id');

my $db = DBIx::Lite->new(schema => $schema) ->connect("DBI:mysql:sds_alintas_dua", "root", "", {RaiseError => 1});
my $log = app->log();

my $outlet = $db->table('outlet');
my $member = $db->table('member');
my $sd_chip = $db->table('sd_chip');
my $rs_chip = $db->table('rs_chip');
my $site = $db->table('site');
my $user = $db->table('user');
my $rs_type = $db->table('rs_type');


