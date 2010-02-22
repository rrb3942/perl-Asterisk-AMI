#!/usr/bin/perl

=head1 NAME

Asterisk::AMI - Perl moduling for interacting with the Asterisk Manager Interface

=head1 VERSION

0.1.6

=head1 SYNOPSIS

	use Asterisk::AMI;
	my $astman = Asterisk::AMI->new(PeerAddr	=>	'127.0.0.1',
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
	Username	Username to access the AMI
	Secret		Secret used to connect to AMI
	BufferSize	Maximum size of buffer, in number of actions
	Timeout		Default timeout of all actions in seconds
	Handlers	Hash reference of Handlers for events	{ 'EVENT' => \&somesub };
	Keepalive	Interval (in seconds) to periodically sends 'Ping' actions to asterisk
	Blocking	Enable/Disable blocking connects	0|1
	on_connect	A subroutine to run after we connect
	on_connect_err	A subroutine to call if we have an error while connecting
	on_error	A subroutine to call when an error occurs on the socket
	on_disconnect	A subroutine to call when the remote end disconnects
	on_timeout	A subroutine to call if our Keepalive times out

	'PeerAddr' defaults to 127.0.0.1.\n
	'PeerPort' defaults to 5038.
	'Events' may be anything that the AMI will accept as a part of the 'Events' parameter for the login action.
	Default is 'off.
	'Username' has no default and must be supplied.
	'Secret' has no default and must be supplied.
	'BufferSize' has a default of 30000. It also acts as our max actionid before we reset the counter.
	'Timeout' has a default of 0, which means no timeout or blocking.
	'Handlers' accepts a hash reference setting a callback handler for the specfied event. EVENT should match the what
	the contents of the {'Event'} key of the event object will be. The handler should be a subroutine reference that
	will be passed the a copy of the AMI object and the event object. The 'default' keyword can be used to set
	a default event handler. If handlers are installed we do not buffer events and instead immediatly dispatch them.
	If no handler is specified for an event type and a 'default' was not set the event is discarded.
	'Keepalive' only works when running with an event loop.
	'Blocking' has a default of 1 (block on connecting). A value of 0 will cause us to queue our connection
	and login for when an event loop is started. If set to non blocking we will always return a valid object.
	'on_connect' is a subroutine to call when we have successfully connected and logged into the asterisk manager.
	it will be passed our AMI object.

	'on_connect_err', 'on_error', 'on_disconnect'
	These three specify subroutines to call when errors occur. 'on_connect_err' is specifically for errors that
	occur while connecting, as well as failed logins. If 'on_connect_err' or 'on_disconnect' it is not set, 
	but 'on_error' is, 'on_error' wil be called. 'on_disconnect' is not reliable, as disconnects seem to get lumped
	under 'on_error' instead. When the subroutine specified for any of theses is called the first argument is a copy
	of our AMI object, and the second is a string containing a message/reason. All three of these are 'fatal', when
	they occur we destroy our buffers and our socket connections.

	'on_timeout' is called when a keepalive has timed out, not when a normal action has. It is non-'fatal'.
	The subroutine will be called with a copy of our AMI object and a message.
	
=head2 Warning - Mixing Eventloops and blocking actions

	If you are running an event loop and use blocking methods (anything that accepts it's timeout outside of 
	the action hash e.g. get_response, check_response, action, connected) the outcome is unspecified. It may work,
	it may lock everything up, the action may work but break something else. I have tested it and behavior seems
	un-predictable at best and is very circumstantial.

	If you are running an eventloop use non-blocking callbacks! It is why they are there!

	However if you do play with blocking methods inside of your loops let me know how it goes.

=head2 Actions

=head3 Construction

No matter which method you use to send an action (send_action(), simple_action(), or action()), they all accept
actions in the same format, which is a hash reference. The only exceptions to this rules are when specifying a
callback and a callback timeout, which only work with send_action.

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

The method get_response() accepts an actionid and will return a Response object (really just a fancy hash) with the 
contents of the Action Response as well as any associated Events it generated. It will return undef if an error 
occured or on timeout.

All responses and events are buffered, therefor you can issue several send_action()s and then retrieve/check their 
responses out of order without losing any information. Infact, if you are issuing many actions in series you can get 
much better performance sending them all first and then retrieving them later, rather than waiting for responses 
immediatly after issuing an action.

Alternativley you can also use simple_action() and action().
simple_action() combines send_action() and check_response(), and therefore returns 1 on success and 0 on failure,
and undef on error or timeout.
action() combines send_action() and get_response(), and therefore returns a Response object or undef.

=head4 Examples

	Send and retrieve and action:
	my $actionid = $astman->send_action({	Action => 'Command',
						Command => 'sip show peers'
				});

	my $response = $astman->get_response($actionid)

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

	my $response3 = $actan->get_response($actionid3);
	my $response1 = $actan->get_response($actionid1);
	my $response2 = $actan->get_response($actionid2);

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

=head3 Callbacks

	You may also specify a method to callback when using send_action as well as a timeout.

	An example of this would be:
	send_action({	Action => 'Ping',
			CALLBACK => \&somemethod,
			TIMEOUT => 7 });

In this example once the action 'Ping' finishes we will call somemethod() and pass it the a copy of our AMI object 
and the Response Object for the action. If TIMEOUT is not specified it will use the default set. A value of 0 means 
no timeout. When the timeout is reached somemethod() will be called and passed the un-completed Response Object, 
therefore somemethod() should check the state of the object. Checking the key {'GOOD'} is usually a good indication if 
the object is useable.

Callback Caveats

Callbacks only work if we are processing packets, therefore you must be running an event loop. Alternatively, we run 
mini-event loops for our blocking calls (e.g. action(), get_action()), so in theory if you set callbacks and then
issue a blocking call those callbacks should also get trigged. However this is an unsupported scenario.

Timeouts are done using timers, depending on how your event loop works it may be relative or absolute. Either way they are
set as soon as you send the object. Therefore if you send an action with a timeout and then monkey around for a long time
before getting back to your event loop (to process input) you can time out before ever even attempting to receive
the response. 

	A very contrived example:
	send_action({	Action => 'Ping',
			CALLBACK => \&somemethod,
			TIMEOUT => 3 });

	sleep(4);

	#Start some loop
	someloop;
	#Oh no we never even tried to get the response yet it will still time out

=head3 ActionIDs

This module handles ActionIDs internally and if you supply one in an action it will simply be ignored and overwritten. 

=head2 Responses and Events

=head3 Responses

	Responses are returned as response objects, which are hash references, structured as follows:

	$response->{'Response'}		Response to our packet (Success, Failed, Error, Pong, etc).
		   {'ActionID'}		ActionID of this Response.
		   {'Message'}		Message line of the response.
		   {'EVENTS'}		Arrary reference containing Event Objects associated with this actionid.
		   {'PARSED'}		Hash refernce of lines we could parse into key->value pairs.
		   {'DATA'}		Array refernce of lines that we could not parse.
		   {'CMD'}		Contains command output from 'Action: Command's. It is an array reference.
		   {'COMPLETED'}	1 if completed, 0 if not (timeout)
		   {'GOOD'}		1 if good, 0 if bad. Good means no errors and COMPLETED.


=head3 Events

	Events are turned into event objects, these are similiar to response objects, but their keys vary much more
	depending on the specific event.

	Some common contents are:

	$event->{'Event'}		The type of Event
		{'ActionID'}		Only available if this event was caused by an action

=head3 Event Handlers

	Here is a very simple example of how to use event handlers.

	my $astman = Asterisk::AMI->new(PeerAddr	=>	'127.0.0.1',
					PeerPort	=>	'5038',
					Username	=>	'admin',
					Secret		=>	'supersecret',
					Events		=>	'on',
					Handlers	=> { default => \&do_event,
							     Hangup => \&do_hangup };
				);

	die "Unable to connect to asterisk" unless ($astman);

	sub do_event {
		my ($asterisk, $event) = @_;

		print 'Yeah! Event Type: ' . $event->{'Event'} . "\r\n";
	}

	sub do_hangup {
		my ($asterisk, $event) = @_;
		print 'Channel ' . $event->{'Channel'} . ' Hungup because ' . $event->{'Cause-txt'} . "\r\n";
	}

	#Start some event loop
	someloop;

=head2 Methods

send_action ( ACTION )

	Sends the action to asterisk. If no errors occured while sending it returns the ActionID for the action,
	which is a positive integer above 0. If it encounters an error it will return undef.
	
check_response( [ ACTIONID ], [ TIMEOUT ] )

	Returns 1 if the action was considered successful, 0 if it failed, or undef on timeout or error. If no ACTIONID
	is specified the ACTIONID of the last action sent will be used. If no TIMEOUT is given it blocks, reading in
	packets until the action completes. This will remove a response from the buffer.

get_response ( [ ACTIONID ], [ TIMEOUT ] )

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

amiver ()

	Returns the version of the Asterisk Manager Interface we are connected to. Undef until a the connection is made
	(important if you have Blocking => 0).
	

connected ( [ TIMEOUT ] )

	This checks the connection to the AMI to ensure it is still functional. It checks at the socket layer and
	also sends a 'PING' to the AMI to ensure it is still responding. If no TIMEOUT is given this will block
	waiting for a response.

	Returns 1 if the connection is good, 0 if it is not.

error ()

	Returns 1 if there are currently errors on the socket, 0 if everything is ok.

destroy ( [ FATAL ] )

	Destroys the contents of all buffers and removes any current callbacks that are set. If FATAL is true
	it will also destroy our IO handle and its associated watcher. Mostly used internally. Useful if you want to
	ensure that our IO handle watcher gets removed. 

=head1 See Also

Asterisk::AMI::Common, Asterisk::AMI::Common::Dev

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

package Asterisk::AMI;

use strict;
use warnings;
use version;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;


#Duh
our $VERSION = qv(0.1.6);

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
#			     {'COMPLETED'}	= 0 or 1				//If the command is completed
#			     {'GOOD'}		= 0 or 1 //if this responses is good, no error, can only be 1 if also COMPLETED
my %ACTIONBUFFER;

my %CALLBACKS;

my $vertical;
#Backwards compatability with 5.8, does not support \v, but on 5.10 \v is much faster than the below char class
{
	no warnings;

	if ($] > 5.010000) {
		$vertical = qr/\v+/;
	} else {
		$vertical = qr/[\x0A-\x0D\x85\x{2028}\x{2029}]+/;
	}
}

