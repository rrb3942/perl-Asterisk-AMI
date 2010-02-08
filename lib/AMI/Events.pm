#!/usr/bin/perl

=head1 NAME

AMI::Events - Extends the AMI module to provide basic event dispatching.

=head1 VERSION

0.1.2

=head1 SYNOPSIS

	use AMI::Events
	my $astman = AMI::Events->new(	PeerAddr	=>	'127.0.0.1',
					PeerPort	=>	'5038',
					Username	=>	'admin',
					Secret		=>	'supersecret',
					Events		=>	'on',
					Handlers	=> { default => \&do_event };
					);

	die "Unable to connect to asterisk" unless ($astman);

	sub do_event {
		my ($event) = @_;

		print 'Yeah! Event Type: ' . $event->{'Event'} . "\r\n";
	}

	$astman->event_loop();
	

=head1 DESCRIPTION

This module extends the standard AMI module to include basic event dispatching and extends event handling.

=head2 Constructor

=head3 new([ARGS])

Creates a new AMI::Events object which takes arguments as key-value pairs. In addition to the options available
from the AMI module this accepts the following additional options:

	FastEvents		Event processing immediatly after reading a packet	0 | 1
	Handlers		Hash referencecontaining event handlers

	'FastEvents' causes any buffered events to be processed after we process a packet. Default is 0. This is useful
	if you want events to continued to be processed while waiting for a response to an action.

	'Handlers' accepts a hash reference setting a callback handler for the specfied event. EVENT should match the what the
	contents of the {'Event'} key of the event object will be. The handler should be a subroutine reference that
	will be passed the event object. The 'default' keyword can be used to set a default event handler.

	Default handler is to simply discard the event.

=head2 Methods

event_loop ()

	Loops, indefinitely, reading in packets and dispatching events to handlers.

=head1 See Also

AMI, AMI::Common, AMI::Common::Dev

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

#This begin block is to handle becomeing a child of
#AMI::Common if the user already loaded it
#Thus auto-magicly granting us all of its methods
BEGIN {
	#What Are We?
	our @ISA;
	
	#Always need atleast the AMI module;
	require AMI;

	my $isa;

	if (exists $INC{'AMI/Common/Dev.pm'}){
		$isa = 'AMI::Common::Dev';
	#If they loaded AMI::Common, use that 
	} elsif (exists $INC{'AMI/Common.pm'}) {
		$isa = 'AMI::Common';
	#Otherwise we are always an AMI
	} else {
		$isa = 'AMI';
	}

	#Yes we are
	push(@ISA, $isa);
}

#use parent qw(AMI);
#use parent -norequire, qw(AMI::Common);

our $VERSION = qv(0.1.1);

#Yeah, fast! yeah!
my $FASTEVENTS = 0;

#Hash ref for holding event handlers
my $HANDLERS;

sub new {
	my ($class, %options) = @_;
	
	my $self;

	if ($class->_configure_events(%options)){
		$class = $class->SUPER::new(%options);
	
		if ($class) {
			$self = $class;
		}
	}

	return $self;
}

sub _configure_events {

	my ($self, %options) = @_;

	$HANDLERS = $options{'Handlers'} if (defined $options{'Handlers'});
	$FASTEVENTS = $options{'FastEvents'} if (defined $options{'FastEvents'});
	
	return 1;
}

#Public version of _process_packet with timeout support
sub process_packet {

	my ($self, $timeout) = @_;

	my $return = $self->SUPER::process_packet($timeout);

	$self->dispatch_events() if $FASTEVENTS;

	return $return;
}

#Proccesses a packet
#First reads it in and the places it into a buffer
sub _process_packet {
	my ($self) = @_;

	my $return = $self->SUPER::_process_packet();

	$self->dispatch_events() if $FASTEVENTS;

	return $return;
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
sub dispatch_events {

	my ($self) = @_;

	while (defined (my $event = $self->get_buffered_event())) {
		$self->_dispatch_event($event);
	}

	return 1;
}

#Loops just waiting for for events
sub event_loop {

	my ($self) = @_;

	while (defined(my $event = $self->get_event(0))) {
		$self->_dispatch_event($event);
	}

	warn "Error while reading in event";

	return 0;
}

1;
