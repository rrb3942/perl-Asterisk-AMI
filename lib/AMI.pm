#!/usr/bin/perl

=head1 NAME

AMI - Perl moduling for interacting with the Asterisk Manager Interface

=head1 VERSION

0.1.1

=head1 SYNOPSIS

	use AMI;
	my $astman = AMI->new(  PeerAddr	=>	'127.0.0.1',
                        	PeerPort	=>	'5038',
				Username	=>	'admin',
				Secret		=>	'supersecret'
				);	
	
	die "Unable to connect to asterisk" unless ($astman);

	my $action = $astman->({ Action => 'Command',
				 Command => 'sip show peers'
				});

=head1 DESCRIPTION

This module provides an interface to the Asterisk Manager Interface. It's goal is to flexible, powerful, and reliable way to
interact with Asterisk upon which other applications may be built.

=head2 Constructor

=head3 new([ARGS])

Creates a new AMI object which takes the arguments as key-value pairs.

	Key-Value Pairs accepted:
	PeerAddr	Remote host address	<hostname>
	PeerPort	Remote host port	<service>
	Events		Enable/Disable Events		'on'|'off'
	ResponseEvents	Match Events to Actions 	0 | 1
	AutoClear	How often to clear out the Action buffer
	AutoAge		Maximum age of item in the Action Buffer
	Username	Username to access the AMI
	Secret		Secret used to connect to AMI


	'PeerAddr' defaults to 127.0.0.1.\n
	'PeerPort' defaults to 5038.
	'Events' may be anything that the AMI will accept as a part of the 'Events' parameter for the login action.
	Default is 'off.
	'ResponseEvents' defaults controls whether or not events associated with an action are matched to and stored
	with the response to that action. The default value of 1 groups Events with their actions.
	'AutoClear' determines how often we clean out the action buffer. It is measure in actions sent. A value
	of 10 would mean every 10th action you sent would trigger a check for cleaning out old events. it
	must be a positive integer. 
	Default value is 1000.
	'AutoAge' is the maximum age of an item in the action buffer in seconds. Default is 300 seconds (5 minutes)
	'Username' has no default and must be supplied.
	'Secret' has no default and must be supplied.

=head2 Actions

=head3 Construction

No matter which method you use to send an action (send_action(), simple_action(), or action()), they all accept
actions in the same format, which is a hash reference.

To build and send an action you can do the following:

	%action = ( Action => 'Command',
		    Command => 'sip show peers'
		);

	$astman->send_action(\%action);

Alternatively you can also do the following to the same effect:

	$astman->send_action({	Action => 'Command',
				Command => 'sip show peers'
				});

Additionally the value of the hash may be an array reference. When an array reference is used, every
value in the array is append as a different line to the action. For example:

	{ Variable => [ 'var1=1', 'var2=2' ] }

	Will become:

	Variable: var1=1
	Variable: var2=2

	When the action is sent.

=head3 Sending and Retrieving

More detailed information on these individual methods is available below

The send_action() method can be used to send an action to the AMI. It will return a positive integer, which is the 
ActionID of the action, on success and will return 0 in the event it is unable to send the event.
	
After sending an action you can then get its response in one of two methods.

The method check_response() accepts an actionid and will return 1 if the action was considered successful and 0 if 
it failed or an error occured.

The method get_action() accepts an actionid and will return a Response object (really just a fancy hash) with the 
contents of the Action Response as well as any associated Events it generated. If the action failed it will return 
undef.

All responses and events are buffered, therefor you can issue several send_action()s and then retrieve/check their 
responses out of order without losing any information. Infact if you are issuing many actions in series you can get 
much better performance sending them all first and then retrieving them later, rather than waiting for responses 
immediatly after issuing an action.

Alternativley you can also use simple_action() and action().
simple_action() combines send_action() and check_response(), and therefore returns 1 on success and 2 on failure.
action() combines send_action() and get_action(), and therefore returns and Response object or undef.

