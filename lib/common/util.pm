package common::util;
use strict;
use warnings FATAL => 'all';
use warnings 'redefine';

use POSIX ();

sub now {
	my $format = $_[0]||'%Y-%m-%d %H:%M:%S';
        POSIX::strftime($format, CORE::localtime);
}

1;
