#!/usr/bin/perl

=head1 NAME

Asterisk::AMI - Perl module for interacting with the Asterisk Manager Interface

=head1 VERSION

0.2.1

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

This module provides an interface to the Asterisk Manager Interface. It's goal is to provide a flexible, powerful, and
reliable way to interact with Asterisk upon which other applications may be built. It utilizes AnyEvent and therefore
can integrate very easily into event-based applications, but it still provides blocking functions for us with standard
scripting.

=head2 SSL SUPPORT INFORMAION

For SSL support you will also need the module that AnyEvent::Handle uses for SSL support, which is not a required dependency.
Currently that module is 'Net::SSLeay' (AnyEvent:Handle version 5.251) but it may change in the future.

=head3 CentOS/Redhat

If the version of Net:SSLeay included in CentOS/Redhat does not work try installing an updated version from CPAN.

=head2 Constructor

=head3 new([ARGS])

Creates a new AMI object which takes the arguments as key-value pairs.

	Key-Value Pairs accepted:
	PeerAddr	Remote host address	<hostname>
	PeerPort	Remote host port	<service>
	Events		Enable/Disable Events		'on'|'off'
	Username	Username to access the AMI
	Secret		Secret used to connect to AMI
	AuthType	Authentication type to use for login	'plaintext'|'MD5'
	UseSSL		Enables/Disables SSL for the connection	0|1
	BufferSize	Maximum size of buffer, in number of actions
	Timeout		Default timeout of all actions in seconds
	Handlers	Hash reference of Handlers for events	{ 'EVENT' => \&somesub };
	Keepalive	Interval (in seconds) to periodically send 'Ping' actions to asterisk
	TCP_Keepalive	Enables/Disables SO_KEEPALIVE option on the socket	0|1
	Blocking	Enable/Disable blocking connects	0|1
	on_connect	A subroutine to run after we connect
	on_connect_err	A subroutine to call if we have an error while connecting
	on_error	A subroutine to call when an error occurs on the socket
	on_disconnect	A subroutine to call when the remote end disconnects
	on_timeout	A subroutine to call if our Keepalive times out
	OriginateHack	Changes settings to allow Async Originates to work 0|1

	'PeerAddr' defaults to 127.0.0.1.
	'PeerPort' defaults to 5038.
	'Events' default is 'off'. May be anything that the AMI will accept as a part of the 'Events' parameter for the 
	login action.
	'Username' has no default and must be supplied.
	'Secret' has no default and must be supplied.
	'AuthType' sets the authentication type to use for login. Default is 'plaintext'.  Use 'MD5' for MD5 challenge
	authentication.
	'UseSSL' defaults to 0 (no ssl). When SSL is enabled the default PeerPort changes to 5039.
	'BufferSize' has a default of 30000. It also acts as our max actionid before we reset the counter.
	'Timeout' has a default of 0, which means no timeout on blocking.
	'Handlers' accepts a hash reference setting a callback handler for the specified event. EVENT should match
	the contents of the {'Event'} key of the event object will be. The handler should be a subroutine reference that
	will be passed the a copy of the AMI object and the event object. The 'default' keyword can be used to set
	a default event handler. If handlers are installed we do not buffer events and instead immediately dispatch them.
	If no handler is specified for an event type and a 'default' was not set the event is discarded.
	'Keepalive' only works when running with an event loop. Used with on_timeout, this can be used to detect if
	asterisk has become un-responsive.
	'TCP_Keepalive' default is disabled. Activates the tcp keep-alive at the socket layer. This does not require 
	an event-loop and is lightweight. Useful for applications that use long-lived connections to Asterisk but 
	do not run an event loop.
	'Blocking' has a default of 1 (block on connecting). A value of 0 will cause us to queue our connection
	and login for when an event loop is started. If set to non blocking we will always return a valid object.

	'on_connect' is a subroutine to call when we have successfully connected and logged into the asterisk manager.
	it will be passed our AMI object.

	'on_connect_err', 'on_error', 'on_disconnect'
	These three specify subroutines to call when errors occur. 'on_connect_err' is specifically for errors that
	occur while connecting, as well as failed logins. If 'on_connect_err' or 'on_disconnect' it is not set, 
	but 'on_error' is, 'on_error' will be called. 'on_disconnect' is not reliable, as disconnects seem to get lumped
	under 'on_error' instead. When the subroutine specified for any of theses is called the first argument is a copy
	of our AMI object, and the second is a string containing a message/reason. All three of these are 'fatal', when
	they occur we destroy our buffers and our socket connections.

	'on_timeout' is called when a keep-alive has timed out, not when a normal action has. It is non-'fatal'.
	The subroutine will be called with a copy of our AMI object and a message.

	'OriginateHack' defaults to 0 (off). This essentially enables 'call' events and says 'discard all events
	unless the user has explicitly enabled events' (prevents a memory leak). It does its best not to mess up
	anything you have already set. Without this, if you use 'Async' with an 'Originate' the action will timeout
	or never callback. You don't need this if you are already doing work with events, simply add 'call' events
	to your eventmask. 
	
=head2 Warning - Mixing Event-loops and blocking actions

	If you are running an event loop and use blocking methods (e.g. get_response, check_response, action,
	simple_action, connected) the outcome is unspecified. It may work, it may lock everything up, the action may
	work but break something else. I have tested it and behavior seems unpredictable at best and is very
	circumstantial.

	If you are running an event-loop use non-blocking callbacks! It is why they are there!

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
it failed and undef if an error occurred or on timeout.

The method get_response() accepts an actionid and will return a Response object (really just a fancy hash) with the 
contents of the Action Response as well as any associated Events it generated. It will return undef if an error 
occurred or on timeout.

