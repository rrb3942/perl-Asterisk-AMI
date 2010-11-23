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

#Returns a hash
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

sub db_get {

        my ($self, $family, $key, $timeout) = @_;

        my $action = $self->action({    Action => 'DBGet',
                                        Family => $family,
                                        Key => $key }, $timeout);


        if ($action->{'GOOD'}) {
                return $action->{'EVENTS'}->[0]->{'Val'};
        }

        return;
}

sub db_show {

        my ($self, $timeout) = @_;

        my $action = $self->action({    Action => 'Command',
                                        Command => 'database show'}, $timeout);

        return unless ($action->{'GOOD'});

        my $database;

        foreach my $dbentry (@{$action->{'CMD'}}) {
                if ($dbentry =~ /^(.+?)\s*:\s*([^.]+)$/ox) {
                        my $family = $1;
                        my $val = $2;
                        
                        my @split = split /\//ox,$family;

                        my $key = pop(@split);

                        $family = join('/', @split);

                        $family = substr($family, 1);

                        $database->{$family}->{$key} = $val;
                }
        }

        return $database;
}

sub get_var {

        my ($self, $channel, $variable, $timeout) = @_;

        my $action = $self->action({    Action => 'GetVar',
                                        Channel => $channel,
                                        Variable => $variable }, $timeout);

        if ($action->{'GOOD'}) {
                return $action->{'PARSED'}->{'Value'};
        }

        return;
}

sub exten_state {

        my ($self, $exten, $context, $timeout) = @_;

        my $action = $self->action({    Action  => 'ExtensionState',
                                        Exten   => $exten,
                                        Context => $context }, $timeout);

        if ($action->{'GOOD'}) {
                return $action->{'PARSED'}->{'Status'};
        }

        return;
}

sub parked_calls {

        my ($self, $timeout) = @_;

        my $action = $self->action({ Action => 'ParkedCalls' }, $timeout);

        return unless ($action->{'GOOD'});

        my $parkinglots;

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

sub sip_peer {

        my ($self, $peername, $timeout) = @_;

        my $action = $self->action({    Action => 'SIPshowpeer',
                                        Peer => $peername }, $timeout);

        if ($action->{'GOOD'}) {
                return $action->{'PARSED'};
        }

        return;
}

sub mailboxcount {

        my ($self, $exten, $context, $timeout) = @_;

        my $action = $self->action({    Action => 'MailboxCount',
                                        Mailbox => $exten . '@' . $context }, $timeout);

        if ($action->{'GOOD'}) {
                return $action->{'PARSED'};
        }

        return;
}

sub mailboxstatus {

        my ($self, $exten, $context, $timeout) = @_;

        my $action = $self->action({    Action => 'MailboxStatus',
                                        Mailbox => $exten . '@' . $context }, $timeout);


        if ($action->{'GOOD'}) {
                return $action->{'PARSED'}->{'Waiting'};
        }

        return;
}

sub queues {
        
        my ($self, $timeout) = @_;

        my $action = $self->action({ Action => 'QueueStatus' }, $timeout);

        return unless ($action->{'GOOD'});

        my $queues;

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

        my $action = $self->action({    Action => 'QueueStatus',
                                        Queue => $queue }, $timeout);


        return unless ($action->{'GOOD'});

        my $queueobj;

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
                        $err = 1;
                        next;
                }

                $return = 0 unless ($resp);
        }

        if ($err) { return };

        return $return;
}

sub channels {
        
        my ($self, $timeout) = @_;

        my $action = $self->action({Action => 'Status'},$timeout);

        return unless ($action->{'GOOD'});

        my $channels;

        foreach my $chan (@{$action->{'EVENTS'}}) {
                #Clean out junk
                delete $chan->{'Event'};
                delete $chan->{'Privilege'};
                delete $chan->{'ActionID'};

                my $name = $chan->{'Channel'};
        
                delete $chan->{'Channel'};

                $channels->{$name} = $chan;
        }

        return $channels;
}

sub chan_status {

        my ($self, $channel, $timeout) = @_;

        my $action = $self->action({    Action  => 'Status',
                                        Channel => $channel}, $timeout);

        return unless ($action->{'GOOD'});

        my $status;

        $status = $action->{'EVENTS'}->[0];

        delete $status->{'ActionID'};
        delete $status->{'Event'};
        delete $status->{'Privilege'};

        return $status;
}

