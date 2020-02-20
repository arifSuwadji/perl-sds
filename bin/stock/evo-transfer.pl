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
use XML::Simple;


while (1) {
	my $db = daemon::db_connect();

	my $res = $db->query(<<"EOS");
SELECT topup_id, nominal, dest_msisdn, topup_qty,
  topup_ts, trans_id, exec_ts
FROM topup
  inner join stock_ref using (stock_ref_id)
  inner join topup_sms using (topup_id)
WHERE topup_status='W' and stock_ref.ref_type_id=9
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

		my $msisdn = $row->{dest_msisdn};
		$msisdn =~ s/62/0/ if $msisdn =~ /^62/;

		my ($nom) = ($row->{nominal}=~ /(\d+)\d{3}/);   # nominal 5000 = 5 
		my %param = (
			msg => join('.', 'T', $msisdn, $row->{topup_qty}, 75893),
			msisdn => 'sds-server', smsc => 'h2h',
			ts => $row->{exec_ts},
		);

		my $url = 'http://192.168.2.201:9192/service?'.enurl(\%param);
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

		my $ref = eval{XMLin $resp->content};
		my $text = ref $ref ? $ref->{text} : '' ;
		$db->update("topup",
			{topup_status=>'S', need_reply => 1, error_msg => $text},
			{trans_id=>$trans_id}
		);
		$db->commit;
	}
	sleep 1;
}