=head4 Examples

	Send and retrieve and action:
	my $actionid = $astman->send_action({	Action => 'Command',
						Command => 'sip show peers'
				});

	my $response = $astman->get_action($actionid)

	This is equivalent to the above:
	my $response =	$astman->action({	Action => 'Command',
						Command => 'sip show peers'
				});

	The following:
	my $actionid1 =	$astman->send_action({	Action => 'Command',
						Command => 'sip show peers'
				});

	my $actionid2 =	$astman->send_action({	Action => 'Command',
						Command => 'sip show peers'
				});

	my $actionid3 =	$astman->send_action({	Action => 'Command',
						Command => 'sip show peers'
				});

	my $response3 = $actan->get_action($actionid3);
	my $response1 = $actan->get_action($actionid1);
	my $response2 = $actan->get_action($actionid2);

	Can be much faster than:
	my $response1 =	$astman->action({	Action => 'Command',
						Command => 'sip show peers'
				});
	my $response2 =	$astman->action({	Action => 'Command',
						Command => 'sip show peers'
				});
	my $response3 =	$astman->action({	Action => 'Command',
						Command => 'sip show peers'
				});

=head3 ActionIDs

This module handles ActionIDs internally and if you supply one in an action it will simply be ignored and overwritten. 

=head2 Responses and Events

=head3 Responses

	Responses are returned as response objects, which are hash references, structured as follows:

	$response->{'Response'}		Response to our packet (Success, Failed, Error, Pong, etc)
		   {'ActionID'}		ActionID of this Response
		   {'Message'}		Message line of the response
		   {'EVENTS'}		Arrary reference containing Event Objects associated with this actionid
		   {'PARSED'}		Hash refernce of lines we could parse into key->value pairs
		   {'DATA'}		Array refernce of lines that we could not parse
		   {'SENDTIME'}		Timestamp when the packet was sent (just the output of time())
		   {'COMPLETED'}	Only exists if the action completed
		   {'TIMESTAMP'}	Timestamp of when the last packet was received for this action(just the output of time())


=head3 Events

	Events are turned into event objects, these are similiar to response objects, but their keys vary much more
	depending on the specific event.

	Some common contents are:

	$event->{'Event'}		The type of Event
		{'ActionID'}		Only available if this event was caused by an action
		{'TIMESTAMP'}		Timestamp of when this event was received, (just the output of time()) 


=head2 Methods

send_action ( ACTION )

	Sends the action to asterisk. If no errors occured while sending it returns the ActionID for the action,
	which is a positive integer above 0. If it encounters and error it will return 0.
	
check_response( [ ACTIONID ], [ TIMEOUT ] )

	Returns 1 if the action was considered successful, or 0 if it failed. If no ACTIONID is specified the ACTIONID
	of the last action sent will be used. If no TIMEOUT is given it blocks, reading in packets until the action
	completes. Unlike get_action, this will not remove a response from the buffer.

get_action ( [ ACTIONID ], [ TIMEOUT ] )

	Returns the response object for the action. If the action failed, or an error was encountered it returns undef.
	If no ACTIONID is specified the ACTIONID of the last action sent will be used. If no TIMEOUT is given it 
	blocks, reading in packets until the action completes. This will remove the response from the buffer.

action ( ACTION [, TIMEOUT ] )

	Sends the action and returns the response object for the action. If the action failed, or an error was 
	encountered it returns undef. If no ACTIONID is specified the ACTIONID of the last action sent will be used.
	If no TIMEOUT is given it blocks, reading in packets until the action completes. This will remove the
	response from the buffer.

simple_action ( ACTION [, TIMEOUT ] )

	Sends the action and returns 1 if the action was considered successful, or 0 if it failed. If no ACTIONID is
	specified the ACTIONID of the last action sent will be used. If no TIMEOUT is given it blocks, reading in
	packets until the action completes. This will remove the response from the buffer.

completed ( ACTIONID )

	This does a non-blocking check to see if an action an action has completed and been read into the buffer.
	If no ACTIONID is given the ACTIONID of the last action sent will be used.
	It returns 1 if the action has completed and 0 if it has not.
	This will not remove the response from the buffer.

close ()

	Logoff and disconnects from the AMI. Returns 1 on success and 0 if any errors were encountered.

