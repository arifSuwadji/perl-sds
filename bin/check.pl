use strict;
use lib "$ENV{HOME}/lib";
use daemon::util ();

our $revision = '$Id: check-sample.pl,v 1.1 2012/07/27 03:24:25 fat Exp $';

chdir "$ENV{HOME}/bin";
	#timeout
	#topup
	#topup-slow-queue
	#stock/dompul
	#sms-outbox
	#report
foreach my $daemon (qw|
	deposit
    approval
|) {
  system("./$daemon.pl >> /log/sds/$daemon.log 2>&1 &")
  unless daemon::util::find_in_ps("$daemon.pl");
}

system("./httpd -f /home/software/sds/etc/httpd.conf") unless daemon::util::find_in_ps('\./httpd');

