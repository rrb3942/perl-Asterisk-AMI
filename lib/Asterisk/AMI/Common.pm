#!/usr/bin/perl

=head1 NAME

Asterisk::AMI::Common - Extends the AMI module to provide simple access to common AMI commands and functions

=head1 VERSION

0.1.5

=head1 SYNOPSIS

	use Asterisk::AMI::Common;

	my $astman = Asterisk::AMI::Common->new(PeerAddr	=>	'127.0.0.1',
						PeerPort	=>	'5038',
						Username	=>	'admin',
						Secret		=>	'supersecret'
				);

	die "Unable to connect to asterisk" unless ($astman);

	$astman->db_get();

=head1 DESCRIPTION

This module extends the AMI module to provide easier access to common actions and commands available
through the AMI.

=head2 Constuctor

=head3 new([ARGS])

Creates new a Asterisk::AMI::Common object which takes the arguments as key-value pairs.

This module inherits all options from the AMI module.

=head2 Methods

commands ( [ TIMEOUT ] )

	Returns a hash reference of commands available through the AMI. TIMEOUT is optional

	$hashref->{'CommandName'}->{'Desc'}	Contains the command description
				   {'Priv'}	Contains list of required privliges.

db_get ( FAMILY, KEY [, TIMEOUT ])

	Returns the value of the Asterisk database entry specified by the FAMILY and KEY pair, or undef if
	does not exist or an error occured. TIMEOUT is optional.

db_put ( FAMILY, KEY, VALUE [, TIMEOUT ])

	Inserts VALUE for the Asterisk database entry specified by the FAMILY and KEY pair. Returns 1 on success, if it
	failed or undef on error or timeout. TIMEOUT is optional.

db_show ( [ TIMEOUT ] )

	Returns a hash reference containing the contents of the Asterisk database, or undef on error or timeout.
	TIMEOUT is optional.

	Values in the hash reference are stored as below:
	$hashref->{FAMILY}->{KEY}

get_var ( CHANNEL, VARIABLE [, TIMEOUT ])

	Returns the value of VARIABLE for CHANNEL, or undef on error or timeout. TIMEOUT is optional.

set_var ( CHANNEL, VARIABLE, VALUE [, TIMEOUT ])

	Sets VARIABLE to VALUE for CHANNEL. Returns 1 on success, 0 if it failed, or undef on error or timeout.
	TIMEOUT is optional.

hangup ( CHANNEL [, TIMEOUT ])

	Hangsup CHANNEL. Returns 1 on success, 0 if it failed, or undef on error or timeout. TIMEOUT is optional.

exten_state ( EXTEN, CONTEXT [, TIMEOUT ])

	Returns the state of the EXTEN in CONTEXT, or undef on error or timeout. TIMEOUT is optional

	States:
	-1 = Extension not found
	0 = Idle
	1 = In Use
	2 = Busy
	4 = Unavailable
	8 = Ringing
	16 = On Hold

park ( CHANNEL, CHANNEL2 [, PARKTIME, TIMEOUT ] )

	Parks CHANNEL and announces park information to CHANNEL2. CHANNEL2 is also the channel the call will return to if
	it timesout. 
	PARKTIME is optional and can be used to control how long a person is parked for. TIMEOUT is optional.

	Returns 1 if the call was parked, or 0 if it failed, or undef on error and timeout.

parked_calls ( [ TIMEOUT ] )

	Returns a hash reference containing parking lots and their members, or undef if an error/timeout or if no calls
	were parked. TIMEOUT is optional.

	Hash reference structure:

	$hashref->{lotnumber}->{'Channel'}
			       {'Timeout'}
			       {'CallerID'}
			       {'CallerIDName'}

sip_peers ( [ TIMEOUT ] )

	Returns a hash reference containing all SIP peers, or undef on error or timeout. TIMEOUT is optional.

	Hash reference structure:

	$hashref->{peername}->{'Channeltype'}
			      {'ChanObjectType'}
			      {'IPaddress'}
			      {'IPport'}
			      {'Dynamic'}
			      {'Natsupport'}
			      {'VideoSupport'}
			      {'ACL'}
			      {'Status'}
			      {'RealtimeDevice'}