All responses and events are buffered, therefor you can issue several send_action()s and then retrieve/check their 
responses out of order without losing any information. In-fact, if you are issuing many actions in series you can get 
much better performance sending them all first and then retrieving them later, rather than waiting for responses 
immediately after issuing an action.

Alternatively you can also use simple_action() and action().
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

	my $response3 = $astman->get_response($actionid3);
	my $response1 = $astman->get_response($actionid1);
	my $response2 = $astman->get_response($actionid2);

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

=head3 Originate Examples

	I see enough searches hit my site for this that I figure it should be included in the documentation.
	These don't include non-blocking examples, please read the section on 'Callbacks' below for information
	on using non-blocking callbacks and events.

	NOTE: Please read about the 'OriginateHack' option for the constructor above if you plan on using the 'Async'
	option in your Originate command, as it may be required to properly retrieve the response.

	In these examples we are dialing extension '12345' at a sip peer named 'peer' and when the call connects
	we drop the channel into 'some_context' at priority 1 for extension 100.

	Example 1 - A simple non-ASYNC Originate

	my $response = $astman->action({Action => 'Originate',
					Channel => 'SIP/peer/12345',
					Context => 'some_context',
					Exten => 100,
					Priority => 1});

	And the contents of respone will look similiar to the following:

	{
		'Message' => 'Originate successfully queued',
		'ActionID' => '3',
		'GOOD' => 1,
		'COMPLETED' => 1,
		'Response' => 'Success'
        };

	Example 2 - Originate with multiple variables
	This will set the channel variables 'var1' and 'var2' to 1 and 2, respectfully.
	The value for the 'Variable' key should be an array reference or an anonymous array in order
	to set multiple variables.

	my $response = $astman->action({Action => 'Originate',
					Channel => 'SIP/peer/12345',
					Context => 'some_context',
					Exten => 100,
					Priority => 1,
					Variable = [ 'var1=1', 'var2=2' ]});

	Example 3 - An Async Originate
	If youre Async Originate never returns please read about the 'OriginateHack' option for the constructor.

	my $response = $astman->action({Action => 'Originate',
					Channel => 'SIP/peer/12345',
					Context => 'some_context',
					Exten => 100,
					Priority => 1,
					Async => 1});

	And the contents of response will look similiar to the following:

	{
		'Message' => 'Originate successfully queued',
		'EVENTS' => [
			{
				'Exten' => '100',
				'CallerID' => '<unknown>',
				'Event' => 'OriginateResponse',
				'Privilege' => 'call,all',
				'Channel' => 'SIP/peer-009c5510',
				'Context' => 'some_context',
				'Response' => 'Success',
				'Reason' => '4',
				'CallerIDName' => '<unknown>',
				'Uniqueid' => '1276543236.82',
				'ActionID' => '3',
				'CallerIDNum' => '<unknown>'
			}
			],
		'ActionID' => '3',
		'GOOD' => 1,
		'COMPLETED' => 1,
		'Response' => 'Success'
	};

	More Info:
	Check out the voip-info.org page for more information on the Originate action.
	http://www.voip-info.org/wiki/view/Asterisk+Manager+API+Action+Originate
					
=head3 Callbacks

	You may also specify a method to callback when using send_action as well as a timeout.

	An example of this would be:
	$astman->send_action({	Action => 'Ping',
				CALLBACK => \&somemethod,
				TIMEOUT => 7 });

	Equivalent in the new alternative sytanx:
	$astman->send_action({ Action => 'Ping' }, \&somemethod, 7);

In this example once the action 'Ping' finishes we will call somemethod() and pass it the a copy of our AMI object 
and the Response Object for the action. If TIMEOUT is not specified it will use the default set. A value of 0 means 
no timeout. When the timeout is reached somemethod() will be called and passed a reference to the our $astman and
the uncompleted Response Object, therefore somemethod() should check the state of the object. Checking the key {'GOOD'}
is usually a good indication if the response is useable.

Callback Caveats

Callbacks only work if we are processing packets, therefore you must be running an event loop. Alternatively, we run 
mini-event loops for our blocking calls (e.g. action(), get_action()), so in theory if you set callbacks and then
issue a blocking call those callbacks should also get triggered. However this is an unsupported scenario.

Timeouts are done using timers and they are set as soon as you send the object. Therefore if you send an action with a
timeout and then monkey around for a long time before getting back to your event loop (to process input) you can time
out before ever even attempting to receive the response. 

	A very contrived example:
	$astman->send_action({	Action => 'Ping',
				CALLBACK => \&somemethod,
				TIMEOUT => 3 });

	sleep(4);

	#Start loop
	$astman->loop;
	#Oh no we never even tried to get the response yet it will still time out

=head3 ActionIDs

This module handles ActionIDs internally and if you supply one in an action it will simply be ignored and overwritten. 

=head2 Responses and Events

	NOTE: Empty fields sent by Asterisk (e.g. 'Account: ' with no value in an event) are represented by the hash
	value of null string, not undef. This means you need to test for ''
	(e.g. if ($response->{'Account'} ne '')) ) for any values that might be possibly be empty.

=head3 Responses

	Responses are returned as response objects, which are hash references, structured as follows:

	$response->{'Response'}		Response to our packet (Success, Failed, Error, Pong, etc).
		   {'ActionID'}		ActionID of this Response.
		   {'Message'}		Message line of the response.
		   {'EVENTS'}		Array reference containing Event Objects associated with this actionid.
		   {'PARSED'}		Hash reference of lines we could parse into key->value pairs.
		   {'CMD'}		Contains command output from 'Action: Command's. It is an array reference.
		   {'COMPLETED'}	1 if completed, 0 if not (timeout)
		   {'GOOD'}		1 if good, 0 if bad. Good means no errors and COMPLETED.