sub meetme_list {
        my ($self, $timeout) = @_;

        my $meetmes;

        my $amiver = $self->amiver();

        #1.8+
        if (defined($amiver) && $amiver >= 1.1) {
                my $action = $self->action({Action => 'MeetmeList'}, $timeout);

                return unless ($action->{'GOOD'});

                foreach my $member (@{$action->{'EVENTS'}}) {
                        my $conf = $member->{'Conference'};
                        my $chan = $member->{'Channel'};
                        delete $member->{'Conference'};
                        delete $member->{'ActionID'};
                        delete $member->{'Channel'};
                        delete $member->{'Event'};
                        $meetmes->{$conf}->{$chan} = $member;
                }
        #Compat mode for 1.4
        } else {
                #List of all conferences
                my $list = $self->action({ Action => 'Command', Command => 'meetme' }, $timeout);

                return unless ($list->{'GOOD'});

                my @cmd = @{$list->{'CMD'}};

                #Get rid of header and footer of cli
                shift @cmd;
                pop @cmd;

                #Get members for each list
                foreach my $conf (@cmd) {
                        my @confline = split/\s{2,}/x, $conf;
                        my $meetme = $self->meetme_members($confline[0], $timeout);

                        return unless (defined $meetme);

                        $meetmes->{$confline[0]} = $meetme;
                }
        }
        
        return $meetmes;
}

sub meetme_members {
        my ($self, $conf, $timeout) = @_;

        my $meetme;

        my $amiver = $self->amiver();

        #1.8+
        if (defined($amiver) && $amiver >= 1.1) {
                my $action = $self->action({    Action => 'MeetmeList',
                                                Conference => $conf }, $timeout);

                return unless ($action->{'GOOD'});

                foreach my $member (@{$action->{'EVENTS'}}) {
                        my $chan = $member->{'Channel'};
                        delete $member->{'Conference'};
                        delete $member->{'ActionID'};
                        delete $member->{'Channel'};
                        delete $member->{'Event'};
                        $meetme->{$chan} = $member;
                }
        #1.4 Compat
        } else {

                my $members = $self->action({   Action => 'Command',
                                                Command => 'meetme list ' . $conf . ' concise' });

                return unless ($members->{'GOOD'});

                foreach my $line (@{$members->{'CMD'}}) {
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

                        $meetme->{$split[3]} = $member;
                }
        }
        
        return $meetme;
}

sub voicemail_list {
        my ($self, $timeout) = @_;

        my $action = $self->action({ Action => 'VoicemailUsersList' }, $timeout);

        return unless ($action->{'GOOD'});

        my $vmusers;

        foreach my $box (@{$action->{'EVENTS'}}) {
                my $context = $box->{'VMContext'};
                my $user = $box->{'VoiceMailbox'};

                delete $box->{'VMContext'};
                delete $box->{'VoiceMailbox'};
                delete $box->{'ActionID'};
                delete $box->{'Event'};
                $vmusers->{$context}->{$user} = $box;
        }


        return $vmusers;
}

sub module_check {
        my ($self, $module, $timeout) = @_;

        my $ver = $self->amiver();

        if (defined $ver && $ver >= 1.1) {
                return $self->simple_action({   Action => 'ModuleCheck',
                                                Module => $module }, $timeout);
        } else {
                my $resp = $self->action({      Action => 'Command',
                                                Command => 'module show like ' . $module }, $timeout);

                return unless (defined $resp && $resp->{'GOOD'});

                if ($resp->{'CMD'}->[-1] =~ /(\d+)\ .*/x) {

                        return 0 if ($1 == 0);

                        return 1;
                }

                return;
        }
}

sub originate {
        my ($self, $chan, $context, $exten, $callerid, $ctime, $timeout) = @_;

        my %action = (  Action => 'Originate',
                        Channel => $chan,
                        Context => $context,
                        Exten => $exten,
                        Priority => 1,
                        );

        $action{'CallerID'} = $callerid if (defined $callerid);

        if (defined $ctime) {
                $action{'Timeout'} = $ctime * 1000;

                if ($timeout) {
                        $timeout = $ctime + $timeout;
                }
        }

        return $self->simple_action(\%action, $timeout);
}

sub originate_async {
        my ($self, $chan, $context, $exten, $callerid, $ctime, $timeout) = @_;

        my %action = (  Action => 'Originate',
                        Channel => $chan,
                        Context => $context,
                        Exten => $exten,
                        Priority => 1,
                        Async => 1
                        );

        $action{'CallerID'} = $callerid if (defined $callerid);
        $action{'Timeout'} = $ctime * 1000 if (defined $ctime);

        my $actionid = $self->send_action(\%action);

        #Bypass async wait, bit hacky
        #allows us to get the intial response
        delete $self->{RESPONSEBUFFER}->{$actionid}->{'ASYNC'};

        return $self->check_response($actionid, $timeout);
}

1;
