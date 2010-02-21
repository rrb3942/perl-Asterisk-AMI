#!/usr/bin/perl

#Author: Ryan Bullock
#Version: 0.1
#Description: This provided a very simple command server for the asterisk manager interface.

use strict;
use warnings;
use AnyEvent::Impl::Perl;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Asterisk::AMI;

#Port to listen on
my $port = 5039;

#Delimiters
my $EOL = "\015\012";

my $EOR = $EOL;

#Command list;
my $list = 'Command List:' . $EOL;
$list .= 'channels - Displays list of active channels' . $EOL;
$list .= 'mailbox <mailbox> - Displays messages for a mailbox' . $EOL;
$list .= 'hangup <channel> - Hangs up a channel' . $EOL;
$list .= 'quit - Disconnects from server' . $EOL;
$list .= 'list - Displays this list' . $EOL . $EOR;

#Keep a list of clients
my %clients;

#Mappings of actionids to clients
my %mappings;

#Connect to asterisk
my $astman = Asterisk::AMI->new(PeerAddr => '127.0.0.1',
				Username => 'test',
				Secret	=> 'supersecret',
				Timeout => 3, #Default timeout for all operations, 3 seconds
				Keepalive => 60, #Send a keepalive every minute
				on_error => sub { print "Error occured on socket\r\n"; exit; },
				on_timeout => sub { print "Connection to asterisk timed out\r\n"; exit; }
			);

die "Unable to connect to asterisk" unless ($astman);

#Callback on mailbox command
sub mailboxcb {
	my ($asterisk, $action) = @_;

	my $id = $action->{'ActionID'};
	
	my $mbstr;

	if ($action->{'GOOD'} && exists $action->{'PARSED'}) {
		while (my ($key, $value) = each %{$action->{'PARSED'}}) {
			$mbstr .= $key . ': '. $value . $EOL;
		}
	} else {
		$mbstr = 'Invalid Mailbox, or command failed' . $EOL;
	}

	$mappings{$id}->push_write($mbstr . $EOR);
	delete $mappings{$id} if (exists $clients{$mappings{$id}});
}

#Callback on channels command
sub chancb {
	my ($asterisk, $action) = @_;

	my $id = $action->{'ActionID'};
	
	my $chanstr;

	if ($action->{'GOOD'} && exists $action->{'EVENTS'}) {
		foreach my $channel (@{$action->{'EVENTS'}}) {
			$chanstr .= $channel->{'Channel'} . $EOL;
		}
	} else {
		$chanstr = 'No channels active' . $EOL;
	}

	$mappings{$id}->push_write($chanstr . $EOR);
	delete $mappings{$id} if (exists $clients{$mappings{$id}});
}

#Callback on hangup command
sub hangupcb {
	my ($asterisk, $action) = @_;

	my $id = $action->{'ActionID'};

	my $str;

	if ($action->{'GOOD'}) {
		$str = 'Channel hungup';
	} else {
		$str = 'Failed to hangup channel';
	}	

	$mappings{$id}->push_write($str . $EOL . $EOR) if (exists $clients{$mappings{$id}});
	delete $mappings{$id};
}

#Remove a client if they d/c or error
sub remove_client {
	delete $clients{$_[0]};
	$_[0]->destroy;
	return 1;
}

#Handle commands from clients
sub client_input {
	my ($handle) = @_;

	my @cmd = split /\s+/,$handle->{rbuf};		
	undef $handle->{rbuf};

	return unless ($cmd[0]);

	my $id;

	if ($cmd[0] eq 'mailbox') {
		$id = $astman->send_action({	Action => 'MailboxCount',
				  		Mailbox => $cmd[1] . '@default',
						CALLBACK => \&mailboxcb });
	} elsif ($cmd[0] eq 'channels') {
		$id = $astman->send_action({Action => 'Status', CALLBACK => \&chancb});
	} elsif ($cmd[0] eq 'hangup') {
		$id = $astman->send_action({	Action => 'Hangup',
						Channel => $cmd[1],
						CALLBACK => \&hangupcb } );
	} elsif ($cmd[0] eq 'list') {
		$handle->push_write($list);
	} elsif ($cmd[0] eq 'quit') {
		$handle->push_write('Goodbye' . $EOL . $EOR);
		remove_client($handle);
	} else {
		$handle->push_write('Invalid Command' . $EOL . $EOR);
	}
	
	$mappings{$id} = scalar($handle) if (defined $id);

	return 1;
}

#Handles new connections
sub new_client {
	my ($fh, $host, $port) = @_;

	#Create an AnyEvent handler for the client
	my $handle = new AnyEvent::Handle(	fh => $fh,
						on_error => \&remove_client,
						on_eof => \&remove_client
						);

	#Read what to do on client input
	$handle->on_read(\&client_input);

	#Send a greeting
	$handle->push_write('Connected to command server.' . $EOL);
	$handle->push_write('Enter \'list\' for a list of commands' . $EOL);

	$clients{$handle} = $handle;
}

#Our server to accept connections
tcp_server undef, $port, \&new_client;

#Start our server
print "Starting Command Server\r\n";
AnyEvent::Impl::Perl::loop;
