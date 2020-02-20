#!/usr/bin/perl -l
package MyPackage;
use strict;
use warnings FATAL => 'all';
use lib "$ENV{HOME}/lib";

use config;
use daemon;
use daemon::trx;

use CGI::Enurl;
use LWP::UserAgent;
use DBIx::Simple();
use Data::Dumper;
use Data::UUID;
use Digest::SHA qw(sha1 sha1_hex sha1_base64);
use JSON::Parse qw(:all);
use base qw(Net::Server::PreFork);

MyPackage->run({port => 63200, min_servers => 3});

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

		#GET trans id
		my ($trans_id) = ($req =~ /\w\/([^!]+)/);

		my $db = daemon::db_connect();

		my $res = $db->query(<<"EOS");
SELECT outlet_mutation.outlet_id, outlet_name, username as hp_number, outlet_mutation.trans_id, topup.member_id, sum(-mutation) as amount, transaction.trans_date,
topup_ts, exec_ts, topup_status, payment_gateway, group_concat(topup_id) as topup_id, group_concat(keyword,':',topup_qty) as description, token_sgo, error_msg
FROM outlet_mutation 
inner join transaction on transaction.trans_id = outlet_mutation.trans_id
left join topup on topup.trans_id = transaction.trans_id
left join transaction as trans on trans.trans_ref = transaction.trans_id 
inner join rs_chip using(rs_id)
inner join outlet on outlet.outlet_id = rs_chip.outlet_id
left join user on user.outlet_id = outlet.outlet_id
inner join stock_ref using (stock_ref_id)
WHERE outlet_mutation.trans_id in ($trans_id)
EOS
		while (my $row = $res->hash) {
			my $topup_id = $row->{topup_id};
			my $sms_id = $db->query("SELECT sms_id FROM topup_sms WHERE topup_id in ($topup_id)")->list;
			my @topup = split /\,/, $topup_id;
			my $count_topup = scalar(@topup);
			my $count_topup_sms = $db->query("SELECT count(*) FROM topup_sms WHERE sms_id=?", $sms_id)->list;
			if($count_topup ne $count_topup_sms){
				daemon::warn("count topup : ", $count_topup, " not equal with count topup sms : ", $count_topup_sms);
				next;
			}
			daemon::warn("row: ", Dumper($row));
			process_row($db, $row, $trans_id);
		}
		$db->disconnect;
	};

	if ($@ =~ /timed out/i) {
		print STDOUT "Timed Out.\r\n";
		return;
	}
}

sub process_row{
	my($db, $row, $trans_id) = @_;

	my $ug = new Data::UUID;
	my ($result, $url, $rq_uuid, $rq_datetime, $signature, $bank_code, $comm_code, $member_code, $msisdn, $desc, $order_id, $resp, $content) = "";
	my %params;
	my $ua = LWP::UserAgent->new;
	$ua->ssl_opts(verify_hostname => 0);

	if($row->{topup_status} eq 'WT'){
		$url = $config::sgo_ip."/rest/server/requesttoken";
		$rq_uuid = $config::sgo_commcode;
		$rq_uuid .= $ug->create_from_name_str($row->{outlet_id}, $row->{topup_ts});
		$rq_datetime = $row->{topup_ts};
		$bank_code = $config::sgo_bankcode;
		$comm_code = $config::sgo_commcode;
		$member_code = $config::sgo_memcode;
		$msisdn = $row->{hp_number};
		$desc = $row->{'description'};
		$order_id = $row->{'topup_id'};
		$row->{amount} =~ s/\.0*$//;
		$signature = sha1_hex($rq_uuid.$comm_code.$order_id.$row->{amount}.$config::sgo_passwd);
		%params = ( rq_uuid     => $rq_uuid,
		            rq_datetime => $rq_datetime,
		            signature   => $signature,
		            bank_code   => $bank_code,
		            comm_code   => $comm_code,
		            member_code => $member_code,
		            msisdn      => $msisdn,
		            amount      => $row->{amount},
		            desc        => $desc,
		            order_id    => $order_id,
		            ccy_id      => 'IDR',
		);
		daemon::warn("request url : ", $url);
		daemon::warn("request params : ", %params);
		#hit sgo mandiri
		$resp = $ua->post($url, \%params);
		#respons
		$content = $resp->content;
		daemon::warn("respons : ", $content);
		#$content =~ s/errorCode"/"errorCode"/; # just for test
		eval {
			assert_valid_json ($content);
		};
		if ($@) {
			daemon::warn("Respons JSON was invalid: $@");
			next;
		}
			
		$result = parse_json($content);
		daemon::warn('dumper result : ', Dumper $result);
		my @topup = split /,/, $row->{topup_id};
		# respons : {"error_code":"0001","error_msg":"Invalid Signature"}
		if($result->{error_code} ne '0000'){
			foreach(@topup){
				my $trx = daemon::trx->new($db, $_);
				$trx->error_msg($result->{error_code}.":".$result->{error_msg});
			}
			next;
		}
		#update table topup
		foreach(@topup){
			my $trx_sgo = $result->{trx_id};
			$db->query("UPDATE topup SET topup_status='CT', error_msg=? WHERE topup_id=?", $trx_sgo, $_);
		}
	}elsif($row->{topup_status} eq 'CT'){
		$url = $config::sgo_ip."/rest/server/confirmtoken";
		unless($row->{token_sgo}){
			daemon::warn("token sgo is empty, please contact canvasser to confirm");
			next;
		}
		$rq_uuid = $config::sgo_commcode;
		$rq_uuid .= $ug->create_from_name_str($row->{outlet_id}, $row->{exec_ts});
		$rq_datetime = $row->{topup_ts};
		$comm_code = $config::sgo_commcode;
		$order_id = $row->{'topup_id'};
		daemon::warn("signature : ". $rq_uuid."|".$comm_code."|".$row->{token_sgo}."|".$order_id."|".$config::sgo_passwd);
		$signature = sha1_hex($rq_uuid.$comm_code.$row->{token_sgo}.$order_id.$config::sgo_passwd);
		daemon::warn("sha signature : ", $signature);

		%params = ( rq_uuid     => $rq_uuid,
		            rq_datetime => $rq_datetime,
		            comm_code   => $comm_code,
		            signature   => $signature,
		            token_id    => $row->{token_sgo},
		            order_id    => $order_id,
		);
		daemon::warn("Confirm Token url : ", $url);
		daemon::warn("Confirm Token params : ", %params);
		#hit sgo mandiri
		$resp = $ua->post($url, \%params);
		#respons
		$content = $resp->content;
		daemon::warn("Confirm respons : ", $content);
		#$content =~ s/errorCode"/"errorCode"/; # just for test
		eval {
			assert_valid_json ($content);
		};
		if ($@) {
			daemon::warn("Confirm Respons JSON was invalid: $@");
			next;
		}

		$result = parse_json($content);
		daemon::warn('dumper Confirm result : ', Dumper $result);
		my @topup = split /,/, $row->{topup_id};
		# respons : {"error_code":"0001","error_msg":"Invalid Signature"}
		if($result->{error_code} ne '0000'){
			foreach(@topup){
				my $trx = daemon::trx->new($db, $_);
				$trx->error_msg($row->{error_msg}." | ".$result->{error_code}.":".$result->{error_msg});
			}
			next;
		}
		#update table topup
		foreach(@topup){
			$db->query("UPDATE topup SET topup_status='W' WHERE topup_id=?", $_);
		}
	}
}
