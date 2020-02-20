#!/usr/bin/perl -l
package MyPackage;
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use daemon;
use daemon::trx;

use CGI::Enurl;
use LWP::UserAgent;
use HTTP::Response;
use DBIx::Simple();
use Data::Dumper;

my $ua = LWP::UserAgent->new;
$ua->ssl_opts(verify_hostname => 0);

MyPackage->run({port => 62001, min_servers => 3});

sub process_request{
	my $self = shift;
	eval {

		local $SIG{'ALRM'} = sub { die "Timed Out!\n" };
		my $timeout = 30; # give the user 30 seconds to type some lines

		my $line = <STDIN> || die "no data";
		$line =~ s/[\r\n]+$//;
		if ($line !~ /^ (\w+) \ + (\S+) \ + (HTTP\/1.\d) $ /x) {
			die "Bad request";
		}

		my ($method, $req, $protocol) = ($1, $2, $3);
		print STDERR join(" ", $self->log_time, $method, $req)."\n";

		#GET Topup id
		my ($topup_id) = ($req =~ /\/(\d+)/);


		my $db = daemon::db_connect();

		my $res = $db->query(<<"EOS", $topup_id);
SELECT topup_id, nominal, rs_number, topup_qty,
  pin, modem, site_url, topup_ts, trans_id, exec_ts, payment_gateway
FROM topup
  inner join stock_ref using (stock_ref_id)
  inner join rs_chip using (rs_id)
  inner join sd_chip using (sd_id)
  inner join site using (site_id)
WHERE topup_id=?
EOS
		while (my $row = $res->hash) {
			daemon::warn("row: ", Dumper($row));
			process_row($db, $row);
		}
		$db->disconnect;
	};

	if ($@ =~ /timed out/i) {
		print STDOUT "Timed Out.\r\n";
		return;
	}
}


sub getUrl {
    my $url = shift;
    my $response;
    eval {
        local $SIG{ALRM} = sub { die "590 timeout"; };
        alarm 20;
        $response = $ua->get($url);
        alarm 0;
    };

    if ($@ && $@ =~ /590 timeout/) {
    print ("Execution Timeout !!!");
        return HTTP::Response->new(590, "Execution Timeout"); # return false on a timeout.
    }

    return $response;
}

sub process_row {
		my($db, $row) = @_;

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

		# unit
		my $url = 'sev?' . enurl({
			op => 52, type => 'R', 
			msisdn => $msisdn, value => $row->{nominal},
			pin => $row->{pin},
			modem => $row->{modem},
			ts => $row->{exec_ts}, qty => $row->{topup_qty},
		});

		# nominal
		unless ($row->{nominal}) {
			$url = 'sms?' . enurl({
				to => '461',
				ts => $row->{exec_ts},
				text => join(' ', 'DOMPUL', $row->{topup_qty}, $msisdn, $row->{pin}),
				modem => $row->{modem},
			});
		}

		$url = $row->{site_url}."/send".$url."&username=app1&password=1234";
		daemon::warn($url);

		# hit jj
		#my $ua = LWPx::ParanoidAgent->new;
		#$ua->whitelisted_hosts(qr/^10\./ ,qr/^192\./, '127.0.0.1');
		#$ua->timeout(10);

		#my $resp = $ua->get($url);
		my $resp = getUrl($url);
		daemon::warn($resp->status_line, ' : ', $resp->content, ' : ', $resp->message);

		my $topup_status = 'P';
		my $err_msg = undef;
		unless ($resp->is_success or $resp->message =~ /timeout/i) {
			########## sgo mandiri ##########
			# jika payament_gateway tidak sama dengan 0 dianggap transaksi sgo mandiri
			# tidak ada reversal otomatis karena trx diwajibkan sukses mau bagaimanapun kondisinya
			if($row->{payment_gateway} eq 0){ # normal trx
				my $trx = daemon::trx->new($db);
				$trx->reversal($trans_id);
				$db->commit;
				next;
			}else{ # sgo trx
				$topup_status = 'F';
				$err_msg = $resp->content;
			}
		}

		$db->update("topup", {topup_status=>$topup_status, error_msg => $err_msg}, {trans_id=>$trans_id});
		$db->commit;
}

