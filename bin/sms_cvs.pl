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
my $a = 1;
my $b = $db->query("select count(*) from member where member_type='CVS' and parent_id in (24, 106)");
while ($a < $b) {

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
	select user_id, username, member_id, parent_id, member_name, member_type, member_target from member inner join user using (member_id) where member_type='CVS' and user.status='Active' and parent_id in (24, 106)
__eos__

	while (my $row = $res->hash) {
		print 'Unprocessed: ', Dumper($row);
		my $out_ts  = common::now();

		my ($smsc_id, $smsc_name) = $db->query(
			"select smsc_id, smsc_name from smsc where smsc_name !='' and smsc_name in ('center','center1','center2') and smsc_status='active' and smsc_name <> ? order by rand() limit 1", $config::smsc)->list;

		my ($from, $until) = $db->query('select from_date, until_date + interval 1 day from target_period where period_status="open"')->list;
		print "from = $from\n";
		print "until = $until\n";
		my $d_sale = $db->query("select ref_type_id, ref_type_name from stock_ref_type where ref_type_id > 11 and ref_type_name like 'Dompul-%'");
		my %sale;
		my @sal = $d_sale->hashes;
		print "==>",Dumper(@sal);
		my %target;
		my $sum_qty_sale = 0;
		my $target_sale = 0;
		my $persen_unit =0;
		my $text_unit = "";
		foreach (@sal) {
			$sum_qty_sale = $db->query(
				"select sum(qty_sale) from dompul_sale where member_id=? and ref_type_id=? and sale_ts >= ? and sale_ts < ?",
				$row->{member_id}, $_->{ref_type_id}, $from, $until
			)->list;
			unless ($sum_qty_sale) {$sum_qty_sale = 0;}
			print "-->",$sum_qty_sale;
			$sale{$_->{ref_type_id}} = $sum_qty_sale;
			$target_sale = $db->query("select qty_target from dompul_target where member_id=? and ref_type_id=?", $row->{member_id}, $_->{ref_type_id})->list;
			unless ($target_sale) {$target_sale = 0;}
			$target{$_->{ref_type_id}} = $target_sale;
			print "))))-->",$target_sale;
			if ($target{$_->{ref_type_id}} == 0 or $sale{$_->{ref_type_id}} == 0) {
				$persen_unit = 0;
			} else {
				$persen_unit = ($sale{$_->{ref_type_id}} / $target{$_->{ref_type_id}}) * 100;
				print "1++>",$persen_unit;
				if ($persen_unit =~ /.\d{2,}/) {
					my ($pers_unit) = ($persen_unit =~ /(\d+)./);
					my ($pers1_unit) = ($persen_unit =~ /\d+.(\d+)/);
					my ($pers3_unit) = ($pers1_unit =~ /^(\d{2})/);
					$persen_unit = $pers_unit.'.'.$pers3_unit;
				}

				print "2++>",$persen_unit;
			}
			#$text_unit .= "$_->{ref_type_name} ; sale = $sale{$_->{ref_type_id}} target = $target{$_->{ref_type_id}} prosentase = $persen_unit %, ";
			$text_unit .= "$_->{ref_type_name}; $sale{$_->{ref_type_id}}|$target{$_->{ref_type_id}}= $persen_unit%, ";
		}
		print "gggg ====> $text_unit\n";

		my $sum_amount = $db->query("select sum(-amount) as sum_amount from topup inner join stock_ref using (stock_ref_id) inner join stock_ref_type using(ref_type_id) inner join mutation using (trans_id) where topup.member_id= ? and topup_status='S' and ref_type_name='Dompul' and topup_ts >= ? and topup_ts < ?", $row->{member_id}, $from, $until)->list;
		
		my $persen;
		unless ($sum_amount) {
			print "kosong"; 
			$persen = '0';
		} else {
		print "amount = $sum_amount";
		$row->{member_target} = '1' if $row->{member_target} == '0';
		$persen = $sum_amount / $row->{member_target} * 100;
			print "persen = $persen";
		if ($persen =~ /.\d{2,}/) {
				my ($pers) = ($persen =~ /(\d+)./);
				my ($pers1) = ($persen =~ /\d+.(\d+)/);
				my ($pers3) = ($pers1 =~ /^(\d{2})/);
				$persen = $pers.'.'.$pers3;
				print "persen = $persen\n";
			}
		}
		$sum_amount =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;
		$sum_amount =~ s/0$//g;
		$row->{member_target} =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;
		$row->{member_target} =~ s/0$//g;

		my $message = "$row->{member_name} = D-nom; $sum_amount|$row->{member_target}= $persen%, $text_unit";
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
	$a = $a + 1;
	exit;
}

