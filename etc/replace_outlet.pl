#!/usr/bin/perl -l
use Data::Dumper;
use DBIx::Simple;

our @db_con = ('DBI:mysql:sds;host=localhost', 'root', '');
my $dbx = DBIx::Simple->connect(@db_con, {RaiseError => 1, AutoCommit =>1});

#open FH, "sub_master_debora.csv";
open FH, "RS_TDOMPUL_KSA.csv";
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
	#outlet : outlet_id, outlet_name, address, district, sub_district, pos_code, owner, mobile_phone
	# member_id
	print "begin";
	eval {	
		my $outlet_id = $dbx->query("select outlet_id from outlet where outlet_name=? and address=?", $cols[0], $cols[2])->list;
		
		my $sd_id = $dbx->query("select sd_id from sd_chip where sd_number=?", $cols[5])->list;
		
		my $rs_type_id = $dbx->query("select rs_type_id from rs_type where type_name=?", $cols[3])->list;

		unless ($outlet_id) {
			print "unless";
			$dbx->query("insert into outlet(outlet_name, address) values('$cols[0]','$cols[2]')");
			$outlet_id = $dbx->last_insert_id(0,0,0,0);
			
			$dbx->query("insert into rs_chip(rs_number, member_id, sd_id, rs_type_id, outlet_id, rs_chip_type) values('$cols[1]', NULL, '$sd_id', '$rs_type_id', '$outlet_id', 'dompul')");
			$dbx->commit();
			next;
		} else {
			print "exist";
			$dbx->query("update rs_chip set rs_number='$cols[1]', member_id=NULL, sd_id='$sd_id', rs_type_id='$rs_type_id', rs_chip_type =  'dompul where outlet_id = '$outlet_id'");							
		}
	};
	if ($@) {
		$dbx->rollback();
		next;
	}
	$dbx->commit();
}