get_event ( [ TIMEOUT ] )

	This returns the first event object in the buffer, or if no events are in the buffer it reads in packets
	waiting for an event. It will return undef if an error occurs.
	If no TIMEOUT is given it blocks, reading in packets until an event arrives.

get_buffered_event ()

	This returns an event object from the buffer, or undef if no events are in the buffer. This does not block.

clear_action ( ACTIONID )

	This removes whatever contents of an action may currently exist in the action buffer.

clear_actions ()

	This clears the entire action buffer of all responses.

clear_old_actions ( MAXAGE )

	This will remove all responses that have not been updated longer that MAXAGE seconds ago. If MAXAGE
	is not given, nothing will be removed.

clear_events ()

	This clears all events in the event buffer.

clear_old_events ( MAXAGE )

	This will remove all events older than MAXAGE seconds ago. If MAXAGE is not given, nothing will be removed.

clear_old ( MAXAGE )

	This removes all responses and events older than MAXAGE seconds ago. If MAXAGE is not give, nothing will
	be removed.

amiver ()

	Returns the version of the Asterisk Manager Interface we are connected to.

check_connection ( [ TIMEOUT ] )

	This checks the connection to the AMI to ensure it is still functional. It checks at the socket layer and
	also sends a 'PING' to the AMI to ensure it is still responding. If no TIMEOUT is given this will block
	waiting for a response.

	Returns 1 if the connection is good, 0 if it is not.

error ()

	Returns 1 if there are currently errors on the socket, 0 if everything is ok.

=head1 See Also

AMI::Common, AMI::Events

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

#Todo:
#Better ActionID: autoincrement Done
#Enable and disable events Done
#Digest Auth With MD5
#Timeouts? Done
#Periodic Actionbuffer cleansing? Done
#Hashes to build actions? Done
#Perf Testing? More references? 30000 actions in 11-13 seconds with asterisk on local system
package AMI;

use strict;
use warnings;
use IO::Socket::INET;
use Digest::MD5;
use version;

#Duh
our $VERSION = qv(0.1.1);
#my $VERSION = '0.01';

#Keep track if we are logged in
my $LOGGEDIN = 0;

#Used for storing events while reading command responses
#Events are stored as hashes in the array
#Example
#@EVETNBUFFER[0]->{'Event'} = Something
my @EVENTBUFFER;

#Buffer for holding action responses and data
# Structure:
# %ACTIONBUFFER{'ActionID'}->{'Response'}	= (Success|Failure|Follows|Goodbye|Pong|Etc..)	//Reponse Status
#			     {'Message'}	= Message 				//Message in the response
#			     {'EVENTS'}		= [%hash1, %hash2, ..]		//Arry of Hashes of parsed events and data for this actionID
#			     {'PARSED'}		= { Hashkey => value, ...}
#			     {'DATA'}		= [$line1, $line2, ...]			//Array of unparsable data
#			     {'SENDTIME'}       = Timestamp when the packet was sent (jut the output of time())
#			     {'COMPLETED'}	= 0 or 1				//If the command is completed
#			     {'TIMESTAMP'}	= Timestamp of when the last packet was received for this action(just the output of time())
my %ACTIONBUFFER;

#Regex for parsing lines
#my $parse  = qr/^([^:\[]+): (.+)$/;
my $parse  = qr/^([^:]+): ([^:]+)$/;

#Regex for possible response packet contents
my $respcontents = qr/^(?:Response|Message|ActionID|Privilege|COMPLETED|TIMESTAMP)$/;

#Trims trailing white space
#When chomp is not enough
my $trim = qr/\s+$/;

#End of line delimiter
my $EOL = "\r\n";

#END of Response Delimiter
my $EOR = $EOL;

#String we expect upon connecting to the AMI
my $amistring = qr/^Asterisk Call Manager\/([0-9]\.[0-9])$/;

#To store the version of the AMI we are connected to
my $AMIVER;

#Regex that will identify positive AMI responses
my $amipositive = qr/^(?:Success|Goodbye|Events Off|Pong)$/;

