package view::aktivasi;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub form {
	my ($s,$q,$db,$log) = @_;
	my $error = $q->param('error')||'';
	return {
		error => $error,
	}
}

sub list {
	my ($s,$q,$db,$log) = @_;
	my $from = $q->param('from');
	my $until = $q->param('until');
	
	my @status_options = (
                        {value=>'W', display=>'Waiting'},
                        {value=>'P', display=>'Pending'},
                        {value=>'S', display=>'Success'},
			{value=>'F', display=>'Failed'},
                        );
        $_->{selected} = $_->{value} eq ($s->param('rs_req_status')||'') ? 1:0 foreach @status_options;
	
	my $list = $s->q_pager(<<'EOS',
select rs_req_id, sd_number, modem, rs_req_number, rs_req_response, rs_req_status, rs_req_ts, site_name
from rs_request
  inner join sd_chip using (sd_id)
  inner join site using (site_id)
EOS
	 filter => {
		from => "rs_req_id >= ?",
		until => "rs_req_id < ?+1",
		rs_req_ts_from => "date(rs_req_ts) >= str_to_date(?,'%d-%m-%Y')",
                rs_req_ts_until => 'date(rs_req_ts) < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
                sd_number => "sd_number = ?",
		rs_number => "rs_req_number = ?",
		rs_req_response => "rs_req_response like concat(?,'%')",
		rs_req_status => "rs_req_status = ?",
                site_name => "site_name like concat(?,'%')",
		modem => "modem like concat(?,'%')",
	},
	suffix => 'order by rs_req_id desc',
	);
	
	return {
		r_args=> $s->{r}->args,
		from => $from,
		until => $until,
		rs_req_ts_from => $q->param('aktivasi_ts_from')||'',
		rs_req_ts_until => $q->param('aktivasi_ts_until')||'',
		rs_req_status_options => \@status_options,
		sd_number => $q->param('sd_number')||'',
		rs_number => $q->param('rs_number')||'',
		rs_req_response => $q->param('rs_req_response')||'',
		modem => $q->param('modem')||'',
		site_name => $q->param('site_name')||'',
		list_report => $list->{list},
		nav => $list->{nav},
	};
}

1;
