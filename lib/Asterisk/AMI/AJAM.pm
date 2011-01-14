package Asterisk::AMI::AJAM;

#Register warnings
use warnings::register;

use strict;
use warnings;

use AnyEvent::HTTP;
use URI::Escape;
use Scalar::Util qw/weaken/;
use Carp qw/carp/;

#Duh
use version; our $VERSION = qv(0.2.4_01);

#Create a new object and return it; If required options are missing, returns undef
sub new {
        my ($class, %values) = @_;

        my $self = bless {}, $class;

        #Configure our new object and connect, else return undef
        if ($self->_configure(%values)) {
                return $self;
        }

        return;
}

#Sets variables for this object Also checks for minimum settings Returns 1 if everything was set, 0 if options were 
#missing
sub _configure {
        my ($self, %config) = @_;

        while (my ($key, $value) = each %config) {
                $self->{uc($key)} = $value;
        }

        weaken $self;

        $self->{HTTP_READ} = sub { $self->_http_read(@_) };

        return 1;
}

#Handles connection failures (includes login failure);
sub _on_connect_err {
        my ($self, $message) = @_;

        if (exists $self->{ON_CONNECT_ERR}) {
                $self->{ON_CONNECT_ERR}->($self, $message);
        } elsif (exists $self->{ON_ERROR}) {
                $self->{ON_ERROR}->($self, $message);
        }

        $self->destroy();

        $self->{SOCKERR} = 1;

        return;
}

#Handles other errors on the socket
sub _on_error {
        my ($self, $message) = @_;

        $self->{ON_ERROR}->($self, $message) if (exists $self->{CONFIG}->{ON_ERROR});
        
        $self->destroy();

        $self->{SOCKERR} = 1;

        return;
}

sub _get_ami_ver {
        my ($self, $headers) = @_;

        #Initialize the key to indicate we atleast tried to find the version
        $self->{AMIVER} = undef;

        if ( $headers->{'server'} =~ /Asterisk\/(\d)\.(\d)\..*/ ) {
                if ($1 >= 1)  {
                        if ($2 > 4) {
                                $self->{AMIVER} = 1.1;
                        } else {
                                $self->{AMIVER} = 1.0;
                        }
                } else {
                        warnings::warnif('Asterisk::AMI',
                                "Unknown Asterisk Version from $self->{'URL'}");

                }
        } else {
                warnings::warnif('Asterisk::AMI',
                                "Unknown Server Type from $self->{'URL'}");
        }
}

sub _http_read {
        my ($self, $data, $headers) = @_;

        #If AMIVER does not exist examine headers to determine our version
        $self->_get_ami_ver($headers) unless (exists $self->{AMIVER});

        if ($headers->{'Status'} > 199 && $headers->{'Status'} < 300) {
                $self->{PUSH_READ}->($data);
        } else {
                #Map http codes to errors?
        } 
}

sub push_write {
        my ($self, $actionhash) = @_;

        my $action;;

        #Create an action out of a hash
        while (my ($key, $value) = each(%{$actionhash})) {
                #Handle multiple values
                if (ref($value) eq 'ARRAY') {
                        foreach my $var (@{$value}) {
                                $action .= uri_escape_utf8($key . '=' . $var) . '&';
                        }
                } else {
                        $action .= uri_escape_utf8($key . '=' . $value) . '&';
                }
        }

        #store the request guard so that we can cancel_request
        $self->{OUTSTANDING}->{$action->{'ActionID'}} = http_post($self->{'URL'}, $action, $self->{HTTP_READ});

        return 1;
}

#Cancels a current http request
sub cancel_request {
        my ($self, $id) = @_;

        delete $self->{OUTSTANDING}->{$id};
}

#Returns server AMI version
sub amiver {
        my ($self) = @_;
        return $self->{AMIVER};
}

sub destroy {
        my ($self) = @_;
        $self->DESTROY;
}

sub DESTROY {   
        my ($self) = @_;
        #Cancel all requests
        delete $self->{OUTSTANDING};
}
#Check whether there was an error on the socket
sub error {
        my ($self) = @_;
        return $self->{SOCKERR};
}

1;

__END__
