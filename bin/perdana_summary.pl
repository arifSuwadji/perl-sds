#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use common;
use daemon;
use Data::Dumper;
use LWPx::ParanoidAgent;
use CGI::Enurl;

my $db = daemon::db_connect();
#my $a = 1;
#my $b = $db->query("select count(*) from member where member_type='CVS'");
while (1) {

		my ($period_id, $from, $until) = $db->query('select period_id,from_date, until_date + interval 1 day from target_period where period_status="open"')->list;
		print "period_id = $period_id\n";
		print "from = $from\n";
		print "until = $until\n";

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__", $from, $until);
	select member_id from member inner join dompul_sale using (member_id) where sale_ts >= ?  and sale_ts < ? group by member_id
__eos__

	while (my $row = $res->hash) {
		print 'Unprocessed: ', Dumper($row);
		my $out_ts  = common::now();
		#perdana
		my $target_week = $db->query('select sum(nominal_target) from dompul_target where member_id=?',$row->{member_id})->list;

		my $sum_qty_sale = $db->query(
                "select sum(qty_sale) from dompul_sale where member_id=? and ref_type_id=? and sale_ts >= ? and sale_ts < ?",
                $row->{member_id}, $config::reftypeid, $from, $until
            )->list;
            unless ($sum_qty_sale) {$sum_qty_sale = 0;}
            my $price = $db->query("select price from pricing inner join stock_ref using(stock_ref_id) where ref_type_id=? limit 1",$config::reftypeid)->list;
		my $sum_price;
		if ($sum_qty_sale >= 1){
            $sum_price = $sum_qty_sale * $price;
            }else {$sum_price = 0;}	

		print "perdana = ",$sum_qty_sale;
		unless ($sum_qty_sale) {
			print "next";
			next;
		}
		my ($s_id) = $db->query('select summary_id from summary_sale where period_id=? and member_id=?',$period_id, $row->{member_id})->list;
		unless ($s_id) {
			print "insert summary";
				$db->insert('summary_sale',{
					period_id => $period_id, member_id => $row->{member_id}, perdana_qty => $sum_qty_sale,	
				});	
		} else {
			print "update summary";
			$db->query('update summary_sale set perdana_qty=? where summary_id=?',$sum_qty_sale, $s_id);
		}	
	}

	$db->disconnect;
	sleep 20;
	exit;
}