sip_peer ( PEERNAME [, TIMEOUT ] )

	Returns a hash reference containing the information for PEERNAME, or undef on error or timeout.
	TIMEOUT is optional.

	Hash reference structure:

	$hashref->{'SIPLastMsg'}
		  {'SIP-UserPhone'}
		  {'Dynamic'}
		  {'TransferMode'}
		  {'SIP-NatSupport'}
		  {'Call-limit'}
		  {'CID-CallingPres'}
		  {'LastMsgsSent'}
		  {'Status'}
		  {'Address-IP'}
		  {'RegExpire'}
		  {'ToHost'}
		  {'Codecs'},
		  {'Default-addr-port'}
		  {'SIP-DTMFmode'}
		  {'Channeltype'}
		  {'ChanObjectType'}
		  {'AMAflags'}
		  {'SIP-AuthInsecure'}
		  {'SIP-VideoSupport'}
		  {'Callerid'}
		  {'Address-Port'}
		  {'Context'}
		  {'ObjectName'}
		  {'ACL'}
		  {'Default-addr-IP'}
		  {'SIP-PromiscRedir'}
		  {'MaxCallBR'}
		  {'MD5SecretExist'}
		  {'SIP-CanReinvite'}
		  {'CodecOrder'}
		  {'SecretExist'}


mailboxcount ( EXTENSION, CONTEXT [, TIMEOUT ] )

	Returns an hash reference containing the message counts for the mailbox EXTENSION@CONTEXT, or undef on error or
	timeout. TIMEOUT is optional.

	Hash reference structure:

	$hashref->{'Mailbox'}
		  {'NewMessages'}
		  {'OldMessages'}

mailboxstatus ( EXTENSION, CONTEXT [, TIMEOUT ] )
	
	Returns the status of the mailbox or undef on error or timeout. TIMEOUT is optinal

chan_timeout ( CHANNEL, CHANNELTIMEOUT [, TIMEOUT ] )

	Sets CHANNEL to timeout in CHANNELTIMEOUT seconds. Returns 1 on success, 0 on failure, or undef on error or timeout.
	TIMEOUT is optinal.

queues ( [ TIMEOUT ] )

	Returns a hash reference containing all queues, queue members, and people currently waiting in the queue,
	or undef on error or timeout. TIMEOUT is optional

	Hash reference structure:

	$hashref->{queue}->{'Max'}
			   {'Calls'}
			   {'Holdtime'}
			   {'Completed'}
			   {'Abandoned'}
			   {'ServiceLevel'}
			   {'ServicelevelPerf'}
			   {'Weight'}
			   {'MEMBERS'}->{name}->{'Location'}
						{'Membership'}
						{'Penalty'}
						{'CallsTaken'}
						{'LastCall'}
						{'Status'}
						{'Paused'}
			   {'ENTRIES'}->{position}->{'Channel'}
						    {'CallerID'}
						    {'CallerIDName'}
						    {'Wait'}

queue_status ( QUEUE [, TIMEOUT ] )

	Returns a hash reference containing the queue status, members, and people currently waiting in the queue,
	or undef on error or timeout. TIMEOUT is optional.

	Hash reference structure

	$hashref->{'Max'}
		  {'Calls'}
		  {'Holdtime'}
		  {'Completed'}
		  {'Abandoned'}
		  {'ServiceLevel'}
		  {'ServicelevelPerf'}
		  {'Weight'}
		  {'MEMBERS'}->{name}->{'Location'}
				       {'Membership'}
				       {'Penalty'}
				       {'CallsTaken'}
				       {'LastCall'}
				       {'Status'}
				       {'Paused'}
		  {'ENTRIES'}->{position}->{'Channel'}
					   {'CallerID'}
					   {'CallerIDName'}
					   {'Wait'}
queue_member_pause ( QUEUE, MEMBER, PAUSEVALUE [, TIMEOUT ] )

	Sets the MEMBER of QUEUE to PAUSEVALUE. A value of 0 will unpause a member, and 1 will pause them.
	Returns 1 if the PAUSEVALUE was set, 0 if it failed, or undef on error or timeout. TIMEOUT is optional.

queue_member_toggle ( QUEUE, MEMBER [, TIMEOUT ] )

	Toggles MEMBER of QUEUE pause status. From paused to unpaused, and unpaused to paused.
	Returns 1 if the the pause status was toggled, 0 if failed, or undef on error or timeout. TIMEOUT is optional