#Regex for parsing lines
#my $parse  = qr/^([^:\[]+): (.+)$/;
my $parse  = qr/^([^:]+): ([^:]+)$/;

my $endcommand = qr/--END COMMAND--$/;

#Regex for possible response packet contents
my $respcontents = qr/^(?:Response|Message|ActionID|Privilege|CMD|COMPLETED)$/;

#Trims trailing white space
#When chomp is not enough
my $trim = qr/\s*$/;

#End of line delimiter
my $EOL = "\015\012";

#END of Response Delimiter
my $EOR = $EOL;

my $DELIM = $EOL . $EOR;

#String we expect upon connecting to the AMI
my $amistring = qr/^Asterisk Call Manager\/([0-9]\.[0-9])$/;

#To store the version of the AMI we are connected to
my $AMIVER;

#Regex that will identify positive AMI responses
my $amipositive = qr/^(?:Success|Goodbye|Events Off|Pong|Follows)$/;

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

#Required settings
my @required = ( 'Username', 'Secret' );

#Our AnyEvent::Handle
my $handle;

#A copy of ourselves
my $myself;

#Keep alive Anyevent::Timer
my $keepalive;

#Module wide condvar
#my $process = AnyEvent->condvar;

#Defaults
my $PEER = '127.0.0.1';
my $PORT = '5038';
my $USERNAME;
my $SECRET;
my $EVENTS = 'off';
my $STOREEVENTS = 1;
my $CALLBACK = 0;
my $TIMEOUT = 0;
my $KEEPALIVE;
my $BUFFERSIZE = 30000;
my $BLOCK = 1;
my %EVENTHANDLERS;
my %ON;
my %DISCARD;

