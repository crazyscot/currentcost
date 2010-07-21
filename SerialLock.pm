#

package SerialLock;

use strict;
use warnings;
our $VERSION = '0.1';
use base 'Exporter';
our @EXPORT = qw/slock sunlock/;
use Carp;

=head1 SerialLock

SerialLock - serial port locking

=head1 SYNOPSIS
	use SerialLock;
	lock("/dev/ttyUSB0");
	lock("/dev/ttyUSB0", 1); # fails
	lock("/dev/ttyUSB0", 0); # waits forever
	unlock("/dev/ttyUSB0");

=head2 Functions

=head3 lock(port)

Locks the given port and returns 1. If the port is already locked, returns 0.

=head3 unlock(port)

Unlocks the given port.
You may want to set up a die handler to call this.

=cut

use Fcntl qw(:flock SEEK_END);

sub slock($) {
	my $dev = shift;
	unless (-c $dev) {
		carp "No such device";
		return 0;
	}
	$dev =~ s,/dev/,,;
	my $lck = "/var/lock/LCK..".$dev;

	return 0 if -f $lck;
	# TODO determine whether lock is stale and try to override it

	unless (open(LF, "+>$lck")) {
		carp "cannot open $lck";
		return 0;
	}
	my $rv=0;

	if (flock(LF, LOCK_EX)) {
		my $me = $0;
		$me =~ s,.*/,,;
		my $u = (getpwuid($<))[0];
		printf LF "%05u %s %s\n",($$,$me,$u);
		$rv=1;
	} else {
		carp "cannot flock $lck";
	}

	close LF;
	return $rv;
}

sub sunlock($) {
	my $dev = shift;
	unless (-c $dev) {
		carp "No such device";
		return 0;
	}
	$dev =~ s,/dev/,,;
	my $lck = "/var/lock/LCK..".$dev;

	return 0 unless -f $lck;

	unless (open(LF, "+<$lck")) {
		carp "cannot open $lck";
		return 0;
	}
	my $rv=0;

	if (flock(LF, LOCK_EX)) {
		$rv= (unlink $lck);
		carp "cannot unlink $lck" unless 1==$rv;
	} else {
		carp "cannot flock $lck";
	}

	close LF;
	return $rv;
}

1;