=head3 Events

	Events are turned into event objects, these are similar to response objects, but their keys vary much more
	depending on the specific event.

	Some common contents are:

	$event->{'Event'}		The type of Event
		{'ActionID'}		Only available if this event was caused by an action

=head3 Event Handlers

	Here is a very simple example of how to use event handlers. Please note that the key for the event handler
	is matched against the event type that asterisk sends. For example if asterisk sends 'Event: Hangup' you use a
	key of 'Hangup' to match it. This works for any event type that asterisk sends.

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

=head2 How to use in an event-based application

	Getting this module to work with your event based application is really easy so long as you are running an
	event-loop that is supported by AnyEvent. Below is a simple example of how to use this module with your
	preferred event loop. We will use EV as our event loop in this example. I use subroutine references in this
	example, but you could use anonymous subroutines if you want to.

	#Use your preferred loop before our module so that AnyEvent will auto-detect it
	use EV;
	use Asterisk::AMI:

	#Create your connection
	my $astman = Asterisk::AMI->new(PeerAddr	=>	'127.0.0.1',
                        		PeerPort	=>	'5038',
					Username	=>	'admin',
					Secret		=>	'supersecret',
					Events		=>	'on',
					Handlers	=>	{ default => \&eventhandler }
				);
	#Alternatively you can set Blocking => 0, and set an on_error sub to catch connection errors
	die "Unable to connect to asterisk" unless ($astman);

	#Define the subroutines for events
	sub eventhandler { my ($ami, $event) = @_; print 'Got Event: ',$event->{'Event'},"\r\n"; }

	#Define a subroutine for your action callback
	sub actioncb { my ($ami, $response) = @_; print 'Got Action Reponse: ',$response->{'Response'},"\r\n"; }

	#Send an action
	my $action = $astman->({ Action => 'Ping',
				 CALLBACK => \&actioncb });

	#Do all of you other eventy stuff here, or before all this stuff, whichever
	#..............

	#Start our loop
	EV::loop



	That's it, the EV loop will allow us to process input from asterisk. Once the action completes it will 
	call the callback, and any events will be dispatched to eventhandler(). As you can see it is fairly
	straight-forward. Most of the work will be in creating subroutines to be called for various events and 
	actions that you plan to use.

=head2 Methods

send_action ( ACTION, [ [ CALLBACK ], [ TIMEOUT ] ] )

	Sends the action to asterisk, where ACTION is a hash reference. If no errors occurred while sending it returns
	the ActionID for the action, which is a positive integer above 0. If it encounters an error it will return undef.
	You may specify a callback function and timeout either in the ACTION hash or in the method call. CALLBACK is
	optional and should be a subroutine reference or any anonymous subroutine. TIMEOUT is optional and only has an
	affect if a CALLBACK is specified. CALLBACKs and TIMEOUTs specified during a method call override any found in
	the ACTION hash.
	
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

disconnect ()

	Logoff and disconnects from the AMI. Returns 1 on success and 0 if any errors were encountered.

get_event ( [ TIMEOUT ] )

	This returns the first event object in the buffer, or if no events are in the buffer it reads in packets
	waiting for an event. It will return undef if an error occurs.
	If no TIMEOUT is given it blocks, reading in packets until an event arrives.

amiver ()

	Returns the version of the Asterisk Manager Interface we are connected to. Undef until the connection is made
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

loop ()

	Starts an eventloop via AnyEvent.

=head1 See Also

Asterisk::AMI::Common, Asterisk::AMI::Common::Dev

=head1 AUTHOR

Ryan Bullock (rrb3942@gmail.com)

=head1 BUG REPORTING AND FEEBACK

Please report any bugs or errors to our github issue tracker at http://github.com/rrb3942/perl-Asterisk-AMI/issues
or the cpan request tracker at https://rt.cpan.org/Public/Bug/Report.html?Queue=perl-Asterisk-AMI

=head1 LICENSE

Copyright (C) 2010 by Ryan Bullock (rrb3942@gmail.com)

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

package Asterisk::AMI;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Digest::MD5;
use Scalar::Util qw/weaken/;

#Duh
use version; our $VERSION = qv(0.2.1);

#Used for storing events while reading command responses
#Events are stored as hashes in the array
#Example
#$_[0]{EVETNBUFFER}->{'Event'} = Something

#Buffer for holding action responses and data
# Structure:
# $_[0]{RESPONSEBUFFER}{'ActionID'}->{'Response'}	= (Success|Failure|Follows|Goodbye|Pong|Etc..)	//Reponse Status
#			     {'Message'}	= Message 				//Message in the response
#			     {'EVENTS'}		= [%hash1, %hash2, ..]		//Arry of Hashes of parsed events and data for this actionID
#			     {'PARSED'}		= { Hashkey => value, ...}
#			     {'COMPLETED'}	= 0 or 1				//If the command is completed
#			     {'GOOD'}		= 0 or 1 //if this responses is good, no error, can only be 1 if also COMPLETED

#Create a new object and return it;
#If required options are missing, returns undef
sub new {
	my ($class, %values) = @_;

	my $self = bless {}, $class;

	#Configure our new object and connect, else return undef
	if ($self->_configure(%values) && $self->_connect()) {
		return $self;
	}

	return;
}

#Used by anyevent to load our read type
sub anyevent_read_type {

	my ($hdl, $cb) = @_;

	return sub {
		if ($_[0]{rbuf} =~ s/^(.+)(?:\015\012\015\012)//so) {
			$cb->($_[0], $1);
		}

		return 0;
	}
}

