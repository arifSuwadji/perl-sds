package report;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use DBIx::Simple ();
use SQL::Abstract ();

use Apache2::Const -compile => qw(:common);
use Apache2::Request ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Log ();

use report::sms ();
use report::ussd ();


sub handler {
	my $r = shift;

	my $q   = Apache2::Request->new($r);
	my $db  = DBIx::Simple->connect('DBI:mysql:sds;host=localhost', 'root', '', {RaiseError => 1, AutoCommit => 1});
	my $log = $r->server->log();

	#$log->warn("uri: ", $r->uri);
	my $sub;
	if ($r->uri =~ /\/report\/sms/) {
		$sub = \&sms;
	}
	elsif ($r->uri =~ /\/report\/ussd/) {
		$sub = \&ussd;
	}
	elsif ($r->uri =~ /\/report\/reg_sms/) {
		$sub = \&reg_sms;
	}
	elsif ($r->uri =~ /\/report\/reg_ussd/) {
		$sub = \&reg_ussd;
	}
	else {
		$log->warn('uri not registered');
		return Apache2::Const::NOT_FOUND;
	}

	my $ret = eval{ &$sub($q, $db, $log) };

	if ($@) {
		# an error occured, or there are some errors
		$log->warn($@);
		return Apache2::Const::SERVER_ERROR;
	}

	$r->print("OK");
	return Apache2::Const::OK;
}

sub sms {
	my ($q, $db, $log) = @_;
	my %arg;
	foreach (qw/msisdn ts msg smsc/) {
		$arg{$_} = $q->param($_);
		unless (defined($arg{$_})) {
			$log->warn("sms report ignored: param '$_' unspecified");
			return;
		}
	}

	my ($sd_id, $type) = $db->query(<<"EOS", $arg{smsc})->list;
select sd_id, ref_type_id
from stock_ref_type inner join sd_chip using (ref_type_id)
where sd_name=?
EOS
	my %api = (
		1 => \&report::sms::dompul,
		3 => \&report::sms::sev,
		4 => \&report::sms::esia,
		5 => \&report::sms::three,
		6 => \&report::sms::smart,
		7 => \&report::sms::fkios,
	#	10 => \&report::sms::sevdkpp,
		11 => \&report::sms::sevnusapro,	
	);
	my $sub = $api{$type};
	unless ($type and $sub) {
		$log->warn('report ignored: ', $arg{smsc});
	}

	$arg{sd_id} = $sd_id;
	my $ret = eval{ &$sub($q, $db, $log, \%arg) };

	if ($@) {
		# an error occured, or there are some errors
		die($@);
	}
}

sub ussd {
	my ($q, $db, $log) = @_;
	my %arg;

	foreach (qw/status info modem ts timing timing2 msisdn/) {
		$arg{$_} = $q->param($_);
		next if $_ =~ /timing2|msisdn/; # non mandatory
		unless (defined($arg{$_})) {
			$log->warn("report ignored: param '$_' empty");
			return;
		}
	}

	my ($sd_id, $type) = $db->query(<<"EOS", $arg{modem})->list;
select sd_id, ref_type_id
from stock_ref_type inner join sd_chip using (ref_type_id)
where sd_name=?
EOS
	my %api = (
		1 => \&report::ussd::dompul,
		2 => \&report::ussd::mkios,
		3 => \&report::ussd::sev,
	#	5 => \&report::ussd::three,
		8 => \&report::ussd::axis,
	);
	my $sub = $api{$type};
	unless ($type and $sub) {
		$log->warn('report ignored: ', $arg{smsc});
	}

	$arg{sd_id} = $sd_id;
	my $ret = eval{ &$sub($q, $db, $log, \%arg) };

	if ($@) {
		# an error occured, or there are some errors
		die($@);
	}
}

sub reg_sms {
	my ($q, $db, $log) = @_;
	my %arg;
	foreach (qw/msisdn ts msg smsc/) {
		$arg{$_} = $q->param($_);
		unless (defined($arg{$_})) {
			$log->warn("sms report ignored: param '$_' unspecified");
			return;
		}
	}

	my ($sd_id, $type) = $db->query(<<"EOS", $arg{smsc})->list;
select modem_id from modem where modem_name=?
EOS
	#Transaksi dgn No. 15011827603170 berhasil utk pengisian pulsa ke 6287782378339 sebesar (10000).Sisa Dompet Pulsa Anda skrg: (173).
	
	my ($number) = ($arg{msg} =~ /ke\s+(\d+)\s+/);
	unless ($number) {
		$log->warn("sms report ignored id msisdn_perdana not found");
	}else{
		$log->warn("sms update note msisdn perdana");
		my $message = $arg{ts}." ".$arg{msg};
		$db->query("update msisdn_perdana set note=?, status='non-Active' where perdana_number=?",$message,$number);
		$log->warn("sms done");
	}
}

sub reg_ussd {
	my ($q, $db, $log) = @_;
	my %arg;
	# Layanan HotRod 3G+ Bulanan, Rp5rb, 100MB(3G Only) no. 62817224611 telah berhasil diaktifkan. Terima kasih atas kerjasama Anda.
	
	foreach (qw/msg smsc modem_id ts msisdn/) {
		$arg{$_} = $q->param($_);
		next if $_ =~ /msisdn/; # non mandatory
		unless (defined($arg{$_})) {
			$log->warn("report ignored: param '$_' empty");
			return;
		}
	}

	my ($number) = ($arg{msg} =~ /no.\s+(\d+)\s+/);
        unless ($number) {
                $log->warn("ussd report ignored id msisdn_perdana not found");
        }else{
		$log->warn("ussd update note msisdn perdana");
        	my $message = $arg{ts}." ".$arg{msg};
	        $db->query("update msisdn_perdana set note=?, status='non-Active'  where perdana_number=?",$message, $number);
        	$log->warn("ussd done");
	}
}

1;

