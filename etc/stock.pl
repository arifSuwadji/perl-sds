#!/usr/bin/perl -l

use Data::Dumper;
use DBIx::Simple;

our @db_con = ('DBI:mysql:sds;host=localhost', 'root', '');
my $dbx = DBIx::Simple->connect(@db_con, {RaiseError=> 1, AutoCommit =>1});

open FH, "stock.csv";

while (<FH>) {
	chomp;
	my @cols = split /;/;
	for(my $i=0;$i<scalar(@cols);$i++) {
		$cols[$i] =~ s/"//g;
	}
	print $cols[0];
	#$cols[0] = sd_name
	#$cols[1] = rs_number
	#$cols[2] = outlet name
	#$cols[3] = XL1 request
	#$cols[4] = XL1 approve
	#$cols[5] = XL5 request
	#$cols[6] = XL5 approve
	#$cols[7] = XL10 request
	#$cols[8] = XL10 approve
	
	#my $sd_id = $dbx->query("select sd_id from sd_chip where sd_name=$cols[0]")->list;
	#stock_ref_id diisi manual
	my $rs_id = $dbx->query("select rs_id from rs_chip where rs_number=$cols[1]")->list;
	unless (defined $rs_id) {next;}
	my $result =  $dbx->query("select distinct(rs_id) as rs_id2 from rs_stock where rs_number=$cols[1]");
	
	my $false = 0;
	while (my $rs_id2 = $result->list) {
		if ($rs_id2 == $rs_id) {
			$false = 1;
		}
	}	
	
	unless ($false) {
		$dbx->query("insert into rs_stock(rs_id, stock_ref_id, request, approve) values(?,11,?,?)", $rs_id, $cols[3], $cols[4]);
	        $dbx->query("insert into rs_stock(rs_id, stock_ref_id, request, approve) values(?,12,?,?)", $rs_id, $cols[5], $cols[6]);
        	$dbx->query("insert into rs_stock(rs_id, stock_ref_id, request, approve) values(?,13,?,?)", $rs_id, $cols[7], $cols[8]);
	}
	
	$dbx->query("update rs_stock set request=?, approve=? where rs_id=? and stock_ref_id=11", $cols[3], $cols[4], $rs_id);
	$dbx->query("update rs_stock set request=?, approve=? where rs_id=? and stock_ref_id=12", $cols[5], $cols[6], $rs_id);
	$dbx->query("update rs_stock set request=?, approve=? where rs_id=? and stock_ref_id=13", $cols[7], $cols[8], $rs_id);

}