queue_add ( QUEUE, MEMEBER [, TIMEOUT ] )

	Adds MEMBER to QUEUE. Returns 1 if the MEMBER was added, or 0 if it failed, or undef on error or timeout.
	TIMEOUT is optional.

queue_remove ( QUEUE, MEMEBER [, TIMEOUT ] )

	Removes MEMBER from QUEUE. Returns 1 if the MEMBER was removed, 0 if it failed, or undef on error or timeout.
	TIMEOUT is optional.

play_dtmf ( CHANNEL, DIGIT [, TIMEOUT ] )

	Plays the dtmf DIGIT on CHANNEL. Returns 1 if the DIGIT was queued on the channel, or 0 if it failed, or
	undef on error or timeout.
	TIMEOUT is optional.

play_digits ( CHANNLS, DIGITS [, TIMEOUT ] )

	Plays the dtmf DIGITS on CHANNEL. DIGITS should be passed as an array reference. Returns 1 if all DIGITS
	were queued on the channel, or 0 if an any queuing failed. TIMEOUT is optional.

channels ( [ TIMEOUT ] )

	Returns a hash reference containing all channels with their information, or undef on error or timeout.
	TIMEOUT is optional.

	Hash reference structure:

	$hashref->{channel}->{'Context'}
			     {'CallerID'}
			     {'CallerIDNum'}
			     {'CallerIDName'}
 			     {'Account'}
 			     {'State'}
 			     {'Context'} 
 			     {'Extension'}
 			     {'Priority'}
 			     {'Seconds'}
 			     {'Link'}
 			     {'Uniqueid'}

chan_status ( CHANNEL [, TIMEOUT ] )
	
	Returns a hash reference containing the status of the channel, or undef on error or timeout.
	TIMEOUT is optional.

	Hash reference structure:
	
	$hashref->{'Channel'}
		  {'CallerID'}
		  {'CallerIDNum'}
		  {'CallerIDName'}
 		  {'Account'}
 		  {'State'}
 		  {'Context'} 
 		  {'Extension'}
 		  {'Priority'}
 		  {'Seconds'}
 		  {'Link'}
 		  {'Uniqueid'}

transfer ( CHANNEL, EXTENSION, CONTEXT [, TIMEOUT ] )

	Transfers CHANNEL to EXTENSION at CONTEXT. Returns 1 if the channel was transfered, 0 if it failed, 
	or undef on error or timeout. TIMEOUT is optional.

meetme_mute ( CONFERENCE, USERNUM [, TIMEOUT ] )

	Mutes USERNUM in CONFERENCE. Returns 1 if the user was muted, 0 if it failed, or undef on error or timeout.
	TIMEOUT is optional.

meetme_unmute ( CONFERENCE, USERNUM [, TIMEOUT ] )

	Unmutes USERNUM in CONFERENCE. Returns 1 if the user was unmuted, or 0 if it failed, or undef on error or timeout.
	TIMEOUT is optional.

monitor ( CHANNEL, FILE [, TIMEOUT ] )

	Begins recording CHANNEL to FILE. Uses the 'wav' format and also mixes both directions into a single file. 
	Returns 1 if the channel was set to record, or 0 if it failed, or undef on error or timeout. TIMEOUT is optional.

monitor_stop ( CHANNEL [, TIMEOUT ])

	Stops recording CHANNEL. Returns 1 if recording on the channel was stopped, 0 if it failed, or undef on error
	or timeout.
	TIMEOUT is optional.

monitor_pause ( CHANNEL [, TIMEOUT ])

	Pauses recording on CHANNEL. Returns 1 if recording on the channel was paused, 0 if it failed, or undef on error
	or timeout.
	TIMEOUT is optional.

monitor_unpause ( CHANNEL [, TIMEOUT ])

	Unpauses recording on CHANNEL. Returns 1 if recording on the channel was unpaused, 0 if it failed, or undef on error
	or timeout.
	TIMEOUT is optional.

monitor_change ( CHANNEL, FILE [, TIMEOUT ] )
	
	Changes the monitor file for CHANNEL to FILE. Returns 1 if the file was change, 0 if it failed, or undef on error
	or timeout.
	TIMEOUT is optional.

=head1 See Also

Asterisk::AMI, Asterisk::AMI::Common::Dev

=head1 AUTHOR

Ryan Bullock (rrb3942@gmail.com)

=head1 BUG REPORTING AND FEEBACK

