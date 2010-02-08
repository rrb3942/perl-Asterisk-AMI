#!/usr/bin/perl

=head1 NAME

AMI - Perl moduling for interacting with the Asterisk Manager Interface

=head1 VERSION

0.1.2

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

This module provides an interface to the Asterisk Manager Interface. It's goal is to provide a flexible, powerful, and reliable way to
interact with Asterisk upon which other applications may be built.

=head2 Constructor

=head3 new([ARGS])

Creates a new AMI object which takes the arguments as key-value pairs.

	Key-Value Pairs accepted:
	PeerAddr	Remote host address	<hostname>
	PeerPort	Remote host port	<service>
	Events		Enable/Disable Events		'on'|'off'
	ResponseEvents	Match Events to Actions 	0 | 1
	Username	Username to access the AMI
	Secret		Secret used to connect to AMI
	BufferSize	Maximum size of buffer, in number of actions
	Timeout		Default timeout of all actions in seconds

	'PeerAddr' defaults to 127.0.0.1.\n
	'PeerPort' defaults to 5038.
	'Events' may be anything that the AMI will accept as a part of the 'Events' parameter for the login action.
	Default is 'off.
	'ResponseEvents' defaults controls whether or not events associated with an action are matched to and stored
	with the response to that action. The default value of 1 groups Events with their actions.
	'Username' has no default and must be supplied.
	'Secret' has no default and must be supplied.
	'BufferSize' has a default of 30000. It also acts as our max actionid before we reset the counter.
	'Timeout' has a default of 0, which means no timeout.

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
ActionID of the action, on success and will return undef in the event it is unable to send the action.
	
After sending an action you can then get its response in one of two methods.

The method check_response() accepts an actionid and will return 1 if the action was considered successful, 0 if 
it failed and undef if an error occured or on timeout.

The method get_action() accepts an actionid and will return a Response object (really just a fancy hash) with the 
contents of the Action Response as well as any associated Events it generated. It will return undef if an error 
occured or on timeout.

All responses and events are buffered, therefor you can issue several send_action()s and then retrieve/check their 
responses out of order without losing any information. Infact, if you are issuing many actions in series you can get 
much better performance sending them all first and then retrieving them later, rather than waiting for responses 
immediatly after issuing an action.

Alternativley you can also use simple_action() and action().
simple_action() combines send_action() and check_response(), and therefore returns 1 on success and 0 on failure,
and undef on error or timeout.
action() combines send_action() and get_action(), and therefore returns a Response object or undef.

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

