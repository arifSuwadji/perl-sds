#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use Data::Dumper;
use LWPx::ParanoidAgent;
use CGI::Enurl;


while (1) {
	my $db = daemon::db_connect();

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
SELECT stock_ref_id, rs_type_id, keyword, type_name, price, old_price
FROM pricing 
  INNER JOIN stock_ref using (stock_ref_id) 
  INNER JOIN rs_type using(rs_type_id)
WHERE price_type = 'NEW'
for update
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Unprocessed: ', Dumper($row));

		my $username = $config::username;
		my $out_ts  = $db->query('select now()')->list;

		my $old_price = $row->{old_price};
		my $keyword = $row->{keyword};
		my $type_name = $row->{type_name};
		my $new_price = $row->{price};
		#($old_price) = $old_price=~ m/(\d+)/;
                #($new_price) = $new_price=~ m/(\d+)/;
	
		my $out_msg = "harga $keyword tipe $type_name sudah menjadi $new_price dari $old_price, by andi"; 
		daemon::warn('out msg :', $out_msg);	
		# my ($smsc_id, $smsc_name) = $db->query(
		#	'select smsc_id, smsc_name from smsc order by rand() limit 1'
		#)->list;
		
		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^192\./, '127.0.0.1');
		$ua->timeout(10);
		
		my $url = 'http://127.0.0.1:59194/service/sendsms?'. enurl({
			username => 'app1',
			password => '1234',
			modem    => $config::smsc,
			text     => $out_msg,
			to       => $username,
			ts       => $out_ts,
		});
		daemon::warn('url: ', $url);
		my $resp = $ua->get($url);
		daemon::warn('resp: ', $resp->status_line, ' : ', $resp->content);
		my $price_type = $resp->is_success ? 'OLD' : 'NEW';
		
		$db->update('pricing',
                        {price_type => $price_type},
                        {rs_type_id => $row->{rs_type_id}, stock_ref_id => $row->{stock_ref_id}},
                );
	sleep 1;
	}
	$db->disconnect;
	sleep 1;
}