#Create a new object and return it;
#If required options are missing, returns undef
sub new {
	my ($class, %values) = @_;

	my $self;

	#Configure our new object, else return undef
	if ($class->_configure(%values)) {
		if ($class->_connect()) {
			$self = $class;
		}
	}

	return $self;
}

#Used by anyevent to load our read type
sub anyevent_read_type {

	my ($handle, $cb) = @_;

	return sub {
		$_[0]{rbuf} =~ s/^(.+)(?:\015\012\015\012)//so or return 0;
		$cb->($_[0], $1);
		return 0;
	}
}

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
	$CALLBACK = $settings{'Callbacks'} if (defined $settings{'Callbacks'});
	$TIMEOUT = $settings{'Timeout'} if (defined $settings{'Timeout'});
	$KEEPALIVE = $settings{'Keepalive'} if (defined $settings{'Keepalive'});
	$BUFFERSIZE = $settings{'BufferSize'} if (defined $settings{'BufferSize'});
	%EVENTHANDLERS = %{$settings{'Handlers'}} if (defined $settings{'Handlers'});
	$BLOCK = $settings{'Blocking'} if (defined $settings{'Blocking'});

	#On Connect
	$ON{'connect'} = $settings{'on_connect'} if (defined $settings{'on_connect'});

	#Error Handling
	$ON{'err_connect'} = $settings{'on_connect_err'} if (defined $settings{'on_connect_err'});
	$ON{'err'} = $settings{'on_error'} if (defined $settings{'on_error'});
	$ON{'disconnect'} = $settings{'on_disconnect'} if (defined $settings{'on_disconnect'});
	$ON{'timeout'} = $settings{'on_timeout'} if (defined $settings{'on_timeout'});

	#We like us
	$myself = $self;
	
	return 1;
}