#Regex to identify the end of an action via Event
my $completed  = qr/[cC]omplete|^(?:DBGetResponse)$/;
my $store = qr/^(?:DBGetResponse)$/;

#Regex to identify responses with things yet to come
my $follows = qr/[fF]ollow/;

#Keep track of socket errors
my $SOCKERR = 0;

#ActionID Sequence number, gets incremented
my $idseq = 1;

#ActionID of the last command sent
my $lastid;

#Our Socket, Yo.
my $socket;

#Required settings
my @required = ( 'Username', 'Secret' );

#Hash to store settings
#Pre populated with defaults
my %settings = (	PeerAddr =>	'127.0.0.1',
			PeerPort => 	'5038',
			Events	 =>	'off',
			ResponseEvents => 1,
			AutoClear => 1000,
			AutoAge => 300
);

#Actuall Setting Variables that get populated from the hash
my $EVENTS;
my $RESPEVENTS;
my $AUTOCLEAR;
my $AUTOAGE;

#Create a new object and return it;
#If required options are missing, returns undef
sub new {
	my ($class, %values) = @_;

	my $self;

	#Configure our new object, else return undef
	if ($class->_configure(%values) && $class->_connect() && $class->_login()) {
		$self = $class;
	}

	return $self;
}

#Sub to use for alarms
sub _sig_alrm { die "alarm\n" };

#Sets variables for this object
#Also checks for minimum settings
#Returns 1 if everything was set, 0 if options were missing
sub _configure {
	my ($self, %values) = @_;

	#Check for required options
	foreach my $req (@required) {
		if (!exists $values{$req}) {
			return 0;
		}
	}

	#Set values
	foreach my $setting (keys %values) {
		$settings{$setting} = $values{$setting};
	}

	if ($settings{'Events'} ne 'off') {
		$EVENTS = 1;
	} else {
		$EVENTS = 0;
	}

	if ($settings{'ResponseEvents'} == 1) {
		$RESPEVENTS = 1;
	} elsif ($settings{'ResponseEvents'} == 0) {
		$RESPEVENTS = 0;
	} else {
		warn "Invalid value for option 'ResponseEvents'";
		return 0;
	}

	if ($settings{'AutoClear'} != 0 && ($settings{'AutoClear'} = int($settings{'AutoClear'}))) {
		$AUTOCLEAR = $settings{'AutoClear'};
	} else {
		warn "Invalid value for option 'AutoClear'";
		return 0;
	}

	if ($settings{'AutoAge'} = int($settings{'AutoAge'})) {
		$AUTOAGE = $settings{'AutoAge'};
	} else { 
		warn "Invalid value for option 'AutoAge'";
		return 0;
	}
	
	return 1;
}

#Connects to the AMI
#Returns 1 on success, 0 on failure
sub _connect {
	$socket = IO::Socket::INET->new (	PeerAddr =>	$settings{'PeerAddr'},
						PeerPort =>	$settings{'PeerPort'},
						Proto =>	'tcp'
	);

	if ($socket) {
		$socket->autoflush(1);
		my $line = <$socket>;
		$line =~ s/$trim//;
		if ($line =~ $amistring) {
			$AMIVER = $1;
			return 1;
		} else {
			warn "Connection Failed: Unknown Protocol/AMI Version";
		}
	}

	warn "Connection Refused";
	return 0;
}

#Reads in and parses packet from the AMI
#Creates a hash
# Response: Success stores 'Success' in %packet{'Response'}, etc.
#Returns a hash of the parsed packet
sub _read_packet {
	my ($self) = @_;

	my %packet;

	while (my $line = <$socket>) {
		#Trim trailing whitespace
		$line =~ s/$trim//;

		#Faster but less accurate
		#$line =~ tr/\r\n//d;

		#Can we parse and store this line nicely in a hash?
		if ($line =~ $parse) {
			$packet{$1} = $2;
		} elsif ($line eq '--END COMMAND--') {
			$packet{'COMPLETED'} = 1;
		} elsif ($line) {
			push(@{$packet{'DATA'}}, $line);
		#End of packet, $EOR gets trimmed to nothing
		} else {
			#Take a timestamp
			$packet{'TIMESTAMP'} = time();
			last;
		}
	}

	return \%packet;
}