All bugs should be reported to bugs@voipnerd.net.
Please address any feedback about this module to feedback@voipnerd.net

=head1 COPYRIGHT

Copyright (C) 2010 by Ryan Bullock (rrb3942@gmail.com)

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

package Asterisk::AMI::Common;


use strict;
use warnings;
use version;
use parent qw(Asterisk::AMI);

our $VERSION = qv(0.1.5);


my $basicparse = qr/^(.+?)\s*:\s*([^.]+)$/;
my $cmdparse = qr/^([^:]+): (.+) \(Priv: (.+)\)$/;

#Trims trailing white space
#When chomp is not enough
my $trim = qr/\s+$/;

my @channelfields = ( 'Context', 'Extension', 'Prio', 'State', 'Application', 'Data', 'CallerID', 'Accountcode', 'Amaflags', 'Duration', 'BridgedTo' );


sub new {
	my ($class, %options) = @_;

        my $self = $class->SUPER::new(%options);

	return $self;
}

#Returns a hash
sub commands {

	my ($self, $timeout) = @_;

	my $action = $self->action({ Action => 'ListCommands' }, $timeout);

	my $commands;

	#Early bail out on bad response
	return $commands unless ($action->{'GOOD'});

	foreach my $cmd (@{$action->{'DATA'}}) {
		$cmd =~ $cmdparse;
		$commands->{$1}->{'Desc'} = $2;
		my @privs = split /,/o,$3;
		$commands->{$1}->{'Priv'} = \@privs;
	}

	return $commands;

}

sub db_get {

	my ($self, $family, $key, $timeout) = @_;

	my $action = $self->action({	Action => 'DBGet',
			 	     	Family => $family,
			      		Key => $key }, $timeout);

	my $return = $action->{'EVENTS'}->[0]->{'Val'} if ($action->{'GOOD'});

	return $return;
}

sub db_put {

	my ($self, $family, $key, $value, $timeout) = @_;

	return $self->simple_action({ 	Action => 'DBPut',
					Family => $family,
					Key => $key,
					Val => $value }, $timeout);
}

sub db_show {

	my ($self) = @_;

	my $action = $self->action({	Action => 'Command',
					Command => 'database show'});

	my $database;

	return $database unless ($action->{'GOOD'});

	foreach my $dbentry (@{$action->{'CMD'}}) {
		next unless $dbentry =~ $basicparse;
		my $family = $1;
		my $key;

		my @split = split /\//o,$family;

		$key = pop(@split);

		$family = join('/', @split);

		$family = substr($family, 1);

		$database->{$family}->{$key} = $2;
	}

	return $database;	
}

sub get_var {

	my ($self, $channel, $variable, $timeout) = @_;

	my $action = $self-action({	Action => 'GetVar',
					Channel => $channel,
					Variable => $variable }, $timeout);

	my $return = $action->{'PARSED'}->{'Value'} if ($action->{'GOOD'});

	return $return;
}

sub set_var {

	my ($self, $channel, $varname, $value, $timeout) = @_;

	return $self->simple_action({	Action => 'Setvar',
					Channel => $channel,
					Variable => $varname,
					Value => $value }, $timeout);
}

sub hangup {

	my ($self, $channel, $timeout) = @_;

	return $self->simple_action({	Action => 'Hangup',
					Channel => $channel }, $timeout);
}

sub exten_state {

	my ($self, $exten, $context, $timeout) = @_;

	my $action = $self->action({	Action => 'ExtensionState',
					Exten	=> $exten,
					Context	=> $context }, $timeout);

	my $return = $action->{'PARSED'}->{'Status'} if ($action->{'GOOD'});

	return $return;
}

sub park {
	my ($self, $chan1, $chan2, $parktime, $timeout) = @_;

	#Why did I format this one like this? weird, still fine though.
	my %action = ( 	Action => 'Park',
			Channel => $chan1,
			Channel2 => $chan2 );

	$action{'Timeout'} = $parktime if (defined $parktime);

	return $self->simple_action(\%action, $timeout);
}

sub parked_calls {

	my ($self, $timeout) = @_;

	my $action = $self->action({ Action => 'ParkedCalls' }, $timeout);

	my $parkinglots;

	return $parkinglots unless ($action->{'GOOD'});

	foreach my $lot (@{$action->{'EVENTS'}}) {
		delete $lot->{'ActionID'};
		delete $lot->{'Event'};

		my $lotnum = $lot->{'Exten'};

		delete $lot->{'Exten'};

		$parkinglots->{$lotnum} = $lot;
	}

	return $parkinglots;
}

