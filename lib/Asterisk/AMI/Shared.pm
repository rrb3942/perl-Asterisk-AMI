#!/usr/bin/perl

=head1 NAME

Asterisk::AMI::Shared - Provides some shared functions used by Asterisk::AMI::Common and Asterisk::AMI::Helper

=head1 VERSION

0.3.0

=head1 SYNOPSIS

        use Asterisk::AMI::Shared;

=head1 DESCRIPTION

This module provides some shared functions used by bot Asterisk::AMI::Common and Asterisk::AMI::Helper

=head2 Methods

=head1 See Also

Asterisk::AMI, Asterisk::AMI::Common

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

package Asterisk::AMI::Shared;

use strict;
use warnings;

use version; our $VERSION = qv(0.3.0);

#Returns a hashref
sub commands {

        my ($action) = @_;

        #Early bail out on bad response
        return unless ($action->{'GOOD'});

        my %commands;

        while (my ($cmd, $desc) = each %{$action->{'PARSED'}}) {
                if ($desc =~ s/\s*\(Priv:\ (.+)\)$//x) {
                        my @privs = split /,/x,$1;
                        $commands{$cmd}->{'Priv'} = \@privs;
                }

                $commands{$cmd}->{'Desc'} = $desc;
        }

        return \%commands;

}

sub db_show {

        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my %database;

        foreach my $dbentry (@{$action->{'CMD'}}) {
                if ($dbentry =~ /^(.+?)\s*:\s*([^.]+)$/ox) {
                        my $family = $1;
                        my $val = $2;
                        
                        my @split = split /\//ox,$family;

                        my $key = pop(@split);

                        $family = join('/', @split);

                        $family = substr($family, 1);

                        $database{$family}->{$key} = $val;
                }
        }

        return \%database;
}

sub parked_calls {

        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my %parkinglots;

        foreach my $lot (@{$action->{'EVENTS'}}) {
                delete $lot->{'ActionID'};
                delete $lot->{'Event'};

                my $lotnum = $lot->{'Exten'};

                delete $lot->{'Exten'};

                $parkinglots{$lotnum} = $lot;
        }

        return \%parkinglots;
}

sub sip_peers {

        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my $peers;

        foreach my $peer (@{$action->{'EVENTS'}}) {
                delete $peer->{'ActionID'};
                delete $peer->{'Event'};

                my $peername = $peer->{'ObjectName'};

                delete $peer->{'ObjectName'};

                $peers->{$peername} = $peer;
        }

        return $peers;
}

sub queues {
        
        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my %queues;

        foreach my $event (@{$action->{'EVENTS'}}) {

                my $qevent = $event->{'Event'};
                my $queue = $event->{'Queue'};

                delete $event->{'Event'};
                delete $event->{'ActionID'};
                delete $event->{'Queue'};
                        
                if ($qevent eq 'QueueParams') {
                        while (my ($key, $value) = each %{$event}) {
                                $queues{$queue}->{$key} = $value;
                        }
                } elsif ($qevent eq 'QueueMember') {

                        my $name = $event->{'Name'};

                        delete $event->{'Name'};

                        $queues{$queue}->{'MEMBERS'}->{$name} = $event;

                } elsif ($qevent eq 'QueueEntry') {

                        my $pos = $event->{'Position'};

                        delete $event->{'Position'};
                        
                        $queues{$queue}->{'ENTRIES'}->{$pos} = $event;
                }

        }

        return \%queues;
}

sub queue_status {
        
        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my %queueobj;

        foreach my $event (@{$action->{'EVENTS'}}) {

                my $qevent = $event->{'Event'};

                delete $event->{'Event'};
                delete $event->{'ActionID'};
                        
                if ($qevent eq 'QueueParams') {
                        while (my ($key, $value) = each %{$event}) {
                                $queueobj{$key} = $value;
                        }
                } elsif ($qevent eq 'QueueMember') {

                        my $name = $event->{'Name'};

                        delete $event->{'Name'};
                        delete $event->{'Queue'};

                        $queueobj{'MEMBERS'}->{$name} = $event;

                } elsif ($qevent eq 'QueueEntry') {

                        my $pos = $event->{'Position'};

                        delete $event->{'Queue'};
                        delete $event->{'Position'};
                        
                        $queueobj{'ENTRIES'}->{$pos} = $event;
                }

        }

        return \%queueobj;
}