#Sorts a packet and places into the appropriate buffer
#Returns 1 on buffered, 0 on discard
sub _sort_and_buffer {

	my ($self, $packet) = @_;

	#Yeah
	if ($packet) {
		#Associated with an action?
		if (exists $packet->{'Response'}) {
			#Response packet?
			if (exists $packet->{'ActionID'}) {
				#No indication of future packets, mark as completed
				if ($packet->{'Response'} ne 'Follows') {
					if (!exists $packet->{'Message'} || (!$RESPEVENTS || $packet->{'Message'} !~ $follows)) {
						$packet->{'COMPLETED'} = 1;
					}
				} 

				#Copy the response into the buffer
				#We dont just assign the hash reference to the ActionID becase it is possible, though unlikely
				#that event data can arrive for an action before the response packet

				foreach my $key (keys %{$packet}) {
					if ($key =~ $respcontents) {
						$ACTIONBUFFER{$packet->{'ActionID'}}->{$key} =  $packet->{$key};
					} elsif ($key eq 'DATA') {
						push(@{$ACTIONBUFFER{$packet->{'ActionID'}}->{'DATA'}}, @{$packet->{'DATA'}});
					} else {
						$ACTIONBUFFER{$packet->{'ActionID'}}->{'PARSED'}->{$key} = $packet->{$key};
					}
				}

				#This is actually slower than the above foreach?
				#$ACTIONBUFFER{$packet->{'ActionID'}} = $packet;

				return 1;
			#ActionID but not a Response or an Event?
			#Must be some kind of fragment/partial/corrupt/bad packet
			} else {
				return 0;
			}
		#An event?
		} elsif (exists $packet->{'Event'}) {
			if ($RESPEVENTS && exists $packet->{'ActionID'}) {
				#Update timestamp
				$ACTIONBUFFER{$packet->{'ActionID'}}->{'TIMESTAMP'} = $packet->{'TIMESTAMP'};
				
				#EventCompleted Event?
				if ($packet->{'Event'} =~ $completed) {
					$ACTIONBUFFER{$packet->{'ActionID'}}->{'COMPLETED'} = 1;
					if ($packet->{'Event'} !~ $store) {
						return 1;
					}
				}
		
				push(@{$ACTIONBUFFER{$packet->{'ActionID'}}->{'EVENTS'}}, $packet);
						
			} else {
				push(@EVENTBUFFER, $packet);
			}

			return 1;
		#What the hell is this?
		} else {
			return 0;
		}
	}

	return 0;
}

#Proccesses a packet
#First reads it in and the places it into a buffer
sub _process_packet {
	my ($self) = @_;

	my $packet = $self->_read_packet();

	return $self->_sort_and_buffer($packet);
}

#Generates an  ActionID
sub _gen_actionid {
	my $actionid;

	#Limit the length of our actionID
	#Know limit in asterisk is around 69 characters
	#Limit it sooner just to be safe
	if (length($idseq) < 61) {
		$actionid = $idseq;
	#Reset the counter
	} else {
		$idseq = 1;
		$actionid = $idseq;
	}

	$idseq++;

	return $actionid;
}

