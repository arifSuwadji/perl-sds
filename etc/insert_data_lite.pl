#!/usr/bin/perl -w

use strict;

use Mojolicious::Lite;
use DBIx::Lite;
use Data::Dumper;

my $schema = DBIx::Lite::Schema->new;
$schema->table('outlet')->autopk('outlet_id');
$schema->table('member')->autopk('member_id');
$schema->table('sd_chip')->autopk('sd_id');

my $db = DBIx::Lite->new(schema => $schema) ->connect("DBI:mysql:sds_suryalaya", "root", "", {RaiseError => 1});
my $log = app->log();

my $outlet = $db->table('outlet');
my $member = $db->table('member');
my $sd_chip = $db->table('sd_chip');
my $rs_chip = $db->table('rs_chip');
my $site = $db->table('site');

open FH, "ALLDATAOUTLETSDSALL.csv";
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
	my %hash_outlet = (outlet_name => $cols[1], address => $cols[3], sub_district => $cols[4], outlet_type_id => 1);
	$log->info("OUTLET ". Dumper \%hash_outlet);
	#site
	my ($sd_name, $sd_number) = split /\[/, $cols[6];
	$sd_name =~ s/\s//g;
	$sd_number =~ s/\]//g;
	$sd_number =~ s/\s//g;
	my @arr_name = split /\-/, $sd_name;
	my $rs_site = $site ->search({site_name => $arr_name[1]})->single;
	#sd chip
	my %hashsd_chip = (sd_name => $sd_name, sd_number => $sd_number, site_id => $rs_site->site_id, ref_type_id => 2);
	$log->info("SD CHIP ". Dumper \%hashsd_chip);
	#member
	$cols[5] =~ s/\s$//;
	my %hash_member = (member_name => $cols[5], site_id => $rs_site->site_id, status => 'Active');
	$log->info("MEMBER ". Dumper \%hash_member);
	#rs chip
	my $rs_number = '62'.$cols[2];
	my %hashrs_chip = (sd_id => '', rs_number => $rs_number, member_id => '', rs_type_id => 2, outlet_id => '', rs_chip_type => 'mkios');
	$log->info($j." Last");

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
}
