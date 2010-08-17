#!/usr/bin/perl -w

# Reads data from a Current Cost device via serial port.
# Run me from /etc/crontab with a line like:
#     @reboot root /usr/local/rrd/CurrentCost.pl

use strict;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use lib "/usr/local/rrd";
use SerialLock;

my $BAUD = "57600";
my $RRD = "/var/lib/collectd/rrd/currentcost.rrd";

my $a = shift @ARGV;
if (defined $a && $a eq "--create-rrd") {
my $cmd = <<EOT;
mkdir -p `dirname $RRD`
rrdtool create "$RRD" --step 6 \\
DS:Power:GAUGE:180:0:U \\
DS:Temperature:GAUGE:180:U:U \\
RRA:AVERAGE:0.5:1:3200 \\
RRA:AVERAGE:0.5:6:3200 \\
RRA:AVERAGE:0.5:36:3200 \\
RRA:AVERAGE:0.5:144:3200 \\
RRA:AVERAGE:0.5:1008:3200 \\
RRA:AVERAGE:0.5:4320:3200 \\
RRA:AVERAGE:0.5:52560:3200 \\
RRA:AVERAGE:0.5:525600:3200 \\
RRA:MIN:0.5:1:3200 \\
RRA:MIN:0.5:6:3200 \\
RRA:MIN:0.5:36:3200 \\
RRA:MIN:0.5:144:3200 \\
RRA:MIN:0.5:1008:3200 \\
RRA:MIN:0.5:4320:3200 \\
RRA:MIN:0.5:52560:3200 \\
RRA:MIN:0.5:525600:3200 \\
RRA:MAX:0.5:1:3200 \\
RRA:MAX:0.5:6:3200 \\
RRA:MAX:0.5:36:3200 \\
RRA:MAX:0.5:144:3200 \\
RRA:MAX:0.5:1008:3200 \\
RRA:MAX:0.5:4320:3200 \\
RRA:MAX:0.5:52560:3200 \\
RRA:MAX:0.5:525600:3200
EOT
	system($cmd);
	exit 0;
}

my $PORT = $a;
die "port not specified" unless defined $PORT;
die "port $PORT does not exist" unless -c $PORT;
# TODO: If multiple ttyUSBs around, autodetect which is which...

$a = shift @ARGV;
die "unknown argument" if (defined $a);

die "No RRD ($RRD)" unless -f $RRD;

die "Cannot lock port" unless 1==slock($PORT);

sub cleanup {
	#print "unlocking $PORT\n";
	sunlock($PORT);
	exit 0;
}
$SIG{'__DIE__'} = \&cleanup;
$SIG{'INT'} = \&cleanup;

my $ob = Device::SerialPort->new($PORT);
unless (-c $PORT && defined($ob)) {
	die "no serial port!";
}

$ob->baudrate($BAUD);
$ob->write_settings;

unless (open(SERIAL, "+>$PORT")) {
	die "opening serial port: $!";
};

while (my $line = <SERIAL>) {
    if ($line =~ m!<tmpr> *([\-\d.]+)</tmpr>.*<ch1><watts>0*(\d+)</watts></ch1>!) {
        my $watts = $2;
        my $temp = $1;
		$watts="U" unless defined $watts;
		$temp="U" unless defined $temp;
		my $rv = system("rrdupdate", "$RRD", "N:$watts:$temp");
		die "rrdupdate failed (system $rv, process return ".($rv>>8).")" unless $rv==0;
    }
}
