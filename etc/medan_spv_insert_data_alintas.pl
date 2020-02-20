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

#open FH, "Perbaikan_Master_Customer-2.csv";
open FH, "DATA_BASE_MEDAN.csv";
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
	my %hash_outlet = (outlet_name => $cols[4], address => $cols[5], outlet_type_id => 1);
	$log->info("OUTLET ". Dumper \%hash_outlet);

	#site
	my $siteName = 'medan';
	my $rs_site = $site ->search({site_name => $siteName})->single;
	my $siteID = undef;
	if($rs_site){
		$siteID = $rs_site->site_id;
	}else{
		my $dataSite = $site ->insert({site_name => $siteName});
		$siteID = $dataSite->site_id;
	}

	#sd chip
	my $sd_number = $cols[3];
	$sd_number =~ s/^0/62/g;
	my $sd_name = 'sd '.$siteName;
	my %hashsd_chip = (sd_name => $sd_name, sd_number => $sd_number, site_id => $siteID, ref_type_id => 1);
	$log->info("SD CHIP ". Dumper \%hashsd_chip);

	#member
	$cols[6] =~ s/\s$//;
	my %hash_member = (member_name => $cols[6], site_id => $siteID, status => 'Active', parent_id => '');

	#spv
	$cols[8] =~ s/\s$//;
	my %hash_spv = (member_name => $cols[8], site_id => $siteID, status => 'Active', member_type => 'SPV', parent_id => '');

	#bm
	$cols[9] =~ s/\s$//;
	my %hash_bm = (member_name => $cols[9], site_id => $siteID, status => 'Active', member_type => 'BM');
	$log->info("BM ". Dumper \%hash_bm);

	#rs_type
	my $typeName = $cols[2] || 'RO';
	my $rs_type_data = $rs_type ->search({type_name => $typeName})->single;
	my $rsTypeID  = undef;
	if($rs_type_data){
		$rsTypeID = $rs_type_data->rs_type_id;
	}else{
		my $dataRsType = $rs_type ->insert({type_name => $typeName});
		$rsTypeID = $dataRsType->rs_type_id;
	}

	#rs chip
	my $rs_number = $cols[0];
	$rs_number =~ s/^0/62/g;
	$log->info('rs type id '.$rsTypeID);
	my %hashrs_chip = (sd_id => '', rs_number => $rs_number, member_id => '', rs_type_id => $rsTypeID, outlet_id => '', rs_chip_type => 'dompul');

	#user/no hp canvasser
	my $no_hp = $cols[7];
	$no_hp =~ s/^0/62/g;
	my %hashno_hp = (member_id => '', username => $no_hp, pin => '1234', status => 'Active');

	my $insert_outlet = $outlet ->find_or_insert(\%hash_outlet);
	my $insert_sdchip = $sd_chip ->find_or_insert(\%hashsd_chip);

	#insert bm
	my $insert_bm = $member ->find_or_insert(\%hash_bm);
	#inert spv
	$hash_spv{parent_id} = $insert_bm->member_id;
	$log->info("SPV ". Dumper \%hash_spv);
	my $insert_spv = $member ->find_or_insert(\%hash_spv);
	#insert_csv
	$hash_member{parent_id} = $insert_spv->member_id;
	$log->info("MEMBER ". Dumper \%hash_member);
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
	my $userData = $user ->search({username => $hashno_hp{username}})->single;
	unless($userData){
		eval{
			$user ->find_or_insert(\%hashno_hp);
		};
		if($@){
			$log->info("insert no hp error ".$@);
		}
	}else{
		$log->info("no hp found");
	}
	$log->info($j." Last");
}
