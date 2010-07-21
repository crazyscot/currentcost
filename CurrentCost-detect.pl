#!/usr/bin/perl -w

# Reads data from a Current Cost device via serial port.
# Run me from /etc/crontab with a line like:
#     @reboot root /usr/local/rrd/CurrentCost.pl

use strict;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use Fcntl;
use SerialLock;

#die "port not specified" unless defined $PORT and -c $PORT;
# TODO: If multiple ttyUSBs around, autodetect which is which...

my $BAUD = "57600";
my $SERIALBUFSIZE = 200;
my @ports = `ls /dev/ttyUSB*`;

my $arg = shift @ARGV;
my $dbg = (defined $arg && ($arg eq "--debug"));

my ($PORT,$FOUND);

for $PORT (@ports) {
	chomp $PORT;
	unless (slock($PORT)) {
		warn "port $PORT is locked" if $dbg;
		next
	}
	my $ob = Device::SerialPort->new($PORT);
	unless (-c $PORT && defined($ob)) {
		warn "cannot set up for port $PORT!";
		sunlock($PORT);
		next;
	}

	$ob->baudrate($BAUD);
	$ob->write_settings;
	# TODO check for locks;
	# Lock ports in turn;
	# Trap to unlock

	print "Trying $PORT\n" if $dbg;

	unless (sysopen(SERIAL, "$PORT", O_NONBLOCK|O_RDWR)) {
		warn "opening serial $PORT: $!";
		sunlock($PORT);
		next;
	};

	# wait for up to 10s to read from the port.
	my $bits = '';
	vec($bits, fileno(SERIAL), 1) = 1;
    my $got = select($bits, undef, $bits, 10);

	select(undef,undef,undef,1); # let the data come in, hope there's a big UART

	if ($got) {
		my $line;
		for (my $i=0; $i<4; $i++) {
			my $n = sysread (SERIAL, $line, $SERIALBUFSIZE);
			print "read from $PORT: $line\n" if $dbg;

			if ($line =~ m!<tmpr> *([\-\d.]+)</tmpr>.*<ch1><watts>0*(\d+)</watts></ch1>!) {
				print "Found a CurrentCost on $PORT!\n" if $dbg;
				$FOUND= $PORT;
				last;
			}
		}
	}

	$ob->close or warn "closing $PORT failed: $!";
	close SERIAL or warn "closing $PORT: $!";
	sunlock($PORT);

	last if defined $FOUND;
}

die "No working devices" unless defined $FOUND;

print "OK, using $FOUND\n" if $dbg;
exec("/usr/local/rrd/CurrentCost.pl $FOUND");