#Sends an action to the AMI
#Accepts an Array
#Returns the actionid of the action
sub send_action {
	my ($self, $actionhash) = @_;

	#Create and Action ID
	my $id = _gen_actionid();

	#Store the Action ID
	$lastid = $id;

	$actionhash->{'ActionID'} = $id;

	#Every 100th action clear actions older than 5 minutes
	if (($id % $AUTOCLEAR) == 0) {
		$self->clear_old_actions($AUTOAGE);
	}

	my $action;

	#Create an action out of a hash
	foreach my $key (keys %{$actionhash}) {
		if (ref($actionhash->{$key}) eq 'ARRAY') {
			foreach my $var (@{$actionhash->{$key}}) {
				$action .= $key . ': ' . $var . $EOL;
			}
		} else {
			$action .= $key . ': ' . $actionhash->{$key} . $EOL;
		}
	}

	#End command
	$action .= $EOR;

	#Send it!
	#print $socket $action;
	if (defined($socket->send($action))) {
		$ACTIONBUFFER{$id}->{'SENDTIME'} = time();
		return $id;
	} else {
		$SOCKERR = 1;
		warn "Error writing to socket";
	}


	return 0;
}
#Wait for an action to complete
#also handles socket/connection errors
sub _complete_action {
	my ($self, $actionid, $timeout) = @_;

	my $completed = 0;

	#Disable timeout if none set
	if (!defined $timeout) {
		$timeout = 0;
	}

	eval {
		#local $SIG{ALRM} = sub { print "GOT ALARM!\n"; die "alarm\n" };
		local $SIG{ALRM} = \&_sig_alrm;
		alarm $timeout;

		#We need our command to be completed before we can return it
		while (!exists $ACTIONBUFFER{$actionid}->{'COMPLETED'}) {
			$self->_process_packet();
		}

		$completed = 1;		

		alarm 0;
	};

	if ($@ && $@ eq "alarm\n") {
		warn "Timed out waiting for response to action";
	}

	return $completed;
}

#Checks for a response to an action
#If no actionid is given uses last actionid sent
#Returns 1 if action success, 0 if failure
sub check_response {
	my ($self, $actionid, $timeout) = @_;

	my $return = 0;

	#Check if an actionid was passed, else us last
	if (!defined $actionid) {
		$actionid = $lastid;
	}

	if ($self->_complete_action($actionid, $timeout)) {
		#Straight up positive response?
		if ($ACTIONBUFFER{$actionid}->{'Response'} =~ $amipositive) {
			$return = 1;
		#If it was a 'Follows' then we also need the command to be completed
		#Otherwise shit be broken
		} elsif ($ACTIONBUFFER{$actionid}->{'Response'} eq 'Follows' && exists $ACTIONBUFFER{$actionid}->{'COMPLETED'}) {
			$return = 1;
		}
	}

	return $return;
}

#Returns the Action with all command data and event
#Actions are hash references
#If an actionid is specified returns that action, otherwise uses last actionid sent
#Removes the event from the buffer
sub get_action {
	my ($self, $actionid, $timeout) = @_;

	#The action we will be returning
	my $action;

	#Check if an actionid was passed, else us last
	if (!defined $actionid) {
		$actionid = $lastid;
	}

	#Disable timeout if none set
	if (!defined $timeout) {
		$timeout = 0;
	}

	#Wait for the action to complete
	if ($self->check_response($actionid, $timeout)) {
		$action = $ACTIONBUFFER{$actionid};

		delete $ACTIONBUFFER{$actionid};		
	}

	return $action;
}

#Sends an action and returns its data
#or undef if the command failed
sub action {
	my ($self, $action, $timeout) = @_;
	
	my $data;

	#Send action
	my $actionid = $self->send_action($action);
	
	if ($actionid) {
		#Get response
		$data = $self->get_action($actionid,$timeout);
	}

	return $data;
}

#Sends an action and returns 1 if it was successful
#and 0 if it failed
sub simple_action {
	my ($self, $action, $timeout) = @_;

	my $response = 0;

	#Send action
	my $actionid = $self->send_action($action);

	if ($actionid) {	
		#Check response
		$response = $self->check_response($actionid,$timeout);

		#Clear action out of the buffer
		$self->clear_action($actionid);
	}

	return $response;
}

#Non-blocking check to see if an action is completed yet
sub completed {
	my ($self, $actionid) = @_;

	if (!defined $actionid) {
		$actionid = $lastid;
	}

	if (exists $ACTIONBUFFER{$actionid}->{'COMPLETED'}) {
		return 1;
	}

	return 0;
}

#Logs into the AMI
sub _login {
	my $self = shift;

	my %action = ( 	Action => 'login',
			Username =>  $settings{'Username'},
			Secret =>  $settings{'Secret'}
	);

	$LOGGEDIN = 1;

	if ($self->simple_action(\%action)){
		return 1;
	} else {
		$LOGGEDIN = 0;
		warn "Authentication Failed";
	}

	return 0;
}

