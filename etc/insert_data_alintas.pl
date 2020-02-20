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

my $db = DBIx::Lite->new(schema => $schema) ->connect("DBI:mysql:sds_alintas", "root", "", {RaiseError => 1});
my $log = app->log();

my $outlet = $db->table('outlet');
my $member = $db->table('member');
my $sd_chip = $db->table('sd_chip');
my $rs_chip = $db->table('rs_chip');
my $site = $db->table('site');
my $user = $db->table('user');

#open FH, "format_isian_data_KBTG.csv";
open FH, "format_isian_data_PDLB.csv";
my $j = 0;
while (<FH>) {
	++$j;
	next if $j == 1;
	chomp;
	my @cols = split /\|/;
	for (my $i=0;$i<scalar(@cols);$i++) {
		$cols[$i] =~ s/"|'//g; # dibersihkan dari petikganda
		$log->info("kolom ke-$i = $cols[$i]");
	}
	#outlet
	my %hash_outlet = (outlet_name => $cols[0], address => $cols[2], sub_district => $cols[3], outlet_type_id => 1);
	$log->info("OUTLET ". Dumper \%hash_outlet);
	#site
	my $siteName = $cols[7];
	my $rs_site = $site ->search({site_name => $siteName})->single;
	my $siteID = undef;
	if($rs_site){
		$siteID = $rs_site->site_id;
	}else{
		my $dataSite = $site ->insert({site_name => $siteName});
		$siteID = $dataSite->site_id;
	}

	#sd chip
	my $sd_number = $cols[6];
	$sd_number =~ s/^0/62/g;
	my $sd_name = $siteName.' ['.$sd_number.']';
	my %hashsd_chip = (sd_name => $sd_name, sd_number => $sd_number, site_id => $siteID, ref_type_id => 1);
	$log->info("SD CHIP ". Dumper \%hashsd_chip);
	#member
	$cols[4] =~ s/\s$//;
	my %hash_member = (member_name => $cols[4], site_id => $siteID, status => 'Active');
	$log->info("MEMBER ". Dumper \%hash_member);
	#rs chip
	my $rs_number = $cols[1];
	$rs_number =~ s/^0/62/g;
	my %hashrs_chip = (sd_id => '', rs_number => $rs_number, member_id => '', rs_type_id => 1, outlet_id => '', rs_chip_type => 'dompul');
	$log->info($j." Last");
	#user/no hp canvasser
	my $no_hp = $cols[5];
	$no_hp =~ s/^0/62/g;
	my %hashno_hp = (member_id => '', username => $no_hp, pin => '1234', status => 'Active');

	my $insert_outlet = $outlet ->find_or_insert(\%hash_outlet);
	my $insert_sdchip = $sd_chip ->find_or_insert(\%hashsd_chip);
	my $insert_member = $member ->find_or_insert(\%hash_member);

	$hashrs_chip{sd_id} = $insert_sdchip->sd_id;
	$hashrs_chip{member_id} = $insert_member->member_id;
	$hashrs_chip{outlet_id} = $insert_outlet->outlet_id;
	$log->info("RS CHIP ". Dumper \%hashrs_chip);
	eval{
		$rs_chip ->find_or_insert(\%hashrs_chip);
	};
	if($@){
		$log->info("insert rs chip error ".$@);
	}

	#insert hp canvasser
	$hashno_hp{member_id} = $insert_member->member_id;
	$log->info("NO HP CANVASSER ".Dumper \%hashno_hp);
	if($no_hp){
		eval{
			$user ->find_or_insert(\%hashno_hp);
		};
		if($@){
			$log->info("insert no hp error ".$@);
		}
	}else{
		$log->info("no hp not found");
	}
}
