#!/usr/bin/perl -l

use Data::Dumper;
use DBIx::Simple;

our @db_con = ('DBI:mysql:sds_ss;host=localhost', 'root', '');
my $dbx = DBIx::Simple->connect(@db_con, {RaiseError => 1, AutoCommit =>1});

#open FH, "sub_master_debora.csv";
#open FH, "Membership_SGN_Bekasi.csv";
open FH, "Membership_with_SubMaster.csv";
my (%upline, %mem);
while (<FH>) {
	chomp;
	my @cols = split /","/;
	print @cols;
	#print $cols[0];
	for (my $i=0;$i<scalar(@cols);$i++) {
		$cols[$i] =~ s/"|'//g; # dibersihkan dari petikganda
		print "kolom ke-$i = $cols[$i]";
	}
	
	# table outlet
	# table sd_chip
	# table member
	# table rs_type
	# table rs_chip

	print "SD Chip	: ",$cols[0],"	RS Chip : ",$cols[1],"	outlet_name : ",$cols[2],"	rs_type : ", $cols[3],"	 outlet_address : ",$cols[4],	
		"District : ", $cols[5],"	sub district : ",$cols[6],"	mobile_phone : ",$cols[7],"	owner : ", $cols[8] , "	ktp_number : ", $cols[9], "	member : ", $cols[10];

	$dbx->begin();
	#insert outlet
	my ($outlet_id,$outlet_name) = $dbx->query("select outlet_id,outlet_name from outlet where outlet_name=?",$cols[2])->list;
	print "outlet_id : ", $outlet_id, "	outlet_name : ", $outlet_name;
	unless($outlet_name){
		my %data = ( outlet_name => $cols[2], address => $cols[4], district => $cols[5], sub_district => $cols[6], owner => $cols[8], 
				mobile_phone => $cols[7], ktp_number => $cols[9],);
		$dbx->insert('outlet', \%data);
		$outlet_id = $dbx->last_insert_id(0,0,0,0);
		print "insert('outlet',	outlet_name => $cols[2],	address	=> $cols[4],	district => $cols[5],	sub_district => $cols[6],	
				owner	=> $cols[8],	mobile_phone => $cols[7],	ktp_number => $cols[9],);";
	}
	
	#insert sd_chip
	my ($sd_id,$sd_number) = $dbx->query("select sd_id,sd_number from sd_chip where sd_number=?",$cols[0])->list;
	print "sd_id	: ", $sd_id , "		sd_number : ", $sd_number;
	unless($sd_number){
		my $count = $dbx->query("select count(*) from sd_chip")->list;
		$count = $count + 1;
		my $sd_name = "sd-dompul-". $count;
		print "sd name : ", $sd_name;
		$dbx->insert('sd_chip',{
				sd_name		=> $sd_name,
				sd_number	=> $cols[0],
				ref_type_id	=> 1,
				site_id		=> 2,
				modem		=> $sd_name,}
		);
		$sd_id = $dbx->last_insert_id(0,0,0,0);
		print "insert('sd_chip',	sd_name	=> $sd_name,	sd_number => $cols[0],	ref_type => 1,	site_id	=> 2,	modem => $sd_name,);";
	}
	
	#insert member
	my ($member_id,$member_name) = $dbx->query("select member_id,member_name from member where member_name like '%$cols[10]%'")->list;
	print "member_id	: ", $member_id	,"	member_name : ", $member_name;
	unless($member_name){
		$dbx->insert('member',{
				member_name	=> $cols[10],
				site_id		=> 2,
				status		=> 'Active',}
		);
		$member_id = $dbx->last_insert_id(0,0,0,0);
		print "insert('member',	member_name => $cols[10],	site_id	=> 2,	status	=> 'Active',);";
	}
	
	#insert rs_type
	my ($rs_type_id,$type_name) = $dbx->query("select rs_type_id,type_name from rs_type where type_name=?",$cols[3])->list;
	print "rs_type_id	: ", $rs_type_id, "	type_name : ", $type_name;
	
	unless($type_name){
		$dbx->query("insert into rs_type(type_name) values('$cols[3]')");
		$rs_type_id = $dbx->last_insert_id(0,0,0,0);
		print "insert into rs_type(type_name) values('$cols[3]')";
	}
	
	#insert rs_chip
	my $rs_number = $dbx->query("select rs_number from rs_chip where rs_number=?",$cols[1])->list;
	print "rs_number	: ", $rs_number;
	unless($rs_number){
		print "sd id : ", $sd_id;
		$dbx->insert('rs_chip',{
				sd_id		=> $sd_id,
				rs_number	=> $cols[1],
				member_id	=> $member_id,
				rs_type_id	=> $rs_type_id,
				outlet_id	=> $outlet_id,
				rs_chip_type	=> 'dompul',}
		);
		print "insert('rs_chip', sd_id => $sd_id,	rs_number => $cols[1],	member_id => $member_id,	rs_type_id => $rs_type_id,	
				outlet_id => $outlet_id,	rs_chip_type => 'dompul',);";
	}
	$dbx->update('rs_chip',{
				sd_id		=> $sd_id,
				rs_number	=> $cols[1],
				member_id	=> $member_id,
				rs_type_id	=> $rs_type_id,
				outlet_id	=> $outlet_id,
				rs_chip_type	=> 'dompul',
			},
			{rs_number	=> $rs_number}
		) if $rs_number;
	print "update('rs_chip',{ sd_id	=> $sd_id,	rs_number => $cols[1],	member_id => $member_id,	rs_type_id => $rs_type_id,	
				outlet_id => $outlet_id,	rs_chip_type => 'dompul',}, {rs_number	=> $rs_number})" if $rs_number;
	print "================================================================================================";
	$dbx->commit();

}