sub sip_peers {

	my ($self, $timeout) = @_;

	my $action = $self->action({ Action => 'Sippeers' }, $timeout);

	my $peers;

	return $peers unless ($action->{'GOOD'});

	foreach my $peer (@{$action->{'EVENTS'}}) {
		delete $peer->{'ActionID'};
		delete $peer->{'Event'};

		my $peername = $peer->{'ObjectName'};

		delete $peer->{'ObjectName'};

		$peers->{$peername} = $peer;
	}

	return $peers;
}

sub sip_peer {

	my ($self, $peername, $timeout) = @_;

	my $action = $self->action({	Action => 'SIPshowpeer',
					Peer => $peername }, $timeout);

	my $return = $action->{'PARSED'} if ($action->{'GOOD'});

	return $return;
}


sub mailboxcount {

	my ($self, $exten, $context, $timeout) = @_;

	my $action = $self->action({	Action => 'MailboxCount',
					Mailbox => $exten . '@' . $context }, $timeout);

	my $return = $action->{'PARSED'} if ($action->{'GOOD'});

	return $return;
}

sub mailboxstatus {

	my ($self, $exten, $context, $timeout) = @_;

	my $action = $self->action({	Action => 'MailboxStatus',
					Mailbox => $exten . '@' . $context }, $timeout);

	my $return = $action->{'PARSED'}->{'Waiting'} if ($action->{'GOOD'});

	return $return;
}

sub chan_timeout {

	my ($self, $channel, $chantimeout, $timeout) = @_;

	return $self->simple_action({	Action => 'AbsoluteTimeout',
					Channel => $channel,
					Timeout => $chantimeout }, $timeout);
}

sub queues {
	
	my ($self, $timeout) = @_;

	my $action = $self->action({ Action => 'QueueStatus' }, $timeout);

	my $queues;

	return $queues unless ($action->{'GOOD'});

	foreach my $event (@{$action->{'EVENTS'}}) {

		my $qevent = $event->{'Event'};
		my $queue = $event->{'Queue'};

		delete $event->{'Event'};
		delete $event->{'ActionID'};
		delete $event->{'Queue'};
			
		if ($qevent eq 'QueueParams') {
			while (my ($key, $value) = each %{$event}) {
				$queues->{$queue}->{$key} = $value;
			}
		} elsif ($qevent eq 'QueueMember') {

			my $name = $event->{'Name'};

			delete $event->{'Name'};

			$queues->{$queue}->{'MEMBERS'}->{$name} = $event;

		} elsif ($qevent eq 'QueueEntry') {

			my $pos = $event->{'Position'};

			delete $event->{'Position'};
			
			$queues->{$queue}->{'ENTRIES'}->{$pos} = $event;
		}

	}

	return $queues;
}

sub queue_status {
	
	my ($self, $queue, $timeout) = @_;

	my $action = $self->action({	Action => 'QueueStatus',
				 	Queue => $queue }, $timeout);

	my $queueobj;

	return $queueobj unless ($action->{'GOOD'});

	foreach my $event (@{$action->{'EVENTS'}}) {

		my $qevent = $event->{'Event'};

		delete $event->{'Event'};
		delete $event->{'ActionID'};
			
		if ($qevent eq 'QueueParams') {
			while (my ($key, $value) = each %{$event}) {
				$queueobj->{$key} = $value;
			}
		} elsif ($qevent eq 'QueueMember') {

			my $name = $event->{'Name'};

			delete $event->{'Name'};
			delete $event->{'Queue'};

			$queueobj->{'MEMBERS'}->{$name} = $event;

		} elsif ($qevent eq 'QueueEntry') {

			my $pos = $event->{'Position'};

			delete $event->{'Queue'};
			delete $event->{'Position'};
			
			$queueobj->{'ENTRIES'}->{$pos} = $event;
		}

	}

	return $queueobj;
}

sub queue_member_pause {

	my ($self, $queue, $member, $paused, $timeout) = @_;

	return $self->simple_action({	Action => 'QueuePause',
					Queue => $queue,
					Interface => $member,
					Paused => $paused }, $timeout);
}

