#!/usr/bin/perl -l
use Data::Dumper;
use DBIx::Simple;

our @db_con = ('DBI:mysql:sds;host=localhost', 'root', '');
my $dbx = DBIx::Simple->connect(@db_con, {RaiseError => 1, AutoCommit =>1});

#open FH, "sub_master_debora.csv";
open FH, "MEMBERSHIP24JUNI.csv";
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
	print "insert into outlet(outlet_name, address, district, mobile_phone, owner) values('$cols[1]','$cols[3]', '$cols[4]', '$cols[6]', '$cols[7]')')";
	print "insert into rs_chip(rs_number, sd_id, rs_type_id, rs_chip_type) values('$cols[0]', 3, 3, 'dompul')";

	#outlet : outlet_id, outlet_name, address, district, sub_district, pos_code, owner, mobile_phone
	#member_id
	
	my $member_id = $dbx->query('select member_id from member where member_name=?',$cols[9])->list;
	eval {
		$dbx->query("insert into outlet(outlet_name, address, district, mobile_phone, owner) values('$cols[1]','$cols[3]', '$cols[4]', '$cols[6]', '$cols[7]')");
		# rs_chip: rs_id, sd_id, rs_number, member_id, rs_type_id, outlet_id, rs_chip_type
		my $last_id = $dbx->last_insert_id(0,0,0,0);
		$dbx->query("insert into rs_chip(rs_number, member_id, sd_id, rs_type_id, outlet_id, rs_chip_type) values('$cols[0]', '$member_id', 3, 2,  '$last_id','dompul')");
	};
	if ($@) {
		$dbx->rollback();
		next;
	}
	$dbx->commit();
}