#Handles connection failures (includes login failure);
sub _on_connect_err {

	my ($self, $fatal, $message) = @_;

	warn "Failed to connect to asterisk - $PEER:$PORT";
	warn "Reason: $message";

	if (exists $ON{'err_connect'}) {
		$ON{'err_connect'}->($self, $message);
	} elsif (exists $ON{'err'}) {
		$ON{'err'}->($self, $message);
	}

	$self->destroy($fatal);

	$SOCKERR = 1;
}

#Handles other errors on the socket
#Fatal is an indication as to if the handle was already destroyed
#If it was we don't try to do it ourselves
sub _on_error {

	my ($self, $fatal, $message) = @_;

	warn "Received Error on socket - $PEER:$PORT";
	warn "Error Message: $message";

	$ON{'err'}->($self, $message) if (exists $ON{'err'});
	
	$self->destroy($fatal);

	$SOCKERR = 1;
}

#Handles the remote end disconnecting
sub _on_disconnect {
	my ($self) = @_;

	my $message = "Remote end disconnected - $PEER:$PORT";
	warn "Remote Asterisk Server ended connection - $PEER:$PORT";

	if (exists $ON{'disconnect'}) {
		$ON{'disconnect'}->($self, $message);
	} elsif (exists $ON{'err'}) {
		$ON{'err'}->($self, $message);
	}

	$self->destroy();

	$SOCKERR = 1;
}

#What happens if our keep alive times out
sub _on_timeout {
	my ($self, $message) = @_;

	warn $message;

	if (exists $ON{'timeout'}) {
		$ON{'timeout'}->($self, $message);
	} elsif (exists $ON{'err'}) {
		$ON{'err'}->($self, $message);
	}

	$SOCKERR = 1;
}

#Things to do after our initial connect
sub _on_connect {

	my ($fh, $line) = @_;

	if ($line =~ $amistring) {
		$AMIVER = $1;
	} else {
		warn "Unknown Protocol/AMI Version from $PEER:$PORT";
	}
			
	$handle->push_read( 'Asterisk::AMI' => \&_handle_packet );

}

