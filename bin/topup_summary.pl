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
	select member_id from member inner join topup using (member_id) where topup_status='S' and topup_ts >= ?  and topup_ts < ? group by member_id
__eos__

	while (my $row = $res->hash) {
		print 'Unprocessed: ', Dumper($row);
		my $out_ts  = common::now();
		#nominal
		my $sum = $db->query("select sum(-amount) as sum_amount from topup inner join stock_ref using (stock_ref_id) inner join stock_ref_type using(ref_type_id) inner join mutation using (trans_id) where topup.member_id= ? and topup_status='S' and topup_ts >= ? and topup_ts < ?", $row->{member_id}, $from, $until)->list;
		
		print "nominal = ",$sum;
		unless ($sum) {
			print "next";
			next;
		}
		my ($s_id) = $db->query('select summary_id from summary_sale where period_id=? and member_id=?',$period_id, $row->{member_id})->list;
		unless ($s_id) {
			print "insert summary";
				$db->insert('summary_sale',{
					period_id => $period_id, member_id => $row->{member_id}, topup_summary => $sum,	
				});	
		} else {
			print "update summary";
			$db->query('update summary_sale set topup_summary=? where summary_id=?',$sum, $s_id);
		}	
	}

	$db->disconnect;
	sleep 15;
	exit;
}

