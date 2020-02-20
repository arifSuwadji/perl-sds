#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use Data::Dumper;


while (1) {
	my $db = daemon::db_connect();

	# get all records which have been in 'P' state for 4 minutes
	my $res = $db->query(<<"__eos__");
SELECT topup_id, topup_ts
FROM topup
WHERE topup_status='P' and topup_ts < date_sub(now(), interval 4 minute)
__eos__

	while (my $row = $res->hash) {
		daemon::warn('row: ', Dumper($row));
		my $topup_id = $row->{topup_id};

		$db->update('topup',
			{topup_status=>'S', need_reply=>1},
			{topup_id => $topup_id},
		);
	}

	$db->disconnect;
	sleep 5;
}

