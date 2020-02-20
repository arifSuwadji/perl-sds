package service;
# sms adapter module : not part of core/trx processing module
# several types of messaging gtw (CRM) : sms, h2h, web

use strict;
use warnings FATAL => 'all';
no warnings 'redefine';
use config();

use DBIx::Simple ();
use SQL::Abstract ();
use XML::Simple;

use Apache2::Request ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Const -compile => qw(:common);
use Apache2::Log ();


sub handler {
	my $r = shift;

	# initialize objects
	my $log = $r->server->log();
	my $q = Apache2::Request->new($r);
	my $db = DBIx::Simple->connect('DBI:mysql:sds;host=localhost', 'root', '', {RaiseError => 1, AutoCommit => 1});
	$db->abstract = SQL::Abstract->new();

	# http://localhost:8181/service?msisdn=..&msg=s.1234&ts=..&smsc=...
	my $smsc = $q->param('smsc') || '';
	
	unless ($smsc eq $config::smsc or $smsc eq '') {

		#1. smsc validation
		my $smsc_id = $db->query('select smsc_id from smsc where smsc_name=?', $smsc)->list;
		unless ($smsc_id) {
			$log->warn("smsc=$smsc invalid");
			return Apache2::Const::FORBIDDEN;
		}

		# 2. msisdn
		my $msisdn = $q->param('msisdn') || '';
		my ($user_id, $pin, $status, $member_id, $outlet_id) = $db->query(
			'select user_id, pin, status, member_id, outlet_id from user where username=? and user.status=1',
			$msisdn,
		)->list;
		if($config::outlet_send_request){
			unless($member_id){
				$member_id = $db->query("SELECT member_id FROM rs_chip WHERE outlet_id=?", $outlet_id)->list;
			}
		}
		my $rs_id;
		my $msg = $q->param('msg') || '';
		unless ($user_id) {
			#check command
			my $check_command = $db->query("select cmd_name from perdana_cmd");
			my @command;
			while(my $row = $check_command->hash){
				push @command, $row->{'cmd_name'};
			}
			my $find_cmd = 0;
			foreach(@command){
				my $cmd = lc($_);
				if(lc($msg) =~ /^$cmd/){
					$find_cmd = 1;
					last;
				}
			}
			if ($find_cmd){
				$user_id = $config::reg_user_id;
				if ($msg !~ /\./){$msg = $msg.".$msisdn";}
			} else {
			$log->warn("msisdn or username = $msisdn invalid");
			return Apache2::Const::FORBIDDEN;
			}
		}
		
		# 3. ts
		my $ts = $q->param('ts') || '';
		unless ($ts =~ /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/) {
			$log->warn("ts = $ts invalid");
			return Apache2::Const::FORBIDDEN;
		}

		# 4. msg
		unless ($msg) {
			$log->warn("msg is empty");
			return Apache2::Const::FORBIDDEN;
		}
		# 5. adm_id
		my $adm_id = $q->param('adm_id') || '';

		### Parameter Validation DONE ########

		# insert incoming message into db....
		# $db->insert(....
	
		# $log->warn("insert into sms (smsc_id, sms_int, user_id, sms_time) values($smsc_id, $msg, $user_id, $ts)");
		# $msg =~ s/\.//g;
		my $sms_interval = $db->query("select config_value from config where config_id = 5")->list; #config_id = 5 untuk repeated sms interval
		my $found_repeated = $db->query(
			"select sms_id from sms where sms_int=? ".
			"and sms_time > date_sub(now(), interval ? minute) and user_id=?",
			$msg, $sms_interval, $user_id,
		)->list;

		if ($found_repeated) {
			$log->warn("same msg occurs from 0 until $sms_interval minutes");
			return Apache2::Const::FORBIDDEN;
		}

		my $response;
		my $sms_id;
		if ($rs_id) {
			$log->warn('process sms from rs');
			eval { 
				$db->query("insert into sms_rs (sms_int, rs_id, sms_time, in_smsc_id) values(?,?,?,?)", $msg, $rs_id, $ts, $smsc_id);
			};
			if ($@) {
				$log->warn($@);
				
			} else {
	                        return Apache2::Const::OK;
			}		
		} else {
	
			$db->query("insert into sms (smsc_id, sms_int, user_id, sms_time, sms_localtime) values(?,?,?,?,now())", $smsc_id, $msg, $user_id, $ts);
			$sms_id = $db->last_insert_id(undef, undef, 'sms', 'sms_id');
			$log->warn("sms id =", $sms_id);
			$response = process($db, $log, {
				ts        => $ts,        msg    => $msg,          user_id => $user_id,
				pin       => $pin,       adm_id => $adm_id,       sms_id  => $sms_id,
				member_id => $member_id, outlet_id => $outlet_id,
			});
		}
	
		if (ref $response eq 'HASH') {
			if ($response->{sms_outbox}) {
				$db->insert('sms_outbox', {
					sms_id  => $sms_id,  out_msg => $response->{sms_outbox}, out_status => 'W',
					user_id => $user_id, out_ts  => \['now()'],
				});
				# smsc-id is set by sms-outbox.pl to reduce lock-contention
			}
			if ($response->{sms_outbox_rs}) {
				eval {
					$db->insert('sms_outbox_rs', {
						sms_id => $sms_id, out_msg => $response->{sms_outbox_rs}, out_status => 'W',
						rs_id => $response->{rs_id}, out_ts => \['now()'],
					});
				};
				if ($@) {
					$log->warn($@);
				}
			}
		} else {
			$db->insert('sms_outbox', {
				sms_id => $sms_id, out_msg => $response, out_status => 'W',
				user_id => $user_id, out_ts => \['now()'],
			});
		}
	
		$r->print(XMLout($response, NoAttr => 1, RootName => "response"));
		return Apache2::Const::OK;
		
	} else {
		eval { 
                	# entry harga x5 tipe retail dari 5200.000 menjadi 5150.000. Untuk approval: forward sms ini
                	my $text = $q->param('msg')||'';
			unless ($text) {
				$log->warn("msg is empty");
				return Apache2::Const::FORBIDDEN;
			}
	                my ($keyword, $type_name, $price)= $text =~ m/entry harga (\w+) tipe retail dari (\d+) menjadi (\d+\.\d+)/;
        	        my ($stock_ref_id) = $db->query('select stock_ref_id from stock_ref where keyword=?', $keyword)->list;
                	my ($rs_type_id) = $db->query('select rs_type_id from rs_type where type_name=?', $type_name)->list;
	                $db->query("replace into pricing_temporary (stock_ref_id, rs_type_id,price, save_time, price_type) value (?,?,?,now(),'NEW')",$stock_ref_id, $rs_type_id, $price);
        	};

	        if ($@) {
        	        # an error occured, or there are some errors
	                die($@);
                	return Apache2::Const::SERVER_ERROR;
        	}
	        $r->print("OK");
        	return Apache2::Const::OK;
	}
}
sub process2 {
	my ($db, $log, $param) = @_;
	$db->query('insert into');
}
sub process {
	# without any xml processing routine
	# has no access to Apache2::IO handle object
	my ($db, $log, $param) = @_;


	######### START PROCESSING #####################

	my @msg = split /\./, $param->{msg};

	my %map = (
		GP   => 'service::info::change_pin', # change pin
		S    => 'service::info::balance', #cek saldo
		HELP => 'service::info::complain', #complain
		REP  => 'service::info::report', #report untuk transaksi
		M    => 'service::trx::multi', #transaksi multi
		MC   => 'service::trx::multi_c', #transaksi multi, credit
		P    => 'service::trx2::package', #paket produk
		M2   => 'service::trx::multi_two', #transaksi multi untuk keyword produk lengkap
		SAL  => 'service::info::outlet_balance', #cek saldo outlet
		CI   => 'service::info::check_payment', #cek pelunasan invoice
		DS   => 'service::info::dompul_sale', # penjualan voucher dompul
		TD   => 'service::trx::transfer', #transfer saldo
		REG  => 'service::info::reg_perdana', # registrasi perdana
		TM   => 'service::trx::sgo_mandiri',#transaksi sgo mandiri
		CT   => 'service::info::sgo_token',#konfirmasi token sgo mandiri
	);

	my $pin_segment = $#msg;
	
	$msg[0] =~ s/(\w+)/\U$1/;
	#check command
	$log->warn("original message : ", join('.',@msg));
	my $check_command = $db->query("select cmd_name from perdana_cmd");
	my @command;
	while(my $row = $check_command->hash){
		push @command, $row->{'cmd_name'};
	}
	my $find_cmd = 0;
	foreach(@command){
		my $cmd = lc($_);
		if(lc($param->{msg}) =~ /^$cmd\./){
			$find_cmd = 1;
			last;
		}
	}
	if($find_cmd){
		#replace first message with REG
		$msg[0] = 'REG';
		$log->warn("after change to reg perdana : ", join('.',@msg));
	}

	# keyword registered ?
	my $subref = $map{$msg[0]};
	unless ($subref) {
		my ($exist) = $db->query('select keyword from stock_ref where keyword=?', $msg[0])->list;
		if ($exist) { 
			$subref ='service::trx::topup';
			$pin_segment = 3;
		}
		else { 
			return 'keyword sms tidak dikenal';
		}
	}

	# pin, usually the last part
	unless($find_cmd){
		if($msg[0] eq 'TM'){
			$pin_segment -= 1;
		}
		if ($msg[$pin_segment] ne $param->{pin}) {
			return 'pin yg anda ketik salah';
		}
	}

	# package validation
	my ($package) = ($subref =~ /([\w:]+)::\w+$/);
	eval "require $package";
	if ($@) {
		$log->warn($@);
		return 'keyword sms belum bisa dilayani 1';
	}

	$subref = eval '\&'.$subref;
	#$log->warn("subref is now a code ref");

	my $ret = eval{ &$subref($db, $log, $param, \@msg) };
	# utk bb: eval{ &$subref($s, $r, $q, $db, $log) };
	#$log->warn("code ref executed");

	if ($@) {
		# an error occured, or there are some errors
		$log->warn($@);
		return 'keyword sms belum bisa dilayani 2';
	}

	return $ret;
}


1;
# vim: ts=4