#Sets variables for this object
#Also checks for minimum settings
#Returns 1 if everything was set, 0 if options were missing
sub _configure {
	my ($self, %settings) = @_;

	#Required settings
	my @required = ( 'Username', 'Secret' );

	#Check for required options
	foreach my $req (@required) {
		if (!exists $settings{$req}) {
			return 0;
		}
	}

	#Defaults
	$_[0]{PEER} = '127.0.0.1';
	$_[0]{PORT} = '5038';
	$_[0]{AUTHTYPE} = 'plaintext';
	$_[0]{EVENTS} = 'off';
	$_[0]{BUFFERSIZE} = 30000;
	$_[0]{BLOCK} = 1;

	#Trigger stuff to make Originate with Async work, Fucking Lame.
	$_[0]{OriginateHack} = $settings{'OriginateHack'} if (defined $settings{'OriginateHack'});

	#Ugly any better way?
	#Set values
	$_[0]{USESSL} = $settings{'UseSSL'} if (defined $settings{'UseSSL'});
	$_[0]{PORT} = 5039 if ($_[0]{USESSL}); #Change default port if using ssl
	$_[0]{PEER} = $settings{'PeerAddr'} if (defined $settings{'PeerAddr'});
	$_[0]{PORT} = $settings{'PeerPort'} if (defined $settings{'PeerPort'});
	$_[0]{USERNAME} = $settings{'Username'} if (defined $settings{'Username'});
	$_[0]{SECRET} = $settings{'Secret'} if (defined $settings{'Secret'});
	$_[0]{EVENTS} = $settings{'Events'} if (defined $settings{'Events'});
	$_[0]{TIMEOUT} = $settings{'Timeout'} if (defined $settings{'Timeout'});
	$_[0]{KEEPALIVE} = $settings{'Keepalive'} if (defined $settings{'Keepalive'});
	$_[0]{TCPALIVE} = $settings{'TCP_Keepalive'} if (defined $settings{'TCP_Keepalive'});
	$_[0]{BUFFERSIZE} = $settings{'BufferSize'} if (defined $settings{'BufferSize'});
	$_[0]{EVENTHANDLERS} = $settings{'Handlers'} if (defined $settings{'Handlers'});
	$_[0]{BLOCK} = $settings{'Blocking'} if (defined $settings{'Blocking'});
	$_[0]{AUTHTYPE} = $settings{'AuthType'} if (defined $settings{'AuthType'});


	#Make adjustments for Originate Async bullscrap
	if ($_[0]{OriginateHack}) {
		#Turn on call events, otherwise we wont get the Async response
		if (lc($_[0]{EVENTS}) eq 'off') {
			$_[0]{EVENTS} = 'call';
			#Fake event type so that we will discard events, else by turning on events our event buffer
			#Will just continue to fill up.
			$_[0]{EVENTHANDLERS} = { 'JUSTMAKETHEHASHNOTEMPTY' => sub {} } unless ($_[0]{EVENTHANDLERS});
		#They already turned events on, just add call types to it, assume they are doing something with events
		#and don't mess with the handlers
		} elsif (lc($_[0]{EVENTS}) !~ /on|call/) {
			$_[0]{EVENTS} .= ',call';
		}
	}

	#On Connect
	$_[0]{ON}->{'connect'} = $settings{'on_connect'} if (defined $settings{'on_connect'});

	#Error Handling
	$_[0]{ON}->{'err_connect'} = $settings{'on_connect_err'} if (defined $settings{'on_connect_err'});
	$_[0]{ON}->{'err'} = $settings{'on_error'} if (defined $settings{'on_error'});
	$_[0]{ON}->{'disconnect'} = $settings{'on_disconnect'} if (defined $settings{'on_disconnect'});
	$_[0]{ON}->{'timeout'} = $settings{'on_timeout'} if (defined $settings{'on_timeout'});


	#Initialize the seq number
	$_[0]{idseq} = 1;

	#Weaken reference for use in anonsub
	weaken($self);
	#Set keepalive
	$_[0]{keepalive} = AE::timer($_[0]{KEEPALIVE}, $_[0]{KEEPALIVE}, sub { $self->_send_keepalive }) if ($_[0]{KEEPALIVE});
	
	return 1;
}

#Handles connection failures (includes login failure);
sub _on_connect_err {

	my ($self, $message) = @_;

	warn "Failed to connect to asterisk - $_[0]{PEER}:$_[0]{PORT}";
	warn "Error Message: $message";

	#Dispatch all callbacks as if they timed out
	$self->_clear_cbs();

	if (exists $_[0]{ON}->{'err_connect'}) {
		$_[0]{ON}->{'err_connect'}->($self, $message);
	} elsif (exists $_[0]{ON}->{'err'}) {
		$_[0]{ON}->{'err'}->($self, $message);
	}

	$self->destroy();

	$_[0]{SOCKERR} = 1;
}

#Handles other errors on the socket
#Fatal is an indication as to if the handle was already destroyed
#If it was we don't try to do it ourselves
sub _on_error {

	my ($self, $fatal, $message) = @_;

	warn "Received Error on socket - $_[0]{PEER}:$_[0]{PORT}";
	warn "Error Message: $message";
	
	#Call all cbs as if they had timed out
	$self->_clear_cbs();

	$_[0]{ON}->{'err'}->($self, $message) if (exists $_[0]{ON}->{'err'});
	
	$self->destroy();

	$_[0]{SOCKERR} = 1;
}

