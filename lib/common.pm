package common;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use POSIX();

sub commify {
	local $_  = shift;
	my $separator = shift||',';
	1 while s/^([-+]?\d+)(\d{3})/$1$separator$2/;
	return $_;
}

sub today {
        my $format = $_[0]||'%d-%m-%Y';
        POSIX::strftime($format, CORE::localtime);
}

sub now {
	my $format = $_[0]||'%Y-%m-%d %H:%M:%S';
	POSIX::strftime($format, CORE::localtime);
}

1;

