package daemon::util;
use strict;
use warnings FATAL => 'all';

sub find_in_ps {
  my $cmd_pattern = shift;
  open(my $FH, '-|', 'ps x');
  while (<$FH>) {
    chomp;
    my %ps;
    @ps{qw/pid         tty          stat       since     cmd/} =
      ($_ =~ /(\d+)\ +([\w\/\?]*)\ +([^\ ]*)\ +([^\ ]*)\ +([\w\W]*)/);
    next unless $ps{cmd}; #skip first row
    return \%ps if $ps{cmd} =~ /$cmd_pattern/;
  }
  close $FH;
  return;
}


1;
