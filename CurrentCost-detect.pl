#!/usr/bin/perl -w
# Current Cost autodetection script
# Copyright (C) 2010 W R Younger.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################
#
# This script looks to see if it can find a CurrentCost device
# attached to a USB serial port, and if so invokes CurrentCost.pl
# to monitor it indefinitely.
#
# Before running this script for the very first time, you must (once) run:
#     CurrentCost.pl --create-rrd
#
# Normally, you would run this script from /etc/crontab with a line like:
#     @reboot root /usr/local/rrd/CurrentCost-detect.pl

use strict;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use Fcntl;
use lib "/usr/local/rrd";
use SerialLock;

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