process_packet ( [TIMEOUT )

	Tells the AMI object to process input from asterisk. Returns 1 if it succesfully read in a packet and buffered it.
	Returns 0 if it failed to read in a packet and buffer it. If this fails you should check your connection. 

send_action ( ACTION )

	Sends the action to asterisk. If no errors occured while sending it returns the ActionID for the action,
	which is a positive integer above 0. If it encounters an error it will return undef.
	
check_response( [ ACTIONID ], [ TIMEOUT ] )

	Returns 1 if the action was considered successful, 0 if it failed, or undef on timeout or error. If no ACTIONID
	is specified the ACTIONID of the last action sent will be used. If no TIMEOUT is given it blocks, reading in
	packets until the action completes. Unlike get_action, this will not remove a response from the buffer.

get_action ( [ ACTIONID ], [ TIMEOUT ] )

	Returns the response object for the action. Returns undef on error or timeout.
	If no ACTIONID is specified the ACTIONID of the last action sent will be used. If no TIMEOUT is given it 
	blocks, reading in packets until the action completes. This will remove the response from the buffer.

action ( ACTION [, TIMEOUT ] )

	Sends the action and returns the response object for the action. Returns undef on error or timeout.
	If no ACTIONID is specified the ACTIONID of the last action sent will be used.
	If no TIMEOUT is given it blocks, reading in packets until the action completes. This will remove the
	response from the buffer.

simple_action ( ACTION [, TIMEOUT ] )

	Sends the action and returns 1 if the action was considered successful, 0 if it failed, or undef on error
	and timeout. If no ACTIONID is specified the ACTIONID of the last action sent will be used. If no TIMEOUT is
	given it blocks, reading in packets until the action completes. This will remove the response from the buffer.

completed ( ACTIONID )

	This does a non-blocking check to see if an action an action has completed and been read into the buffer.
	If no ACTIONID is given the ACTIONID of the last action sent will be used.
	It returns 1 if the action has completed and 0 if it has not.
	This will not remove the response from the buffer.

disconnect ()

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

	This removes all responses and events older than MAXAGE seconds ago. If MAXAGE is not given, nothing will
	be removed.

amiver ()

	Returns the version of the Asterisk Manager Interface we are connected to.

connected ( [ TIMEOUT ] )

	This checks the connection to the AMI to ensure it is still functional. It checks at the socket layer and
	also sends a 'PING' to the AMI to ensure it is still responding. If no TIMEOUT is given this will block
	waiting for a response.

	Returns 1 if the connection is good, 0 if it is not.

error ()

	Returns 1 if there are currently errors on the socket, 0 if everything is ok.

=head1 See Also

AMI::Common, AMI::Common::Dev, AMI::Events

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
#Hashes to build actions? Done
#Perf Testing? More references? 30000 actions in 11-13 seconds with asterisk on local system
#Pre-clear actions when sending (delete ACTIONBUFFER{id}) could replace periodic cleanse?
#Linked to above -> Set max increment id
#send_action should return undef on err
#Default timeout? Done

package AMI;

use strict;
use warnings;
use IO::Socket::INET;
use Digest::MD5;
use version;

#Duh
our $VERSION = qv(0.1.2);

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
my $amipositive = qr/^(?:Success|Goodbye|Events Off|Pong|Follows)$/;

#Regex to identify the end of an action via Event
my $completed  = qr/[cC]omplete|^(?:DBGetResponse)$/;
my $store = qr/^(?:DBGetResponse)$/;

#Die string sent from our alarm timeouts
my $die = "alarm\n";

#Regex to identify responses with things yet to come
my $follows = qr/[fF]ollow/;

#Keep track of socket errors
my $SOCKERR = 0;

#ActionID Sequence number, gets incremented
my $idseq = 1;

#ActionID of the last command sent
my $lastid;

#Required settings
my @required = ( 'Username', 'Secret' );

#Defaults
my $PEER = '127.0.0.1';
my $PORT = '5038';
my $USERNAME;
my $SECRET;
my $EVENTS = 'off';
my $STOREEVENTS = 1;
my $RESPEVENTS = 1;
my $TIMEOUT = 0;
my $BUFFERSIZE = 30000;

#Create a new object and return it;
#If required options are missing, returns undef
sub new {
	my ($class, %values) = @_;

	my $self;

	#Configure our new object, else return undef
	if ($class->_configure(%values)) {
		my $socket = $class->_connect();

		$class = bless($socket, $class);
		if ($class->_login()) {
			$self = $class;
		}
	}

	return $self;
}

#Sub to use for alarms
sub _sig_alrm { die $die };

#Sets variables for this object
#Also checks for minimum settings
#Returns 1 if everything was set, 0 if options were missing
sub _configure {
	my ($self, %settings) = @_;

	#Check for required options
	foreach my $req (@required) {
		if (!exists $settings{$req}) {
			return 0;
		}
	}

	#Set values
	$PEER = $settings{'PeerAddr'} if (defined $settings{'PeerAddr'});
	$PORT = $settings{'PeerPort'} if (defined $settings{'PeerPort'});
	$USERNAME = $settings{'Username'} if (defined $settings{'Username'});
	$SECRET = $settings{'Secret'} if (defined $settings{'Secret'});
	$EVENTS = $settings{'Events'} if (defined $settings{'Events'});
	$STOREEVENTS = 0 if ($EVENTS eq 'off');
	$RESPEVENTS = $settings{'ResponseEvents'} if (defined $settings{'ResponseEvents'});
	$TIMEOUT = $settings{'Timeout'} if (defined $settings{'Timeout'});
	$BUFFERSIZE = $settings{'BufferSize'} if (defined $settings{'BufferSize'});

	return 1;
}

#Connects to the AMI
#Returns 1 on success, 0 on failure
sub _connect {
	my $socket = IO::Socket::INET->new (	PeerAddr =>	$PEER,
						PeerPort =>	$PORT,
						Proto =>	'tcp'
	);

	if ($socket) {
		$socket->autoflush(1);
		my $line = <$socket>;
		$line =~ s/$trim//;
		if ($line =~ $amistring) {
			$AMIVER = $1;
		} else {
			warn "Connection Failed: Unknown Protocol/AMI Version";
		}
	} else {
		warn "Connection Refused";
	}

	return $socket;
}

#Reads in and parses packet from the AMI
#Creates a hash
# Response: Success stores 'Success' in %packet{'Response'}, etc.
#Returns a hash of the parsed packet
sub _read_packet {
	my ($self) = @_;

	my %packet;

	while (defined(my $line = <$self>)) {
		#Trim trailing whitespace
		$line =~ s/$trim//;

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

	if (exists $packet->{'ActionID'}) {
		#Snag our actionid
		my $actionid = $packet->{'ActionID'};

		if (exists $packet->{'Response'}) {
			#No indication of future packets, mark as completed
			if ($packet->{'Response'} ne 'Follows') {
				if (!exists $packet->{'Message'} || (!$RESPEVENTS || $packet->{'Message'} !~ $follows)) {
					$packet->{'COMPLETED'} = 1;
				}
			} 

			#Copy the response into the buffer
			#We dont just assign the hash reference to the ActionID becase it is possible, though unlikely
			#that event data can arrive for an action before the response packet
			while (my ($key, $value) = each %{$packet}) {
				if ($key =~ $respcontents) {
					$ACTIONBUFFER{$actionid}->{$key} =  $value;
				} elsif ($key eq 'DATA') {
					push(@{$ACTIONBUFFER{$actionid}->{$key}}, @{$value});
				} else {
					$ACTIONBUFFER{$actionid}->{'PARSED'}->{$key} = $value;
				}
			}
			
		} elsif (exists $packet->{'Event'}) {
			if ($RESPEVENTS) {
				#Update timestamp
				$ACTIONBUFFER{$actionid}->{'TIMESTAMP'} = $packet->{'TIMESTAMP'};
				
				#EventCompleted Event?
				if ($packet->{'Event'} =~ $completed) {
					$ACTIONBUFFER{$actionid}->{'COMPLETED'} = 1;
					if ($packet->{'Event'} !~ $store) {
						return 1;
					}
				}
		
				push(@{$ACTIONBUFFER{$actionid}->{'EVENTS'}}, $packet);
				
			} else {
				push(@EVENTBUFFER, $packet);
			}
		}
	#Is it an event? Are events on? Discard otherwise
	} elsif (exists $packet->{'Event'} && $STOREEVENTS) {
				push(@EVENTBUFFER, $packet);
	#Not a response, not an Event, bad packet
	} else {
		return 0;
	}

	return 1;
}

#Publicly available version of _process_packet with a supported timeout
sub process_packet {

	my ($self, $timeout) = @_;

	$timeout = $TIMEOUT unless (defined $timeout);

	my $packet;

	my $eval = eval {
		local $SIG{ALRM} = \&_sig_alrm;
		alarm $timeout;

		$packet = $self->_read_packet();

		alarm 0;
	};

	#Timeout
	warn "Timed out waiting for event" unless (defined $eval);

	return $self->_sort_and_buffer($packet);
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

	#Reset the seq number if we hit our max
	$idseq = 1 if ($idseq > $BUFFERSIZE);

	$actionid = $idseq;

	$idseq++;

	return $actionid;
}

#Sends an action to the AMI
#Accepts an Array
#Returns the actionid of the action
sub send_action {
	my ($self, $actionhash) = @_;

	my $return;

	#Create and Action ID
	my $id = _gen_actionid();

	#Store the Action ID
	$lastid = $id;

	#Delete anything that might be in the buffer
	delete $ACTIONBUFFER{$id};

	my $action;

	#Create an action out of a hash
	while (my ($key, $value) = each(%{$actionhash})) {

		#Clean out user ActionIDs
		next if (lc $key eq 'actionid');

		if (ref($value) eq 'ARRAY') {
			foreach my $var (@{$value}) {
				$action .= $key . ': ' . $var . $EOL;
			}
		} else {
			$action .= $key . ': ' . $value . $EOL;
		}
	}

	#Append ActionID and End Command
	$action .= 'ActionID: ' . $id . $EOL . $EOR;	

	#Send it!
	if (print $self $action) {
		$ACTIONBUFFER{$id}->{'SENDTIME'} = time();
		$return = $id;
	} else {
		$SOCKERR = 1;
		warn "Error writing to socket";
	}


	return $return;
}
#Wait for an action to complete
#also handles socket/connection errors
sub _complete_action {
	my ($self, $actionid, $timeout) = @_;

	my $complete;

	#Disable timeout if none set
	$timeout = $TIMEOUT unless (defined $timeout);

	my $eval = eval {
		local $SIG{ALRM} = \&_sig_alrm;
		alarm $timeout;

		#We need our command to be completed before we can return it
		until (exists $ACTIONBUFFER{$actionid}->{'COMPLETED'}) {
			$self->_process_packet() or return 0;
		}

		$complete = 1;		

		alarm 0;
	};

	warn "Timed out waiting for event" unless (defined $eval);

	return $complete;
}

#Checks for a response to an action
#If no actionid is given uses last actionid sent
#Returns 1 if action success, 0 if failure
sub check_response {
	my ($self, $actionid, $timeout) = @_;

	#Check if an actionid was passed, else us last
	$actionid = $lastid unless (defined $actionid);

	my $return;

	if ($self->_complete_action($actionid, $timeout)) {
		#Positive response?
		if ($ACTIONBUFFER{$actionid}->{'Response'} =~ $amipositive) {
			$return = 1;
		} else {
			$return = 0;
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

	#Check if an actionid was passed, else us last
	$actionid = $lastid unless (defined $actionid);

	#The action we will be returning
	my $action;

	#Wait for the action to complete
	$action = $ACTIONBUFFER{$actionid} if $self->_complete_action($actionid, $timeout);

	#clear it out of the buffer
	delete $ACTIONBUFFER{$actionid};		

	return $action;
}

#Sends an action and returns its data
#or undef if the command failed
sub action {
	my ($self, $action, $timeout) = @_;
	
	my $data;

	#Send action
	my $actionid = $self->send_action($action);
	
	#Get response
	$data = $self->get_action($actionid,$timeout) if (defined $actionid);

	return $data;
}

#Sends an action and returns 1 if it was successful
#and 0 if it failed
sub simple_action {
	my ($self, $action, $timeout) = @_;

	my $response;

	#Send action
	my $actionid = $self->send_action($action);

	if (defined $actionid) {
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

	$actionid = $lastid unless (defined $actionid);

	if ($ACTIONBUFFER{$actionid}->{'COMPLETED'}) {
		return 1;
	}

	return 0;
}

#Logs into the AMI
sub _login {
	my $self = shift;

	my %action = ( 	Action => 'login',
			Username =>  $USERNAME,
			Secret =>  $SECRET
	);

	if ($self->simple_action(\%action)){
		$LOGGEDIN = 1;
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

	if ($self->simple_action(\%action)) {
		$LOGGEDIN = 0;
		return 1;
	}

	return 0;
}

#Disconnect from the AMI
#If logged in will first issue a _logoff
sub disconnect {
	my ($self) = @_;

	$self->send_action({ Action => 'logoff' }) if ($LOGGEDIN);
		
	$LOGGEDIN = 0;

	close($self);
	
	#No socket? No Problem.
	return 1;
}

#Pops the topmost event out of the buffer and returns it
#Events are hash references
sub get_event {
	my ($self, $timeout) = @_;

	$timeout = $TIMEOUT unless (defined $timeout);

	my $event = shift @EVENTBUFFER;

	my $eval = eval {
		local $SIG{ALRM} = \&_sig_alrm;
		alarm $timeout;

		until (defined $event) {
			$self->_process_packet() or return 0;

			$event = shift @EVENTBUFFER;
		}

		alarm 0;
	};

	warn "Timed out waiting for event" unless (defined $eval);

	return $event;
}

#Returns an event out of the event buffer, or undef if no events are in the list
sub get_buffered_event {
	return shift @EVENTBUFFER;
}

#Clears buffered responses for a specific action id
sub clear_action {
	my ($self, $actionid) = @_;

	delete $ACTIONBUFFER{$actionid}	if (defined $actionid);

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

			my $old = ($ACTIONBUFFER{$action}->{'TIMESTAMP'} || $ACTIONBUFFER{$action}->{'SENDTIME'}) - $curtime;

			delete $ACTIONBUFFER{$action} if ($old > $age);
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

	if (defined $type) {
		foreach my $event (@EVENTBUFFER) {
			undef $event if ($event->{'Event'} eq $type);
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
sub connected {
	my ($self, $timeout) = @_;
	
	my $return = 0;

	if ($self) {	
		$return = 1 if ($self->simple_action({ Action => 'Ping'}, $timeout));
	} 

	return $return;
}

#Returns if we have a current error on the socket
sub error {
	return $SOCKERR;
}

return 1;

