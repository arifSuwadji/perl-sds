#!/usr/bin/perl -l
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use daemon::trx;

use CGI::Enurl;
use LWPx::ParanoidAgent;
use DBIx::Simple();
use Data::Dumper;


while (1) {
	my $db = daemon::db_connect();

	my $res = $db->query(<<"EOS");
SELECT topup_id, nominal, keyword, rs_number, topup_qty,
  pin, modem, site_url, topup_ts, exec_ts
FROM topup
  inner join stock_ref using (stock_ref_id)
  inner join rs_chip using (rs_id)
  inner join sd_chip using (sd_id)
  inner join site using (site_id)
WHERE topup_status='W' and stock_ref.ref_type_id=11
  AND exec_ts>0 and exec_ts<=now()
EOS
	while (my $row = $res->hash) {
		daemon::warn("row: ", Dumper($row));
		$db->begin();

		# lock
		my $trans_id = $db->query(
			"select trans_id from topup ".
			"where topup_id=? and topup_status='W' FOR UPDATE",
			$row->{topup_id},
		)->list;

		unless ($trans_id) {
			$db->rollback();
			next;
		}

		my $msisdn = $row->{rs_number};
		$msisdn =~ s/62/0/ if $msisdn =~ /^62/;
		my $url;
		if ($row->{nominal}) {	
			$url = 'sms?' . enurl({
				to => '6777',
				ts => $row->{exec_ts},
				text => join('.', 'DSV', $row->{keyword}.'='.$row->{topup_qty}, $msisdn , 
					$row->{pin}, 99),
				modem => $row->{modem},
			});
		}
		
		$url = $row->{site_url}."/send".$url."&username=app1&password=1234";
		daemon::warn($url);

		# hit jj
		my $ua = LWPx::ParanoidAgent->new;
		$ua->whitelisted_hosts(qr/^10\./ ,qr/^192\./, '127.0.0.1');
		$ua->timeout(10);

		my $resp = $ua->get($url);
		daemon::warn($resp->status_line, ' : ', $resp->content);

		unless ($resp->is_success or $resp->message =~ /timeout/i) {
			my $trx = daemon::trx->new($db);
			$trx->reversal($trans_id);
			$db->commit;
			next;
		}

		$db->update("topup", {topup_status=>'P'}, {trans_id=>$trans_id});
		$db->commit;
	}
	sleep 1;
}