sub play_digits {

        my ($actions) = @_;

        foreach my $action (@{$actions}) {
                return unless ($action->{GOOD});
        }

        return 1;
}

sub channels {
        
        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my %channels;

        foreach my $chan (@{$action->{'EVENTS'}}) {
                #Clean out junk
                delete $chan->{'Event'};
                delete $chan->{'Privilege'};
                delete $chan->{'ActionID'};

                my $name = $chan->{'Channel'};
        
                delete $chan->{'Channel'};

                $channels{$name} = $chan;
        }

        return \%channels;
}

sub chan_status {

        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my $status;

        $status = $action->{'EVENTS'}->[0];

        delete $status->{'ActionID'};
        delete $status->{'Event'};
        delete $status->{'Privilege'};

        return $status;
}

sub meetme_list {
        my ($action) = @_;

        my %meetmes;

        return unless ($action->{'GOOD'});

        foreach my $member (@{$action->{'EVENTS'}}) {
                my $conf = $member->{'Conference'};
                my $chan = $member->{'Channel'};
                delete $member->{'Conference'};
                delete $member->{'ActionID'};
                delete $member->{'Channel'};
                delete $member->{'Event'};
                $meetmes{$conf}->{$chan} = $member;
        }
        
        return \%meetmes;
}

sub meetme_list_1_4 {

        my ($action) = @_;

        return unless ($action->{'GOOD'});

        #Get rid of header and footer of cli
        shift @{$action->{'CMD'}};
        pop @{$action->{'CMD'}};

        my @meetmes = map { my @split = split /\s{2,}/x; $split[0] } @{$action->{'CMD'}};

        return \@meetmes;
}

sub meetme_members {
        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my %meetme;

        foreach my $member (@{$action->{'EVENTS'}}) {
                my $chan = $member->{'Channel'};
                delete $member->{'Conference'};
                delete $member->{'ActionID'};
                delete $member->{'Channel'};
                delete $member->{'Event'};
                $meetme{$chan} = $member;
        }
        
        return \%meetme;
}

sub meetme_members_1_4 {

        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my %meetme;

        foreach my $line (@{$action->{'CMD'}}) {
                my @split = split /\!/x, $line;
                                
                my $member;
                #0 - User num
                #1 - CID Name
                #2 - CID Num
                #3 - Chan
                #4 - Admin
                #5 - Monitor?
                #6 - Muted
                #7 - Talking
                #8 - Time
                $member->{'UserNumber'} = $split[0];

                $member->{'CallerIDName'} = $split[1];

                $member->{'CallerIDNum'} = $split[2];

                $member->{'Admin'} = $split[4] ? "Yes" : "No";

                $member->{'Muted'} = $split[6] ? "Yes" : "No";

                $member->{'Talking'} = $split[7] ? "Yes" : "No";

                $meetme{$split[3]} = $member;
        }

        return \%meetme;
}

sub voicemail_list {
        my ($action) = @_;

        return unless ($action->{'GOOD'});

        my %vmusers;

        foreach my $box (@{$action->{'EVENTS'}}) {
                my $context = $box->{'VMContext'};
                my $user = $box->{'VoiceMailbox'};

                delete $box->{'VMContext'};
                delete $box->{'VoiceMailbox'};
                delete $box->{'ActionID'};
                delete $box->{'Event'};
                $vmusers{$context}->{$user} = $box;
        }

        return \%vmusers;
}

sub module_check {
        my ($self, $module, $timeout) = @_;

        my $ver = $self->amiver();

        if (defined $ver && $ver >= 1.1) {
                return $self->simple_action({   Action => 'ModuleCheck',
                                                Module => $module }, $timeout);
        } else {
        }
}

sub module_check_1_4 {

        my ($resp) = @_;

        return unless ($resp->{'GOOD'});

        if ($resp->{'CMD'}->[-1] =~ /(\d+)\ .*/x) {

                return 0 if ($1 == 0);

                return 1;
        }

        return;
}

1;