#Logs out of the AMI
sub _logoff {
	my $self = shift;

	my %action = (Action => 'logoff');

	if ($self->simple_action(\%action)){
		$LOGGEDIN = 0;
		return 1;
	}

	return 0;
}

#Disconnect from the AMI
#If logged in will first issue a _logoff
sub close {
	my ($self) = @_;

	if (defined($socket)) {
		if ($LOGGEDIN) {
			$self->send_action({ Action => 'logoff' });
		}
		
		$LOGGEDIN = 0;

		return $socket->close();
	
	}

	#No socket? No Problem.
	return 1;
}

#Pops the topmost event out of the buffer and returns it
#Events are hash references
sub get_event {
	my ($self, $timeout) = @_;

	if (!defined $timeout) {
		$timeout = 0;
	}

	my $event = shift @EVENTBUFFER;

	eval {
		local $SIG{ALRM} = \&_sig_alrm;
		alarm $timeout;

		while (!defined $event) {
			$self->_process_packet();
	
			$event = shift @EVENTBUFFER;
		}

		alarm 0;
	};

	if ($@ && $@ eq "alarm\n") {
		warn "Timed out waiting for event";
	}

	return $event;
}

#Returns an event out of the event buffer, or undef if no events are in the list
sub get_buffered_event {
	return shift @EVENTBUFFER;
}

#Clears buffered responses for a specific action id
sub clear_action {
	my ($self, $actionid) = @_;

	if (exists($ACTIONBUFFER{$actionid})) {
		delete $ACTIONBUFFER{$actionid};
	}

	return 1;
}

#Clears all actions in buffer
sub clear_actions {
	undef %ACTIONBUFFER;
	return 1;
}

#Clears actions with no updates older than $age in seconds
sub clear_old_actions {
	my ($self, $age) = @_;

	my $curtime = time();

	if (defined $age) {
		foreach my $action (keys %ACTIONBUFFER) {
			my $old;

			#If we got a packet for the action base the time difference off when it was received
			if (exists $ACTIONBUFFER{$action}->{'TIMESTAMP'}) {
				$old = $ACTIONBUFFER{$action}->{'TIMESTAMP'} - $curtime;
			#Else use the time we sent the packet
			} else {
				$old = $ACTIONBUFFER{$action}->{'SENDTIME'} - $curtime;
			}

			if ($old > $age) {
				delete $ACTIONBUFFER{$action};
			}
		}
	}

	return 1;
}

#Clears events out of the event buffer
#If an event type is supplied only events of that type are cleared
#Examples:
#clear_events()  //clears all events in buffer
#clear_events('PeerStatus') //clears all events of type 'PeerStatus'
sub clear_events {
	my ($self, $type) = @_;

	if (defined($type)) {
		foreach my $event (@EVENTBUFFER) {
			if ($event->{'Event'} eq $type) {
				undef $event;
			}
		}
	} else {	
		undef @EVENTBUFFER;
	}

	return 1;
}

#Clears events older than $age in seconds
sub clear_old_events {
	my ($self, $age) = @_;

	my $curtime = time();

	if (defined $age) {
		@EVENTBUFFER = grep { ($curtime - $_->{'TIMESTAMP'}) > $age } @EVENTBUFFER;
	}
	
	return 1;
}

#Clears events and actions older than $age in seconds
sub clear_old {
	my ($self, $age) = @_;
	
	$self->clear_old_actions($age);

	$self->clear_old_events($age);

	return 1;
}

#Returns server AMI version
sub amiver {
	return $AMIVER;
}

#Checks the connection, returns 1 if the connection is good
sub check_connection {
	my ($self, $timeout) = @_;
	if ($socket->opened()) {	
		return $self->simple_action({ Action => 'Ping'}, $timeout);
	} 

	return 0;
}

#Returns if we have a current error on the socket
sub error {

	if ($SOCKERR) {
		return $SOCKERR;
	}

	return $socket->error();
}

return 1;