#Handles the remote end disconnecting
sub _on_disconnect {

	my ($self) = @_;

	my $message = "Remote end disconnected - $_[0]{PEER}:$_[0]{PORT}";
	warn "Remote Asterisk Server ended connection - $_[0]{PEER}:$_[0]{PORT}";

	#Call all callbacks as if they had timed out
	_
	$self->_clear_cbs();

	if (exists $_[0]{ON}->{'disconnect'}) {
		$_[0]{ON}->{'disconnect'}->($self, $message);
	} elsif (exists $_[0]{ON}->{'err'}) {
		$_[0]{ON}->{'err'}->($self, $message);
	}

	$self->destroy();

	$_[0]{SOCKERR} = 1;
}

#What happens if our keep alive times out
sub _on_timeout {
	my ($self, $message) = @_;

	warn $message;

	if (exists $_[0]{ON}->{'timeout'}) {
		$_[0]{ON}->{'timeout'}->($self, $message);
	} elsif (exists $_[0]{ON}->{'err'}) {
		$_[0]{ON}->{'err'}->($self, $message);
	}

	$_[0]{SOCKERR} = 1;
}

#Things to do after our initial connect
sub _on_connect {

	my ($self, $fh, $line) = @_;

	if ($line =~ /^Asterisk Call Manager\/([0-9]\.[0-9])$/o) {
		$_[0]{AMIVER} = $1;
	} else {
		warn "Unknown Protocol/AMI Version from $_[0]{PEER}:$_[0]{PORT}";
	}

	#Weak reference for us in anonysub	
	weaken($self);

	$_[0]{handle}->push_read( 'Asterisk::AMI' => sub { $self->_handle_packet(@_); }  );
}

#Connects to the AMI
#Returns 1 on success, 0 on failure
sub _connect {
	my ($self) = @_;

	#Weaken ref for use in anonysub
	weaken($self);

	my $process = AE::cv;

	#Build a hash of our anyevent::handle options
	my %hdl = (	connect => [$_[0]{PEER} => $_[0]{PORT}],
			on_connect_err => sub { $self->_on_connect_err($_[1]); },
			on_error => sub { $self->_on_error($_[1],$_[2]) },
			on_eof => sub { $self->_on_disconnect; },
			on_connect => sub { $self->{handle}->push_read( line => sub { $self->_on_connect(@_); } ); });

	#TLS stuff
	$hdl{'tls'} = 'connect' if ($_[0]{USESSL});
	#TCP Keepalive
	$hdl{'keeplive'} = 1 if ($_[0]{TCPALIVE});

	#Make connection/create handle
	$_[0]{handle} = new AnyEvent::Handle(%hdl);

	#Return login status if blocking
	return $_[0]->_login if ($_[0]{BLOCK}); 

	#Queue our login
	$_[0]->_login;

	#If we have a handle, SUCCESS!
	return 1 if ($_[0]{handle});

        return;
}

sub _handle_packet {
	foreach my $packet (split /\015\012\015\012/o, $_[2]) {
		my %parsed;

		foreach my $line (split /\015\012/o, $packet) {
			#Is this our command output?
			if ($line =~ s/--END COMMAND--$//o) {
				$parsed{'COMPLETED'} = 1;

				push(@{$parsed{'CMD'}},split(/\x20*\x0A/o, $line));
			} else {
			#Regular output, split on :\ 
				my ($key, $value) = split /: /, $line, 2;

				$parsed{$key} = $value;

			}
		}

		$_[0]->_sort_and_buffer(\%parsed);
	}

	return 1;
}

#Sorts a packet and places into the appropriate buffer
#Returns 1 on buffered, 0 on discard
sub _sort_and_buffer {
	#my ($self, $packet) = @_;
	my $packet = $_[1];

	if (exists $packet->{'ActionID'}) {
		#Snag our actionid
		my $actionid = $packet->{'ActionID'};

		return unless ($_[0]{EXPECTED}->{$actionid});

		if (exists $packet->{'Event'}) {
			#EventCompleted Event?
			if ($packet->{'Event'} =~ /[cC]omplete/o) {
				$_[0]{RESPONSEBUFFER}->{$actionid}->{'COMPLETED'} = 1;
			} else {
				#DBGetResponse and Originate Async Exceptions
				if ($packet->{'Event'} eq 'DBGetResponse' || $packet->{'Event'} eq 'OriginateResponse') {
					$_[0]{RESPONSEBUFFER}->{$actionid}->{'COMPLETED'} = 1;
				}
				
				push(@{$_[0]{RESPONSEBUFFER}->{$actionid}->{'EVENTS'}}, $packet);
			}

		} elsif (exists $packet->{'Response'}) {
			#If No indication of future packets, mark as completed
			if ($packet->{'Response'} ne 'Follows') {
				#Originate Async Exception is the first test
				if (!$_[0]{RESPONSEBUFFER}->{$actionid}->{'ASYNC'} && (!exists $packet->{'Message'} || $packet->{'Message'} !~ /[fF]ollow/o)) {
					$packet->{'COMPLETED'} = 1;
				}
			} 

			#Copy the response into the buffer
			foreach (keys %{$packet}) {	
				if ($_ =~ /^(?:Response|Message|ActionID|Privilege|CMD|COMPLETED)$/o) {
					$_[0]{RESPONSEBUFFER}->{$actionid}->{$_} =  $packet->{$_};
				} else {
					$_[0]{RESPONSEBUFFER}->{$actionid}->{'PARSED'}->{$_} = $packet->{$_};
				}
			 }
		}
	
		#This block handles callbacks
		if ($_[0]{RESPONSEBUFFER}->{$actionid}->{'COMPLETED'}) {
			#This aciton is finished do not accept any more packets for it
			delete $_[0]{EXPECTED}->{$actionid};

			#Determine 'Goodness'
			if (defined $_[0]{RESPONSEBUFFER}->{$actionid}->{'Response'} && $_[0]{RESPONSEBUFFER}->{$actionid}->{'Response'} =~ /^(?:Success|Follows|Goodbye|Events Off|Pong)$/o) {
				$_[0]{RESPONSEBUFFER}->{$actionid}->{'GOOD'} = 1;
			}

			#Do callback and cleanup if callback exists
			if (defined $_[0]{CALLBACKS}->{$actionid}->{'cb'}) {
				#Stuff needed to process callback
				my $callback = $_[0]{CALLBACKS}->{$actionid}->{'cb'};
				my $response = $_[0]{RESPONSEBUFFER}->{$actionid};

				#cleanup
				delete $_[0]{RESPONSEBUFFER}->{$actionid};
				delete $_[0]{CALLBACKS}->{$actionid};

				#Delete Originate Async bullshit
				delete $response->{'ASYNC'};

				$callback->($_[0], $response);
			}
		}

	#Is it an event?
	} elsif (exists $packet->{'Event'}) {

		#If handlers were configured just dispatch, don't buffer
		if ($_[0]{EVENTHANDLERS}) {
			if (exists $_[0]{EVENTHANDLERS}->{$packet->{'Event'}}) {
				$_[0]{EVENTHANDLERS}->{$packet->{'Event'}}->($_[0], $packet);
			} elsif (exists $_[0]{EVENTHANDLERS}->{'default'}) {
				$_[0]{EVENTHANDLERS}->{'default'}->($_[0], $packet);
			}
		} else {
			#Someone is waiting on this packet, don't bother buffering
			if (exists $_[0]{CALLBACKS}->{'EVENT'}) {
				$_[0]{CALLBACKS}->{'EVENT'}->{'cb'}->($packet);
				delete $_[0]{CALLBACKS}->{'EVENT'};
			#Save for later
			} else {
				push(@{$_[0]{EVENTBUFFER}}, $packet);
			}
		}

	#Not a response, not an Event, bad packet
	} else {
		return 0;
	}

	return 1;
}