sub queue_member_toggle {

	my ($self, $queue, $member, $timeout) = @_;

	my $queueobj = $self->queue_status($queue, $timeout);

	my $paused;

	return $paused unless ($queueobj);

	if ($queueobj->{'MEMBERS'}->{$member}->{'Paused'} == 0) {
		$paused = 1;
	} elsif ($queueobj->{'MEMBERS'}->{$member}->{'Paused'}) {
		$paused = 0;
	}

	if (defined $paused) { $self->queue_pause($queue, $member, $paused, $timeout) or undef $paused };

	return $paused;
}

sub queue_add {

	my ($self, $queue, $member, $timeout) = @_;

	return $self->simple_action({	Action => 'QueueAdd',
					Queue => $queue,
					Interface => $member }, $timeout);
}

sub queue_remove {

	my ($self, $queue, $member, $timeout) = @_;

	return $self->simple_action({	Action => 'QueueRemove',
					Queue => $queue,
					Interface => $member }, $timeout);
}

sub play_dtmf {

	my ($self, $channel, $digit, $timeout) = @_;

	return $self->simple_action({	Action => 'PlayDTMF',
					Channel => $channel,
					Digit => $digit }, $timeout);
}

sub play_digits {

	my ($self, $channel, $digits, $timeout) = @_;

	my $return = 1;
	my $err = 0;

	my @actions = map { $self->send_action({ Action => 'PlayDTMF',
						 Channel => $channel,
						 Digit => $_}) } @{$digits};

	foreach my $action (@actions) {
		my $resp = $self->check_response($action,$timeout);

		next if ($err);

		unless (defined $resp) {
			undef $return;
			$err = 1;
			next;
		}

		$return = 0 unless ($resp);
	}

	return $return;
}

sub channels {
	
	my ($self, $timeout) = @_;

	my $action = $self->action({Action => 'Status'},$timeout);

	my $channels;

	return $channels unless ($action->{'GOOD'});

	foreach my $chan (@{$action->{'EVENTS'}}) {
		#Clean out junk
		delete $chan->{'Event'};
		delete $chan->{'Privilege'};

		my $name = $chan->{'Channel'};
	
		delete $chan->{'Channel'};

		$channels->{$name} = $chan;
	}

	return $channels;
}

sub chan_status {

	my ($self, $channel, $timeout) = @_;

	my $action = $self->action({	Action => 'Status',
					Channel	=> $channel}, $timeout);

	my $status;

	return $status unless ($action->{'GOOD'});

	$status = $action->{'EVENTS'}->[0];

	delete $status->{'ActionID'};
	delete $status->{'Event'};

	return $status;
}

sub transfer {

	my ($self, $channel, $exten, $context, $timeout) = @_;

	return $self->simple_action({	Action => 'Redirect',
					Channel => $channel,
					Exten => $exten,
					Context => $context,
					Priority => 1 }, $timeout);

}

sub meetme_mute {
	my ($self, $conf, $user, $timeout) = @_;

	return $self->simple_action({	Action => 'MeetmeMute',
					Meetme => $conf,
					Usernum => $user }, $timeout);
}

sub meetme_unmute {
	my ($self, $conf, $user, $timeout) = @_;

	return $self->simple_action({	Action => 'MeetmeUnmute',
					Meetme => $conf,
					Usernum => $user }, $timeout);
}

sub monitor {
	my ($self, $channel, $file, $timeout) = @_;

	return $self->simple_action({	Action => 'Monitor',
					Channel => $channel,
					File => $file,
					Format => 'wav',
					Mix => '1' }, $timeout);
}

sub monitor_stop {
	my ($self, $channel, $timeout) = @_;

	return $self->simple_action({	Action => 'StopMonitor',
					Channel => $channel }, $timeout);
}

sub monitor_pause {
	my ($self, $channel, $timeout) = @_;

	return $self->simple_action({	Action => 'PauseMonitor',
					Channel => $channel }, $timeout);
}

sub monitor_unpause {
	my ($self, $channel, $timeout) = @_;

	return $self->simple_action({	Action => 'UnpauseMonitor',
					Channel => $channel }, $timeout);
}

sub monitor_change {
	my ($self, $channel, $file, $timeout) = @_;

	return $self->simple_action({	Action => 'ChangeMonitor',
					Channel => $channel,
					File => $file }, $timeout);
}

return 1;
