package view::setting;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub admin_log {
	my ($s,$q,$db,$log) = @_;
	
	my $from = $q->param('from');
	my $until = $q->param('until');
	
	my $res = $s->q_pager(<<"EOS",
		select admin_log_ts, args, inet_ntoa(ip) as ip_address, admin_name, path, path_title
from admin_log
		inner join admin using (admin_id)
		inner join page using (page_id)
EOS
	filter =>{
		from       => "admin_log_ts >= str_to_date(?,'%d-%m-%Y')",
		until      => "admin_log_ts < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day)",
		admin_name => "admin_name = ?",
		path       => "path = ?",
	},
	suffix => 'order by admin_log_id desc'
	);
	
	return{
		list       => $res->{list},
		nav        => $res->{nav},
		from       => $from,
		until      => $until,
		admin_name => $q->param('admin_name') || '',
		path       => $q->param('path') || '',
	}
}

sub reg_list {
	my ($s,$q,$db,$log) = @_;
	
	my $number = $q->param('number');
	my $from = $q->param('from');
	my $until = $q->param('until');
	my $status = $q->param('status') || '';
	my($active,$no,$approve) = '';
	if($status eq 'Active'){
		$active='selected';
	}elsif($status eq 'non-Active'){
		$no ='selected';
	}elsif($status eq 'Approve'){
		$approve ='selected';
	}

	my $res = $s->q_pager(<<"EOS",
	select perdana_id, ts_perdana, perdana_number, status, note from msisdn_perdana
EOS
	filter =>{
		from       => "ts_perdana >= str_to_date(?,'%d-%m-%Y')",
		until      => "ts_perdana < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day)",
		number     => "perdana_number = ?",
		status     => "status=?",
	},
	suffix => 'order by perdana_id desc'
	);

	return {
		r_args     => $s->{r}->args,
		list       => $res->{list},
		nav        => $res->{nav},
		number 	   => $number,
		from       => $from,
		from_status=> $from,
		until      => $until,
		active     => $active,
		no         => $no,
		approve    => $approve,
	}
}

sub reg_command {
	my ($s,$q,$db,$log) = @_;
	my $res = $s->q_pager(<<"EOS",
	select cmd_id, cmd_name, type, command, receiver from perdana_cmd
EOS
	);
	my $modem = $s->q_pager(<<'EOS',
select modem_id, modem_name, status, pin, case status when 'Active' then 'non-Active' when 'non-Active' then 'Active' end as upd_status from modem
EOS
	);

	return {
		cmd       => $res->{list},
		nav        => $res->{nav},
		modem	=> $modem->{list},

	}
}

1;