#This is used to provide blocking behavior for calls
#It installs callbacks for an action if it is not in the buffer and waits for the response before
#returning it.
sub _wait_response {
	my ($self, $id, $timeout) =  @_;

	#Already got it?
	if ($_[0]{RESPONSEBUFFER}->{$id}->{'COMPLETED'}) {
		my $resp = $_[0]{RESPONSEBUFFER}->{$id};
		delete $_[0]{RESPONSEBUFFER}->{$id};
		delete $_[0]{CALLBACKS}->{$id};
		delete $_[0]{EXPECTED}->{$id};
		return $resp;
	}

	#Don't Have it, wait for it
	#Install some handlers and use a CV to simulate blocking
	my $process = AE::cv;

	$_[0]{CALLBACKS}->{$id}->{'cb'} = sub { $process->send($_[1]) };
	$timeout = $_[0]{TIMEOUT} unless (defined $timeout);

	#Should not need to weaken here because this is a blocking call
	#Only outcomes can be error, timeout, or complete, all of which will finish the cb and clear the reference
	#weaken($self)

	if ($timeout) {
		$_[0]{CALLBACKS}->{$id}->{'timeout'} = sub {
				my $response = $self->{'RESPONSEBUFFER'}->{$id};
				delete $self->{RESPONSEBUFFER}->{$id};
				delete $self->{CALLBACKS}->{$id};
				delete $self->{EXPECTED}->{$id};
				$process->send($response);
			};

		$_[0]{CALLBACKS}->{$id}->{'timer'} = AE::timer $timeout, 0, $_[0]{CALLBACKS}->{$id}->{'timeout'};
	}

	return $process->recv;
}

#Sends an action to the AMI
#Accepts an Array
#Returns the actionid of the action
sub send_action {
	my ($self, $actionhash, $callback, $timeout) = @_;

	#No connection
	return unless ($_[0]{handle});

	#resets id number 
	if ($_[0]{idseq} > $_[0]{BUFFERSIZE}) {
		$_[0]{idseq} = 1;
	}

	my $id = $_[0]{idseq}++;

	#Store the Action ID
	$_[0]{lastid} = $id;

	#Delete anything that might be in the buffer
	delete $_[0]{RESPONSEBUFFER}->{$id};
	delete $_[0]{CALLBACKS}->{$id};

	#Set default timeout
	#$actionhash->{'TIMEOUT'} = $_[0]{TIMEOUT} unless (defined $actionhash->{'TIMEOUT'});

	#Get a copy of our timeout
	#Deprecated
	if (!defined $timeout && defined $actionhash->{'TIMEOUT'}) {
		$timeout = $actionhash->{'TIMEOUT'};
	}

	$timeout = $_[0]{TIMEOUT} unless (defined $timeout);

	#Deprecated
	if (!defined $callback && defined $actionhash->{'CALLBACK'}) {
		$callback = $actionhash->{'CALLBACK'};
	}

	#Assign Callback
	$_[0]{CALLBACKS}->{$id}->{'cb'} = $callback if (defined $callback);

	delete $actionhash->{'TIMEOUT'};
	delete $actionhash->{'CALLBACK'};

	my $action;

	#Create an action out of a hash
	while (my ($key, $value) = each(%{$actionhash})) {

		my $lkey = lc($key);
		#Clean out user ActionIDs
		if ($lkey eq 'actionid') {
			next;
		#Exception of Orignate Async
		} elsif ($lkey eq 'async' && $value == 1) {
			$_[0]{RESPONSEBUFFER}->{$id}->{'ASYNC'} = 1;
		}

		if (ref($value) eq 'ARRAY') {
			foreach my $var (@{$value}) {
				$action .= $key . ': ' . $var . "\015\012";
			}
		} else {
			$action .= $key . ': ' . $value . "\015\012";
		}
	}

	#Append ActionID and End Command
	$action .= 'ActionID: ' . $id . "\015\012\015\012";	

	if ($_[0]{LOGGEDIN} || lc($actionhash->{'Action'}) =~ /login|challenge/) {
		$_[0]{handle}->push_write($action);
	} else {
		$_[0]{PRELOGIN}->{$id} = $action;
	}

	$_[0]{RESPONSEBUFFER}->{$id}->{'COMPLETED'} = 0;
	$_[0]{RESPONSEBUFFER}->{$id}->{'GOOD'} = 0;
	$_[0]{EXPECTED}->{$id} = 1;

	#Weaken ref of use in anonsub
	weaken($self);

	#Start timer for timeouts
	if ($timeout && defined $_[0]{CALLBACKS}->{$id}) {
		$_[0]{CALLBACKS}->{$id}->{'timeout'} = sub {
				my $response = $self->{RESPONSEBUFFER}->{$id};
				my $callback = $self->{CALLBACKS}->{$id}->{'cb'};
				delete $self->{RESPONSEBUFFER}->{$id};
				delete $self->{CALLBACKS}->{$id};
				delete $self->{EXPECTED}->{$id};
				delete $self->{PRELOGIN}->{$id};
				$callback->($self, $response);;
			};
		$_[0]{CALLBACKS}->{$id}->{'timer'} = AE::timer $timeout, 0, $_[0]{CALLBACKS}->{$id}->{'timeout'};
	}

	return $id;
}

