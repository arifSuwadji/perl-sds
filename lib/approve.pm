package approve;
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

sub handler {
	my $r = shift;

	my $q   = Apache2::Request->new($r);
	my $db  = DBIx::Simple->connect('DBI:mysql:sds;host=localhost', 'root', '', {RaiseError => 1, AutoCommit => 1});
	my $log = $r->server->log();

	my %arg;
	foreach (qw/msisdn ts msg smsc/) {
		$arg{$_} = $q->param($_);
		unless (defined($arg{$_})) {
			$log->warn("sms report ignored: param '$_' unspecified");
			return Apache2::Const::SERVER_ERROR;
		}
	}
	
	unless ($arg{smsc} ne $config::smsc) {
		$log->warn('smsc : ', $arg{smsc});
                return Apache2::Const::SERVER_ERROR;
	}
	
	unless ($arg{msisdn} = $config::username) {
		$log->warn('msisdn : ', $arg{msisdn});
		return Apache2::Const::SERVER_ERROR;
	}	
	
	eval{ 
		# entry harga x5 tipe retail dari 5200 menjadi 5150. Untuk approval: forward sms ini
		my $text = $arg{msg};
		my ($keyword, $type_name, $price)= $text =~ m/entry harga (\w+) tipe retail dari (\d+) menjadi (\d+)/; 
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

1;

