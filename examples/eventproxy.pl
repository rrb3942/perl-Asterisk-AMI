#!/usr/bin/perl

#This script demonstrates a simply event proxy created useing AMI::Events and
#IO::Select. The entire program runs in a single thread, and sends any connected
#clients a copy of any events received from Asterisk.
#By default it is set to listen on port 5039 and you can connect to it with telnet
#or netcat.
#Be sure to fill in your asterisk server information.

use strict;
use warnings;
use AMI::Events;
use IO::Select;
use IO::Socket::INET;

my $EOL = "\r\n";

my $EOR = $EOL;

#Port to listen on
my $port = 5039;

#Hash to store clients
my %clients;

#My IO::Select
my $selector = IO::Select->new();

#My listening socket
my $server = IO::Socket::INET->new (	Listen => 1,
					LocalPort => $port,
					Proto => 'tcp'
				);

die "Unable to bind to port $port" unless ($server);

#My asterisk connection
my $astman = AMI::Events->new (	PeerAddr => '127.0.0.1', #Set this to your asterisk server
				Username => 'manageruser', #Set this to your manager user
				Secret	=> 'managersecrect', #Set this to your manageruser secrect
				Events	=> 'on', #Give us something to proxy
				FastEvents => 1, #Enable immediate processing of events
				Timeout => 3, #Default timeout for all operations, 3 seconds
				Handlers => { default => \&proxy_event } #Install default handler
				);

die "Unable to connect to asterisk" unless ($astman);

#Handler for events
sub proxy_event {
	my ($event) = @_;

	#Event string to build and proxy
	my $pevent;

	#They don't want our timestamp, do they?
	delete $event->{'TIMESTAMP'};

	#Build the proxied event string
	#For now pretend we like we are asterisk and format as such

	#String from {'DATA'}
	my $dstring;

	#DATA in events are usually lines without values
	#something like 'AppData:' but nothing in the value
	#We don't have to send them, but just to be 'compatible' we will
	foreach my $data (@{$event->{'DATA'}}) {
		$dstring .= $data . $EOL;
	}

	$dstring .= $EOR;

	delete $event->{'DATA'};

	while (my ($key, $value) = each(%{$event})) {
		$pevent .= $key . ': ' . $value . $EOL;
	}

	#Stick the DATA fields at the end
	$pevent .= $dstring;

	#Inform the soldiers, clear the dead
	while (my ($client, $handle) = each(%clients)) {
		remove_client($handle) unless (print $handle $pevent);
	}

	return 1;
}

#Remove a client if they d/c
sub remove_client {
	my ($client) = @_;
	$selector->remove($client);
	delete $clients{$client};
	return 1;
}

#What to do when we get something from asterisk
sub read_astman {
	#Have astman handle the packet
	unless ($astman->process_packet()) {
		#Failed to read packet for some reason
		#Check the connection, die if d/c
		unless($astman->connected()) {
			die "Lost connection to asterisk";
		}
	}

	return 1;
}

#Run the server
sub run {

	#Add handlers to IO::Select
	$selector->add($server);
	$selector->add($astman);

	print "Event proxy started\r\n";

	#Wait for input from clients or asterisk
	while (my @fhs = $selector->can_read()) {
		foreach my $fh (@fhs) {
			#Something came in from asterisk
			if ($fh == $astman) {
				read_astman();
			#New connection
			} elsif ($fh == $server) {
				#accept
				my $client = $fh->accept();
				#store
				$clients{$client} = $client;
				#watch
				$selector->add($client);
			#Client
			} else {
				#Remove them if they are D/C, otherwise ignore it
				remove_client($fh) unless (defined (my $test = <$fh>));
				next;	
			}
		}
	}

	return 1;
}

run();