#Checks for a response to an action
#If no actionid is given uses last actionid sent
#Returns 1 if action success, 0 if failure
sub check_response {
	my ($self, $actionid, $timeout) = @_;

	#Check if an actionid was passed, else us last
	$actionid = $_[0]{lastid} unless (defined $actionid);

	my $resp = $self->_wait_response($actionid, $timeout);

	if ($resp->{'COMPLETED'}) {
		return $resp->{'GOOD'};
	}

	return;
}

#Returns the Action with all command data and event
#Actions are hash references
#If an actionid is specified returns that action, otherwise uses last actionid sent
#Removes the event from the buffer
sub get_response {
	my ($self, $actionid, $timeout) = @_;

	#Check if an actionid was passed, else us last
	$actionid = $_[0]{lastid} unless (defined $actionid);

	#Wait for the action to complete
	my $resp = $self->_wait_response($actionid, $timeout);
	
	if ($resp->{'COMPLETED'}) {
		return $resp;
	}

	return;
}

#Sends an action and returns its data
#or undef if the command failed
sub action {
	my ($self, $action, $timeout) = @_;
	
	#Send action
	my $actionid = $self->send_action($action);
	if (defined $actionid) {
		#Get response
		return $self->get_response($actionid,$timeout);
	}

	return;
}

#Sends an action and returns 1 if it was successful
#and 0 if it failed
sub simple_action {
	my ($self, $action, $timeout) = @_;

	#Send action
	my $actionid = $self->send_action($action);

	if (defined $actionid) {
		my $resp = $self->_wait_response($actionid, $timeout);
		if ($resp->{'COMPLETED'}) {
			return $resp->{'GOOD'};
		}
	}

	return;
}

#Logs into the AMI
sub _login {
	my $self = $_[0];

	#Auth challenge
	my %challenge;
	
	#Build login action
	my %action = (	Action => 'login',
			Username => $_[0]{USERNAME},
			Events => $_[0]{EVENTS} );

	#Actions to take for different authtypes
	if (lc($_[0]{AUTHTYPE}) eq 'md5') {
		#Do a challenge
		%challenge = (	Action => 'Challenge',
				AuthType => $_[0]{AUTHTYPE});
	} else {
		$action{'Secret'} = $_[0]{SECRET};
	}

	#Blocking connect
	if ($_[0]{BLOCK}) {
		my $resp;

		my $timeout;
		$timeout = 5 unless ($_[0]{TIMEOUT});

		#If a challenge exists do handle it first before the login
		if (%challenge) {
			#Get challenge response
			my $chresp = $self->action(\%challenge,$timeout);

			if ($chresp->{'GOOD'}) {
				#Build up our login from the challenge
				my $md5 = new Digest::MD5;

				$md5->add($chresp->{'PARSED'}->{'Challenge'});
				$md5->add($_[0]{SECRET});

				$md5 = $md5->hexdigest;

				$action{'Key'} = $md5;
				$action{'AuthType'} = $_[0]{AUTHTYPE};

				#Login
				$resp = $self->action(\%action,$timeout);
						
			} else {
				#Challenge Failed
				if ($chresp->{'COMPLETED'}) {
					warn "$_[0]{AUTHTYPE} challenge failed";
				} else {
					warn "Timed out waiting for challenge";
				}
			}
		} else {
			#Plaintext login
			$resp = $self->action(\%action,$timeout);
		}

		
		if ($resp->{'GOOD'}){
			#Login successful
			$_[0]{LOGGEDIN} = 1;
			#Run on_connect stuff
			$_[0]{ON}->{'connect'}->($self) if (defined $_[0]{ON}->{'connect'});

			#Flush pre-login buffer			
			foreach (values %{$_[0]{PRELOGIN}}) {
				$_[0]{handle}->push_write($_);
			}

			delete $_[0]{PRELOGIN};

			return 1;
		} else {
			#Login Failed
			$_[0]{LOGGEDIN} = 0;
			if ($resp->{'COMPLETED'}) {
				warn "Authentication Failed";
			} else {
				warn "Timed out waiting for login";
			}
		}
	#Non-blocking connect
	} else {

		#Weaken ref for use in anonsub
		weaken($self);		

		#Callback for login action
		$action{'CALLBACK'} = sub {
					if ($_[1]->{'GOOD'}) {
						#Login was good
						$self->{LOGGEDIN} = 1;
						#Flush pre-login buffer			
						foreach (values %{$self->{PRELOGIN}}) {
							$self->{handle}->push_write($_);
						}

						delete $self->{PRELOGIN};

						$self->{ON}->{'connect'}->($self) if (defined $self->{ON}->{'connect'});
					} else {
						#Login failed
						my $message;

						if ($_[1]->{'COMPLETED'}) {
							$message = "Login Failed to Asterisk at $_[0]{PEER}:$_[0]{PORT}";
						} else {
							$message = "Login Failed to Asterisk due to timeout at $_[0]{PEER}:$_[0]{PORT}"
						}
						
						$self->_on_connect_err(0 ,$message);
					} 
		};

		$action{'TIMEOUT'} = 5 unless ($_[0]{TIMEOUT});

		#Do a md5 challenge
		if (%challenge) {
			#Create callbacks for the challenge
			$challenge{'TIMEOUT'} = 5 unless ($_[0]{TIMEOUT});
			$challenge{'CALLBACK'} = sub {
				if ($_[1]->{'GOOD'}) {
					my $md5 = new Digest::MD5;

					$md5->add($_[1]->{'PARSED'}->{'Challenge'});
					$md5->add($_[0]{SECRET});

					$md5 = $md5->hexdigest;

					$action{'Key'} = $md5;
					$action{'AuthType'} = $_[0]{AUTHTYPE};

					$self->send_action(\%action);
						
				} else {
					if ($_[1]->{'COMPLETED'}) {
						warn "$_[0]{AUTHTYPE} challenge failed";
					} else {
						warn "Timed out waiting for challenge";
					}
				}
			};
			#Send challenge
			$self->send_action(\%challenge);

		} else { 
			#Plaintext login
			$self->send_action(\%action);
		}

		return 1;
	}

	return;
}

