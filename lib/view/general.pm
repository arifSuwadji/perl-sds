package view::general;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub setting {
	my ($s,$q,$db,$log) = @_;
	my $list = $s->sql_list(<<"EOS"
select config_id, config_name,3=config_id as percent1, 4=config_id as percent2, 2=config_id as pertrx, 5=config_id as sms_interval, 6=config_id as trx_brake_interval, config_value from config 
EOS
	);
	
	return {
		list_config => $list,
	};
}

1;

