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
		
		if($outlet_id) {
			print "exist";
			$dbx->query("update outlet set owner='$cols[6]' where outlet_id = '$outlet_id'");
			# $dbx->query("update rs_chip set rs_number='$cols[1]', member_id=NULL, sd_id='$sd_id', rs_type_id='$rs_type_id', rs_chip_type =  'dompul where outlet_id = '$outlet_id'");							
		}
	};
	if ($@) {
		$dbx->rollback();
		next;
	}
	$dbx->commit();
}
