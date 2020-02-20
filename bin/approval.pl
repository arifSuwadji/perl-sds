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
SELECT stock_ref_id, rs_type_id, keyword, type_name, price
FROM pricing_temporary 
  INNER JOIN stock_ref using (stock_ref_id) 
  INNER JOIN rs_type using(rs_type_id)
WHERE price_type = 'NEW' and price<>0
for update
__eos__

	while (my $row = $res->hash) {
		daemon::warn('Data : ', Dumper($row));

	    if($config::skip_approval){
		daemon::warn('skip approval for update price');
		eval{
			#update pricing
			my $find_price = $db->query("SELECT stock_ref_id FROM pricing WHERE rs_type_id=? AND stock_ref_id=?",$row->{rs_type_id},$row->{stock_ref_id})->list;
			if($find_price){
				$db->update('pricing',
							{price => $row->{price}},
							{rs_type_id => $row->{rs_type_id}, stock_ref_id => $row->{stock_ref_id}},
				);
			}else{
				$db->insert('pricing',
							{
								stock_ref_id => $row->{stock_ref_id},
								rs_type_id => $row->{rs_type_id},
								price => $row->{price},
							}
				);
			}
		   #update status pricing temporary
	 	   $db->update('pricing_temporary',
                        {price_type => 'OLD'},
                        {rs_type_id => $row->{rs_type_id}, stock_ref_id => $row->{stock_ref_id}},
                   );
		};
		if($@){
			daemon::warn("error change price : ", $@);
		}
	    }else{
		my $username = $config::username;
		my $out_ts  = $db->query('select now()')->list;

		my ($old_price) = $db->query("select price from pricing where stock_ref_id=? and rs_type_id=? and price_type='OLD'", $row->{stock_ref_id}, $row->{rs_type_id})->list;
		my $keyword = $row->{keyword};
		my $type_name = $row->{type_name};
		my $new_price = $row->{price};
		#($old_price) = $old_price=~ m/(\d+)\.\d+/;
		#($new_price) = $new_price=~ m/(\d+)\.\d+/;
		
		my $out_msg = "entry harga $keyword tipe $type_name dari $old_price menjadi $new_price. Untuk approval forward sms ini"; 
		
		#my ($smsc_id, $smsc_name) = $db->query(
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
		
		$db->update('pricing_temporary',
                        {price_type => $price_type},
                        {rs_type_id => $row->{rs_type_id}, stock_ref_id => $row->{stock_ref_id}},
                );
	    }
		sleep 1;	
	}
	$db->disconnect;
	sleep 1;
}

