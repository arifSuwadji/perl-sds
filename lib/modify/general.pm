package modify::general;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub setting {
	my ($s, $q, $db, $log) = @_;
	my @checkbox = $q->param('config_id');
	$log->warn(@checkbox) if @checkbox;
	return '/view/general/setting' unless @checkbox;
	foreach (@checkbox) {
        	my ($name) = $db->query("select config_name from config where config_id=?", $_)->list;
	$log->warn($name);
                my $value = $q->param($name);
          	$log->warn("update config set config_value=$value where config_id=$_");
		$s->query(
	               'update config set config_value=? where config_id=?',
	     	$value, $_
		);
	}
	return '/view/general/setting';
}

1;
