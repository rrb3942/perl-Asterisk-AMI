package Asterisk::AMI::Manager;

#Register warnings
use warnings::register;

use strict;
use warnings;

use Scalar::Util qw/weaken/;
use Carp qw/carp/;

use AnyEvent;
use parent qw(AnyEvent::Handle);

#Duh
use version; our $VERSION = qv(0.2.4_01);

sub new {
        my ($class, %options) = @_;

        #On initial connect grab AMI version
        $options{on_connect} = \&_on_connect;

        return $class->SUPER::new(%options);
}

#Used by anyevent to load our read type
sub anyevent_read_type {
        my ($hdl, $cb) = @_;

        return sub {
                if ($hdl->{rbuf} =~ s/^(.+)(?:\015\012\015\012)//sox) {
                        $cb->($hdl, $1);
                }

                return;
        }
}

sub anyevent_write_type {

        my ($hdl, $hashref) = @_;

        my $action;

        #Create an action out of a hash
        while (my ($key, $value) = each(%{$hashref})) {
                #Handle multiple values
                if (ref($value) eq 'ARRAY') {
                        foreach my $var (@{$value}) {
                                $action .= $key . ': ' . $var . "\015\012";
                        }
                } else {
                        $action .= $key . ': ' . $value . "\015\012";
                }
        }

        $action .= "\015\012";

        return $action;        
}

sub push_write {
        my ($self, $action) = @_;

        return $self->SUPER::push_write( 'Asterisk::AMI::Manager' => $action );
}

sub _on_connect {
        my ($self, $host, $port, $retry) = @_;
        weaken($self);

        $self->push_read( line => \&_get_ami_ver );
}

#Things to do after our initial connect
sub _get_ami_ver {
        my ($self, $line) = @_;

        if ($line =~ /^Asterisk\ Call\ Manager\/([0-9]\.[0-9])$/ox) {
                $self->{AMIVER} = $1;
        } else {
                warnings::warnif('Asterisk::AMI', "Unknown Protocol/AMI Version from $self->{peername}:$self->{connect}->[1]");
        }

        #Weak reference for us in anonysub
        weaken($self);

        $self->push_read( 'Asterisk::AMI::Manager' => $self->{on_packets} );

        return 1;
}

#Make sure we stick around before going poof
#Should be passed logoff action
#Should help with broken pipe errors
sub linger_destroy {
        my ($self, $logoff) = @_;

        #Drain read buffer
        $self->_drain_rbuf;

        #Nuke read queue
        delete $self->{_queue};

        #Circular reference linger timer
        $self->{linger_timer} = AE::timer 5, 0, sub { $self->destroy };

        weaken($self);
        #Prevent further error invocations;
        $self->on_error(sub { $self->destroy });

        #watch for last line after logoff
        $self->push_read( line => sub {
                                        #Last line
                                        if ($self->{rbuf} =~ /fish/) {
                                                #Call our destructor
                                                $self->destroy;
                                        }

                                        return 1;
                                 });

        $self->on_error(sub { $self->destroy });

        #Request logoff
        $self->push_write($logoff);
}

sub amiver {
        my ($self) = @_;
        return $self->{AMIVER};
}

#Check whether there was an error on the socket
sub error {
        my ($self) = @_;
        return $self->{SOCKERR};
}

sub DESTROY {
        my ($self) = @_;

        #Remove linger timer
        delete $self->{linger_timer};

        $self->SUPER::DESTROY;

}
1;

__END__

=head1 NAME

Asterisk::AMI::Manager - Provides TCP IO layer to Asterisk::AMI

=head1 VERSION

0.2.4_01

=head1 SYNOPSIS

        You should never use this module directly. Instead you should use Asterisk::AMI.

        use Asterisk::AMI;

        my $astman = Asterisk::AMI->new(        PeerAddr => '127.0.0.1',
                                                PeerPort => '5038',
                                                Username => 'admin',
                                                Secret  =>  'supersecret',
                                                AJAM => 1
                                );

        die "Unable to connect to asterisk" unless ($astman);

        my $db = $astman->action({ Action => 'Ping' });

=head1 DESCRIPTION

This module inherits from AnyEvent::Handle and provides extended functionaly for use with the Asterik Manager
Interface.

You should never use this module directly, but instead use Asterisk::AMI.

=head1 See Also

Asterisk::AMI, Asterisk::AMI::Common, Asterisk::AMI::Async

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
