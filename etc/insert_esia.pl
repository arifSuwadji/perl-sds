#!/usr/bin/perl -l
use Data::Dumper;
use DBIx::Simple;

our @db_con = ('DBI:mysql:sds;host=localhost', 'root', '');
my $dbx = DBIx::Simple->connect(@db_con, {RaiseError => 1, AutoCommit =>1});

#open FH, "sub_master_debora.csv";
open FH, "rs_esia.csv";
my (%upline, %mem);
while (<FH>) {
	chomp;
	my @cols = split /,/;
	print @cols;
	print $cols[0];
	for (my $i=0;$i<scalar(@cols);$i++) {
		$cols[$i] =~ s/"|'//g; # dibersihkan dari petikganda
		print "kolom ke-$i = $cols[$i]";
	}
	$dbx->begin();
	print "begin";
	#outlet : outlet_id, outlet_name, address, district, sub_district, pos_code, owner, mobile_phone
	#member_id
	my $sd_id = $dbx->query("select sd_id from sd_chip where sd_name= '$cols[0]'")->list;	
	my $rs_type_id = $dbx->query("select rs_type_id from rs_type where type_name='$cols[3]'")->list;
	print "sd_id = $sd_id, rs_type_id = $rs_type_id";
	eval {
		$dbx->query("insert into outlet(outlet_name) values('$cols[4]')");
		# rs_chip: rs_id, sd_id, rs_number, member_id, rs_type_id, outlet_id, rs_chip_type
		my $last_id = $dbx->last_insert_id(0,0,0,0);
		$dbx->query("insert into rs_chip(rs_number, sd_id, rs_type_id, outlet_id, rs_chip_type) values('$cols[2]', $sd_id, $rs_type_id,  '$last_id','esia')");
	};
	if ($@) {
		$dbx->rollback();
		next;
	}
	$dbx->commit();
}