#Connects to the AMI
#Returns 1 on success, 0 on failure
sub _connect {
	my ($self) = @_;

	my $process = AnyEvent->condvar;

	$handle = new AnyEvent::Handle(
		connect => [$PEER => $PORT],
		on_connect_err => sub { $process->send(0) if ($BLOCK); $self->_on_connect_err(1,$_[1]); },
		on_error => sub { $self->_on_error($_[1],$_[2]) },
		on_eof => sub { $self->_on_disconnect; },
		on_connect => sub { $handle->push_read( line => \&_on_connect ); }
	);

	return $self->_login if ($BLOCK); 

	#Queue our login
	$self->_login;

	return 0 unless ($handle);

        return 1;
}

#Reads in and parses packet from the AMI
#Creates a hash
# Response: Success stores 'Success' in %packet{'Response'}, etc.
#Returns a hash of the parsed packet
sub _handle_packet {

	my ($self, $packets) = @_;

	foreach my $packet (split /$DELIM/o, $packets) {

		my %parsed;

		foreach my $line (split /$EOL/o, $packet) {
			#Can we parse and store this line nicely in a hash?
			if ($line =~ $parse) {
				$parsed{$1} = $2;
			#Is this our command output?
			} elsif ($line =~ $endcommand) {
				$parsed{'COMPLETED'} = 1;

				push(@{$parsed{'CMD'}}, grep { s/$trim//o } split(/$vertical/o, $line));

				#Get rid of the '---END COMMAND---'
				pop @{$parsed{'CMD'}};
			} elsif ($line) {
				push(@{$parsed{'DATA'}}, $line);
			}
		}

		_sort_and_buffer(\%parsed);
	}

	return 1;
}

#Sorts a packet and places into the appropriate buffer
#Returns 1 on buffered, 0 on discard
sub _sort_and_buffer {

	my ($packet) = @_;

	if (exists $packet->{'ActionID'}) {

		#Snag our actionid
		my $actionid = $packet->{'ActionID'};

		return if ($DISCARD{$actionid});

		if (exists $packet->{'Response'}) {
			#No indication of future packets, mark as completed
			if ($packet->{'Response'} ne 'Follows') {
				if (!exists $packet->{'Message'} || $packet->{'Message'} !~ $follows) {
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
			my $save = 1;
				
			#EventCompleted Event?
			if ($packet->{'Event'} =~ $completed) {
				$ACTIONBUFFER{$actionid}->{'COMPLETED'} = 1;
				$save = 0 unless ($packet->{'Event'} =~ $store);
			}
		
			push(@{$ACTIONBUFFER{$actionid}->{'EVENTS'}}, $packet) if $save;
		}

		#This block handles callbacks
		if ($ACTIONBUFFER{$actionid}->{'COMPLETED'}) {
			return 0 unless (exists $ACTIONBUFFER{$actionid}->{'Response'});
			$ACTIONBUFFER{$actionid}->{'GOOD'} = 1 if ($ACTIONBUFFER{$actionid}->{'Response'} =~ $amipositive);

			if (defined $CALLBACKS{$actionid}->{'cb'}) {
				#Stuff needed to process callback
				my $callback = $CALLBACKS{$actionid}->{'cb'};
				my $action = $ACTIONBUFFER{$actionid};

				#cleanup
				delete $ACTIONBUFFER{$actionid};
				delete $CALLBACKS{$actionid};
				delete $DISCARD{$actionid};
				$callback->($myself, $action);
			}
		}

	#Is it an event? Are events on? Discard otherwise
	} elsif (exists $packet->{'Event'}) {

		#If handlers were configured just dispatch, don't buffer
		if (%EVENTHANDLERS) {
			if (exists $EVENTHANDLERS{$packet->{'Event'}}) {
				$EVENTHANDLERS{$packet->{'Event'}}->($myself, $packet);
			} elsif (exists $EVENTHANDLERS{'default'}) {
				$EVENTHANDLERS{'default'}->($myself, $packet);
			}
		} else {
			#Someone is waiting on this packet, don't bother buffering
			if (exists $CALLBACKS{'EVENT'}) {
				$CALLBACKS{'EVENT'}->{'cb'}->($packet);
				delete $CALLBACKS{'EVENT'};
			#Save for later
			} else {
				push(@EVENTBUFFER, $packet);
			}
		}

	#Not a response, not an Event, bad packet
	} else {
		return 0;
	}

	return 1;
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

sub _wait_response {
	my ($id, $timeout) =  @_;

	unless ($ACTIONBUFFER{$id}->{'COMPLETED'}) {

		my $process = AnyEvent->condvar;

		$CALLBACKS{$id}->{'cb'} = sub { $process->send($_[1]) };
		$timeout = $TIMEOUT unless (defined $timeout);

		if ($timeout) {
			$CALLBACKS{$id}->{'timeout'} = sub {
					my $response = $ACTIONBUFFER{$id};
					delete $ACTIONBUFFER{$id};
					delete $CALLBACKS{$id};
					$DISCARD{$id} = 1;
					$process->send($response);
				};

			$CALLBACKS{$id}->{'timer'} = AnyEvent->timer(after => $timeout, cb => $CALLBACKS{$id}->{'timeout'}); 
		}

		return $process->recv;
	}

	my $resp = $ACTIONBUFFER{$id};
	delete $ACTIONBUFFER{$id};
	return $resp;
}

#Sends an action to the AMI
#Accepts an Array
#Returns the actionid of the action
sub send_action {
	my ($self, $actionhash) = @_;

	return unless ($handle);

	#Create and Action ID
	my $id = _gen_actionid();

	#Store the Action ID
	$lastid = $id;

	#Delete anything that might be in the buffer
	delete $ACTIONBUFFER{$id};
	delete $CALLBACKS{$id};

	unless (defined $actionhash->{'TIMEOUT'}) {
		$actionhash->{'TIMEOUT'} = $TIMEOUT;
	}

	if (defined $actionhash->{'CALLBACK'}) {
		$CALLBACKS{$id}->{'cb'} = $actionhash->{'CALLBACK'};
		if ($actionhash->{'TIMEOUT'}) {
			$CALLBACKS{$id}->{'timeout'} = sub {
					my $response = $ACTIONBUFFER{$id};
					my $callback = $CALLBACKS{$id}->{'cb'};
					delete $ACTIONBUFFER{$id};
					delete $CALLBACKS{$id};
					$DISCARD{$id} = 1;
					$callback->($self, $response);;
				};
			$CALLBACKS{$id}->{'timer'} = AnyEvent->timer(after => $actionhash->{'TIMEOUT'}, cb => $CALLBACKS{$id}->{'timeout'}); 
		}
	}

	delete $actionhash->{'TIMEOUT'};
	delete $actionhash->{'CALLBACK'};

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
	$handle->push_write($action);
	$ACTIONBUFFER{$id}->{'COMPLETED'} = 0;
	$ACTIONBUFFER{$id}->{'GOOD'} = 0;
	$DISCARD{$id} = 0;

	return $id;
}

#Checks for a response to an action
#If no actionid is given uses last actionid sent
#Returns 1 if action success, 0 if failure
sub check_response {
	my ($self, $actionid, $timeout) = @_;

	#Check if an actionid was passed, else us last
	$actionid = $lastid unless (defined $actionid);

	my $return;

	my $resp = _wait_response($actionid, $timeout);

	$return = $resp->{'GOOD'} if $resp->{'COMPLETED'};

	return $return;
}

#Returns the Action with all command data and event
#Actions are hash references
#If an actionid is specified returns that action, otherwise uses last actionid sent
#Removes the event from the buffer
sub get_response {
	my ($self, $actionid, $timeout) = @_;

	#Check if an actionid was passed, else us last
	$actionid = $lastid unless (defined $actionid);

	#The action we will be returning
	my $resp = _wait_response($actionid, $timeout);

	#Wait for the action to complete
	undef $resp unless ($resp->{'COMPLETED'});

	return $resp;
}

#Sends an action and returns its data
#or undef if the command failed
sub action {
	my ($self, $action, $timeout) = @_;
	
	my $resp;

	#Send action
	my $actionid = $self->send_action($action);
	
	#Get response
	$resp = $self->get_response($actionid,$timeout) if (defined $actionid);

	return $resp;
}

#Sends an action and returns 1 if it was successful
#and 0 if it failed
sub simple_action {
	my ($self, $action, $timeout) = @_;

	my $response;

	#Send action
	my $actionid = $self->send_action($action);

	if (defined $actionid) {

		my $resp = _wait_response($actionid, $timeout);
		$response = $resp->{'GOOD'} if ($resp->{'COMPLETED'});
	}

	return $response;
}

#Logs into the AMI
sub _login {
	my $self = shift;

	my %action = ( 	Action => 'login',
			Username =>  $USERNAME,
			Secret => $SECRET,
			Events => $EVENTS
	);

	if ($BLOCK) {
		if ($self->simple_action(\%action)){
			$LOGGEDIN = 1;
			$ON{'connect'}->($self) if (defined $ON{'connect'});
			return 1;
		} else {
			$LOGGEDIN = 0;
			warn "Authentication Failed";
		}
	} else {
		$action{'CALLBACK'} = sub {
					if ($_[1]->{'GOOD'}) {	
						$LOGGEDIN = 1;
						$ON{'connect'}->($self) if (defined $ON{'connect'});
					} else {
						my $message;

						if ($_[1]->{'COMPLETED'}) {
							$message = "Login Failed to Asterisk at $PEER:$PORT";
						} else {
							$message = "Login Failed to Asterisk due to timeout at $PEER:$PORT"
						}
						
						$self->_on_connect_err(0 ,$message);
					} 
		};

		$action{'TIMEOUT'} = 5 unless ($TIMEOUT);

		$self->send_action(\%action);

		#Set keep alive;
		$keepalive = AnyEvent-> timer (	after => $KEEPALIVE,
						interval => $KEEPALIVE,
						cb => \&_send_keepalive
						) if ($KEEPALIVE);

		return 1;
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

	$self->destroy(1);

	#No socket? No Problem.
	return 1;
}

#Pops the topmost event out of the buffer and returns it
#Events are hash references
sub get_event {
	my ($self, $timeout) = @_;

	$timeout = $TIMEOUT unless (defined $timeout);

	unless (defined $EVENTBUFFER[0]) {

		my $process = AnyEvent->condvar;

		$CALLBACKS{'EVENT'}->{'cb'} = sub { $process->send($_[0]) };
		$CALLBACKS{'EVENT'}->{'timeout'} = sub { warn "Timed out waiting for event"; $process->send(undef); };

		$timeout = $TIMEOUT unless (defined $timeout);

		if ($timeout) {
			$CALLBACKS{'EVENT'}->{'timer'} = AnyEvent->timer(after => $timeout, cb => $CALLBACKS{'EVENT'}->{'timeout'}); 
		}

		return $process->recv;
	}

	return shift @EVENTBUFFER;
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

#Check whether there was an error on the socket
sub error {
	return $SOCKERR;
}

#Sends a keep alive
sub _send_keepalive {

	#my ($self) = @_;

	my $timeout = 5 unless ($TIMEOUT);

	my %action = (	Action => 'Ping',
			CALLBACK => sub { $myself->_on_timeout("Asterisk failed to respond to keepalive - $PEER:$PORT") unless ($_[1]->{'GOOD'}); },
			TIMEOUT => $timeout
		);
	
	$myself->send_action(\%action);
}

#Cleans up 
sub destroy {
	my ($self, $fatal) = @_;
	undef %CALLBACKS;
	undef %ACTIONBUFFER;
	undef @EVENTBUFFER;
	unless ($fatal) {
		$handle->destroy;
		undef $handle;
	};
}

return 1;

