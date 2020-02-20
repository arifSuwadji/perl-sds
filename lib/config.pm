package config;
use strict;
use warnings;

our @db_conn = ('DBI:mysql:sds_alintas;host=localhost', 'root', '');
our $free_canvasser=1;
our $username = '628159973284';
our $smsc = 'APPROVE';
our $topup_owner_free;
our $waiting_approve;#=1;
our $stockbase_admin;#=1;
our $adm_gid= 5;#=5;
our $take_price = 1; # for pricing
our $skip_approval = 1;
our $use_smsc;# = 1; # for sms site
our $topup_web_empty;# = 1;
our $need_check_quota;# = 0; 
our $reg_user_id = 1;
our $akses_request;# = 1;

1;

