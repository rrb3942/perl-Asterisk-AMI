package Asterisk::AMI::Manager;

#Register warnings
use warnings::register;

use strict;
use warnings;

use Digest::MD5;
use Scalar::Util qw/weaken/;
use Carp qw/carp/;

use parent qw(AnyEvent::Handle);

#Duh
use version; our $VERSION = qv(0.2.4_01);

sub new {
        my ($class, %options) = @_;

        weaken($class);

        #On initial connect grab AMI version
        $options{on_connect} = sub { $class->push_read( line => sub { $class->_on_connect(@_); } ); };

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

#Things to do after our initial connect
sub _on_connect {
        my ($self, $hdl, $line) = @_;

        if ($line =~ /^Asterisk\ Call\ Manager\/([0-9]\.[0-9])$/ox) {
                $self->{AMIVER} = $1;
        } else {
                warnings::warnif('Asterisk::AMI', "Unknown Protocol/AMI Version from $self->{CONFIG}->{PEERADDR}:$self->{CONFIG}->{PEERPORT}");
        }

        #Weak reference for us in anonysub
        weaken($self);

        $self->push_read( 'Asterisk::AMI::Manager' => $self->{on_packets} );

        return 1;
}

sub push_write {
        my ($self, $actionhash) = @_;

        my $action;

        #Create an action out of a hash
        while (my ($key, $value) = each(%{$actionhash})) {
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

        $self->SUPER::push_write($action);
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

1;

__END__
