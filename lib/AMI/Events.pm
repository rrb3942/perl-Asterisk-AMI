#!/usr/bin/perl

=head1 NAME

AMI::Events - Extends the AMI module to provide basic event dispatching.

=head1 VERSION

0.1.1

=head1 SYNOPSIS

	use AMI::Events
	my $astman = AMI::Events->new(	PeerAddr	=>	'127.0.0.1',
					PeerPort	=>	'5038',
					Username	=>	'admin',
					Secret		=>	'supersecret',
					Events		=>	'on'
					);

	die "Unable to connect to asterisk" unless ($astman);

	sub do_event {
		my ($event) = @_;

		print 'Yeah! Event Type: ' . $event->{'Event'} . "\r\n";
	}

	$astman->handlers( { 'default' => \&do_event } );

	$astman->event_loop();
	

=head1 DESCRIPTION

This module extends the standard AMI module to include basic event dispatching and extends event handling.

=head2 Constructor

=head3 new([ARGS])

Creates a new AMI::Events object which takes arguments as key-value pairs. In addition to the options available
from the AMI module this accepts the following additional options:

	EventPreempt		Event processing Preempts reading packets.	0 | 1

	'EventPreempt' causes events to be dispatched even when waiting for action responses. Default is off.
	Care should be taken with this option. If the event handlers being triggered create actions themselves 
	it may be possible to cause very deep recursive behavior.

=head2 Methods

eventmask ( EVENTMASK )

	Can be used to set the eventmask. Accepts any value that can be used by the Eventmask Parameter of the
	Asterisk Event action. Returns 1 if it was set succesfully, 0 otherwise. Setting eventmask to 'on' is
	unreliable, as certain versions of asterisk generate no response to this action.

handlers ( { EVENT => \&handler } )

	Accepts a hash reference setting a callback handler for the specfied event. EVENT should match the what the
	contents of the {'Event'} key of the event object will will. The handler should be a subroutine reference that
	will be passed the event object. The 'default' keyword can be used to set a default event handler.

	Default action is to simply discard the event.

	Example:
	$astman->handlers({ QueueParams => \&queuehandler,
			    default	=> \&defaulthandler
			});

event_loop ()

	Loops, indefinitely, reading in packets and dispatching events to handlers.

=head1 See Also

AMI, AMI::Common

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

package AMI::Events;

use strict;
use warnings;
use version;
use parent qw(AMI);

our $VERSION = qv(0.1.1);

my %settings = ('EventPreempt' => 0);

my $EVENTPREEMPT;

my $HANDLERS;

sub new {
	my ($class, %options) = @_;
	
	my $self;

	foreach my $key (keys %options) {
		$settings{$key} = $options{$key};
	}


	delete $options{'EventPreempt'};

	$class->SUPER::new(%options);

	if (!$class->_configure_events()){
		return $self;
	}

	$self = $class;

	return $self;
}

sub _configure_events {

	my ($self, %options) = @_;

	if ($settings{'EventPreempt'} == 1) {
		$EVENTPREEMPT = 1;
	} elsif ($settings{'EventPreempt'} != 0) {
		warn "Bad value for EventPreempt";
		return 0;			
	}
	
	return 1;
}

sub eventmask {
	my ($self, $mask) = @_;

	if ($mask eq 'on') {
		return $self->send_action( { Action => 'Events',
					     EventMask => 'on' });
	} else {
		return $self->simple_action( { Action => 'Events',
					     EventMask => $mask });
	}

	return 0;
}

sub handlers {
	my ($self, $handlers) = @_;

	$HANDLERS = $handlers;
	
	return 1;
}

#Proccesses a packet
#First reads it in and the places it into a buffer
sub _process_packet {
	my ($self) = @_;

	if ($EVENTPREEMPT) {
		$self->_dispatch_buffered_events();
	}

	my $packet = $self->_read_packet();

	return $self->_sort_and_buffer($packet);
}

#Event handler, accepts an event packet and handles it
sub _dispatch_event {

	my ($self, $event) = @_;

	if (exists $HANDLERS->{$event->{'Event'}}) {
		$HANDLERS->{$event->{'Event'}}->($event);
	} elsif (exists $HANDLERS->{'default'}) {
		$HANDLERS->{'default'}->($event);
	}

	return 1;
}

#Proccess all buffered events 
sub _dispatch_buffered_events {

	my ($self) = @_;

	while (my $event = $self->get_buffered_event()) {
		$self->_dispatch_event($event);
	}

	return 1;
}

#Loops just waiting for for events
sub event_loop {

	my ($self) = @_;

	while (my $event = $self->get_event()) {
		$self->_dispatch_event($event);
	}

	return 1;
}

1;
