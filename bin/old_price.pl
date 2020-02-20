#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use Data::Dumper;


while (1) {
	my $db = daemon::db_connect();

	# get all records which are in 'W' state
	my $res = $db->query(<<"__eos__");
SELECT stock_ref_id, rs_type_id, price, old_price
FROM pricing 
WHERE price_type = 'OLD'
__eos__

	while (my $row = $res->hash) {
		unless ($row->{old_price}) {
			daemon::warn('Unprocessed: ', Dumper($row));

			my $old_price = $row->{price};
			$db->update('pricing',
        	                {old_price => $old_price},
                	        {rs_type_id => $row->{rs_type_id}, stock_ref_id => $row->{stock_ref_id}},
	                );
		}
	}
	$db->disconnect;
	sleep 1;
}