#Disconnect from the AMI
#If logged in will first issue a logoff
sub disconnect {
	my ($self) = @_;

	$self->destroy();

	#No socket? No Problem.
	return 1;
}

#Pops the topmost event out of the buffer and returns it
#Events are hash references
sub get_event {
	#my ($self, $timeout) = @_;
	my $timeout = $_[1];

	$timeout = $_[0]{TIMEOUT} unless (defined $timeout);

	unless (defined $_[0]{EVENTBUFFER}->[0]) {

		my $process = AE::cv;

		$_[0]{CALLBACKS}->{'EVENT'}->{'cb'} = sub { $process->send($_[0]) };
		$_[0]{CALLBACKS}->{'EVENT'}->{'timeout'} = sub { warn "Timed out waiting for event"; $process->send(undef); };

		$timeout = $_[0]{TIMEOUT} unless (defined $timeout);

		if ($timeout) {
			$_[0]{CALLBACKS}->{'EVENT'}->{'timer'} = AE::timer $timeout, 0, $_[0]{CALLBACKS}->{'EVENT'}->{'timeout'}; 
		}

		return $process->recv;
	}

	return shift @{$_[0]{EVENTBUFFER}};
}

#Returns server AMI version
sub amiver {
	return $_[0]{AMIVER};
}

#Checks the connection, returns 1 if the connection is good
sub connected {
	my ($self, $timeout) = @_;
	
	if ($self && $self->simple_action({ Action => 'Ping'}, $timeout)) {	
		return 1;
	} 

	return 0;
}

#Check whether there was an error on the socket
sub error {
	return $_[0]{SOCKERR};
}

#Sends a keep alive
sub _send_keepalive {
	my ($self) = @_;
	#Weaken ref for use in anonysub
	weaken($self);
	my %action = (	Action => 'Ping',
			CALLBACK => sub { $self->_on_timeout("Asterisk failed to respond to keepalive - $_[0]{PEER}:$_[0]{PORT}") unless ($_[1]->{'GOOD'}); }
		);

	$action{'TIMEOUT'} = 5 unless ($_[0]{TIMEOUT});
	
	$self->send_action(\%action);
}

#Calls all callbacks as if they had timed out
#Used when an error has occured on the socket
sub _clear_cbs {
	foreach my $id (keys %{$_[0]{CALLBACKS}}) {
		my $response = $_[0]{RESPONSEBUFFER}->{$id};
		my $callback = $_[0]{CALLBACKS}->{$id}->{'cb'};
		delete $_[0]{RESPONSEBUFFER}->{$id};
		delete $_[0]{CALLBACKS}->{$id};
		delete $_[0]{EXPECTED}->{$id};
		$callback->($_[0], $response);
	}
}

#Cleans up 
sub destroy {
	my ($self) = @_;

	$self->DESTROY;

	bless $self, "Asterisk::AMI::destroyed";
}

#Runs the AnyEvent loop
sub loop {
	AnyEvent->loop;
}

#Bye bye
sub DESTROY {
	#Logoff
	if ($_[0]{LOGGEDIN}) {
		$_[0]->send_action({ Action => 'Logoff' });
		undef $_[0]{LOGGEDIN};
	}

	#Destroy our handle first to cause it to flush
	if ($_[0]{handle}) {
		$_[0]{handle}->destroy();
	}

	#Do our own flushing
	$_[0]->_clear_cbs();

	#Cleanup, remove everything
	%{$_[0]} = ();
}

sub Asterisk::AMI::destroyed::AUTOLOAD {
	#Everything Fails!
	return;
}

1;
