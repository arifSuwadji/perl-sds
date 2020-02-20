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

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
	select user_id, username, member_id, parent_id, member_name, member_type, member_target from member inner join user using (member_id) where member_type='CVS' and user.status='Active'
__eos__

	while (my $row = $res->hash) {
		print 'Unprocessed: ', Dumper($row);
		my $out_ts  = common::now();

		my ($smsc_id, $smsc_name) = $db->query(
			"select smsc_id, smsc_name from smsc where smsc_status='active' and smsc_name <> ? order by rand() limit 1", $config::smsc)->list;

		my ($from, $until) = $db->query('select from_date, until_date + interval 1 day from target_period where period_status="open"')->list;
		print "from = $from\n";
		print "until = $until\n";
		my $type = $db->query("select ref_type_name from topup inner join stock_ref using (stock_ref_id) inner join stock_ref_type using (ref_type_id) where member_id=? and topup_ts > ? and topup_ts < ?  group by ref_type_name", $row->{member_id}, $from, $until);
		my @types = $type->hashes;
		#print "==>",Dumper(@types);
		my $sum_amount = '0';
		my $text = "";
		foreach (@types) {
		$sum_amount = $db->query("select sum(-amount) as sum_amount from topup inner join stock_ref using (stock_ref_id) inner join stock_ref_type using(ref_type_id) inner join mutation using (trans_id) where topup.member_id= ? and topup_status='S' and ref_type_name=? and topup_ts >= ? and topup_ts < ?", $row->{member_id}, $_->{ref_type_name}, $from, $until)->list;
		
		$sum_amount =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;
        $sum_amount =~ s/0$//g;
		$text .="$_->{ref_type_name} = Rp.$sum_amount, ";
		}
		print "message = $text\n";	

		my $message = "penjualan $row->{member_name} sampai tgl : $out_ts, $text";
		print "message = $message\n";


		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^192\./, '127.0.0.1');
		$ua->timeout(10);

		my $url = 'http://127.0.0.1:59194/service/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $smsc_name,
			#modem    => 'modem1',
			text     => $message,
			to       => $row->{username},
			ts       => $out_ts,
		});
		print 'url: ', $url;
		my $resp = $ua->get($url);
		print 'resp: ', $resp->status_line, ' : ', $resp->content;
		my $out_status = $resp->is_success ? 'S' : 'F';

		sleep 1;
	}

	$db->disconnect;
	sleep 1;
	#$a = $a + 1;
	exit;
}

