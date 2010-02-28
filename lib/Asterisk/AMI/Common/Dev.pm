#!/usr/bin/perl

=head1 NAME

Asterisk::AMI::Common::Dev - Extends AMI::Common to include functions for the current development branch of asterisk

=head1 VERSION

0.1.7

=head1 SYNOPSIS

	use Asterisk::AMI::Common:Dev;

	my $astman = Asterisk::AMI::Common::Dev->new(	PeerAddr	=>	'127.0.0.1',
							PeerPort	=>	'5038',
							Username	=>	'admin',
							Secret		=>	'supersecrect'
					);

	die "Unable to connect to asterisk" unless ($astman);

	$astman->bridge($channel1, $channel2);

=head1 DESCRIPTION

This module extends Asterisk::AMI::Common to include additional functions for working with the development branch of Asterisk.
It will also be the launching ground for new functions be they are merged into AMI::Common.

=head2 Constuctor

=head3 new([ARGS])

Creates new a Asterisk::AMI::Common::Dev object which takes the arguments as key-value pairs.

This module inherits all options from the AMI module.

=head2 Methods

meetme_list ( [ TIMEOUT ] )

	Returns a hash reference containing all meetme conferences and their members, or undef if an error occured.
	TIMEOUT is optional.

	Hash reference:
	$hashref->{RoomNum}->{MemberChannels}->{'Muted'}
                                               {'Role'}
                                               {'Event'}
                                               {'Talking'}
                                               {'UserNumber'}
                                               {'CallerIDName'}
                                               {'MarkedUser'}
                                               {'CallerIDNum'}
                                               {'Admin'}
meetme_members ( ROOMNUM [, TIMEOUT ] )

	Returns a hash reference containing all members of a meetme conference, or undef if an error occured.
	TIMEOUT is optional.

	Hash reference:
	$hashref->{MemberChannels}->{'Muted'}
                                    {'Role'}
                                    {'Event'}
                                    {'Talking'}
                                    {'UserNumber'}
                                    {'CallerIDName'}
                                    {'MarkedUser'}
                                    {'CallerIDNum'}
                                    {'Admin'}

voicemail_list ( [ TIMEOUT ] )

	Returns a hash reference of all mailboxs on the system, or unde if an error occured.
	TIMEOUT is optional.

	Hash reference:
	$hashref->{context}->{mailbox}->{'Pager'}
                                        {'SayEnvelope'}
                                        {'AttachMessage'}
                                        {'SayCID'}
                                        {'CanReview'}
                                        {'DeleteMessage'}
                                        {'Email'}
                                        {'MaxMessageLength'}
                                        {'SayDurationMinimum'}
                                        {'CallOperator'}
                                        {'NewMessageCount'}
                                        {'MaxMessageCount'}
                                        {'Fullname'}
                                        {'VolumeGain'}

text ( CHANNEL, MESSAGE [, TIMEOUT ] )

	Sends MESSAGE as a text on CHANNEL. Returns 1 on success, 0 on failure, or undef on error or timeout.
	TIMEOUT is optional.

attended_transfer ( CHANNEL, EXTEN, CONTEXT [, TIMEOUT ] )

	Performs an attended transfer on CHANNEL to EXTEN@CONTEXT. Returns 1 on success, 0 on failure, or undef on
	error or timeout. TIMEOUT is optional

bridge ( CHANNEL1, CHANNEL2 [, TIMEOUT ] )

	Bridges CHANNEL1 and CHANNEL2. Returns 1 on success, 0 on failure, or undef on error or timeout.
	TIMEOUT is optional.

=head1 See Also

Asterisk::AMI, Asterisk::AMI::Common

=head1 AUTHOR

Ryan Bullock (rrb3942@gmail.com)

=head1 BUG REPORTING AND FEEBACK

Please report any bugs or errors to our github issue tracker at http://github.com/rrb3942/perl-Asterisk-AMI/issues
or the cpan request tracker at https://rt.cpan.org/Public/Bug/Report.html?Queue=perl-Asterisk-AMI

=head1 COPYRIGHT

Copyright (C) 2010 by Ryan Bullock (rrb3942@gmail.com)

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

package Asterisk::AMI::Common::Dev;

use strict;
use warnings;
use parent qw(Asterisk::AMI::Common);

use version; our $VERSION = qv(0.1.7);

sub new {
	my ($class, %options) = @_;

	my $self = $class->SUPER::new(%options);

	return $self;
}

sub meetme_list {
	my ($self, $timeout) = @_;

	my $action = $self->action({Action => 'MeetmeList'}, $timeout);

	my $meetmes;

	return $meetmes unless ($action->{'GOOD'});

	foreach my $member (@{$action->{'EVENTS'}}) {
		my $conf = $member->{'Conference'};
		my $chan = $member->{'Channel'};
		delete $member->{'Conference'};
		delete $member->{'ActionID'};
		delete $member->{'TIMESTAMP'};
		delete $member->{'Channel'};
		delete $member->{'Event'};
		$meetmes->{$conf}->{$chan} = $member;
	}
	
	return $meetmes;
}

sub meetme_members {
	my ($self, $conf, $timeout) = @_;

	my $action = $self->action({	Action => 'MeetmeList',
					Conference => $conf}, $timeout) if (defined $conf);

	my $meetme;

	return $meetme unless ($action->{'GOOD'});

	foreach my $member (@{$action->{'EVENTS'}}) {
		my $chan = $member->{'Channel'};
		delete $member->{'Conference'};
		delete $member->{'ActionID'};
		delete $member->{'TIMESTAMP'};
		delete $member->{'Channel'};
		delete $member->{'Event'};
		$meetme->{$chan} = $member;
	}
	
	return $meetme;
}

sub voicemail_list {
	my ($self, $timeout) = @_;

	my $action = $self->action({ Action => 'VoicemailUsersList' }, $timeout);

	my $vmusers;

	return $vmusers unless ($action->{'GOOD'});

	foreach my $box (@{$action->{'EVENTS'}}) {
		my $context = $box->{'VMContext'};
		my $user = $box->{'VoiceMailbox'};

		delete $box->{'VMContext'};
		delete $box->{'VoiceMailbox'};
		delete $box->{'ActionID'};
		delete $box->{'TIMESTAMP'};
		delete $box->{'DATA'};
		delete $box->{'Event'};
		$vmusers->{$context}->{$user} = $box;
	}


	return $vmusers;
}

sub text {
	my ($self, $chan, $message, $timeout) = @_;

	return $self->simple_action({	Action => 'SendText',
					Channel => $chan,
					Message => $message }, $timeout);
}

sub attended_transfer {

	my ($self, $channel, $exten, $context, $timeout) = @_;

	return $self->simple_action({	Action => 'Atxfer',
					Channel => $channel,
					Exten => $exten,
					Context => $context,
					Priority => 1 }, $timeout);
}

sub bridge {
	my ($self, $chan1, $chan2, $timeout) = @_;

	return $self->simple_action({	Action => 'Bridge',
					Channel1 => $chan1,
					Channel2 => $chan2,
					Tone => 'Yes'}, $timeout);
}

return 1;
