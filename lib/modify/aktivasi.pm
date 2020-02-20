package modify::aktivasi;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use CGI::Enurl;
use common::util();
use daemon::trx;
use common();

sub form {
	my ($s, $q, $db, $log) = @_;
	
	my $rs_req_number = $q->param('rs_req_number');
	my $sd_number = $q->param('sd_number');
	eval {
		my ($sd_id) = $db->query('select sd_id from sd_chip where sd_number=?',$sd_number)->list; 
		$db->query("insert into rs_request(rs_req_number, sd_id) values(?,?)", $rs_req_number, $sd_id);
	};
	if ($@) {
		return "/view/aktivasi/form?error=$@";
	}
	my $ymd = common::util::now('%d-%m-%Y');
	return "/view/aktivasi/list?rs_req_ts_from=$ymd&rs_req_ts_until=$ymd";
}

1;
