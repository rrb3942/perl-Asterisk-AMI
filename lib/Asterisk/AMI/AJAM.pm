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

#Create a new object and return it;
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
                $self->{lc($key)} = $value;
        }

        weaken $self;

        $self->{HTTP_READ} = sub { $self->_http_read(@_) };

        return 1;
}

#Handles connection failures (includes login failure);
sub _on_connect_err {
        my ($self, $message) = @_;

        if (exists $self->{on_connect_err}) {
                $self->{on_connect_err}->($self, $message);
        } elsif (exists $self->{on_error}) {
                $self->{on_error}->($self, $message);
        }

        $self->destroy();

        $self->{SOCKERR} = 1;

        return;
}

#Handles other errors on the socket
sub _on_error {
        my ($self, $message) = @_;

        $self->{on_error}->($self, $message) if (exists $self->{on_error});
        
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

#Handles HTTP Response and passes the data off to the parser
sub _http_read {
        my ($self, $data, $headers) = @_;

        #If AMIVER does not exist examine headers to determine our version
        $self->_get_ami_ver($headers) unless (exists $self->{AMIVER});

        #2XX Responses are ok, anything else we don't really know how to handle
        if ($headers->{'Status'} > 199 && $headers->{'Status'} < 300) {
                $self->{on_packets}->($data);
        } else {
                #Place ourselves in an error condition
                $self->{SOCKERR} = 1;

                #Internal AnyEvent::HTTP Errors
                if ($headers->{'Status'} > 549 && $headers->{'Status'} < 600) {
                        $self->_on_error($headers->{'Reason'});
                } else {
                        $self->_on_error("Received unhandled response of type $headers->{'Status'} when accessing $self->{url}");
                }
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
                                $action .= uri_escape_utf8($key) . '=' . uri_escape_utf8($var) . '&';
                        }
                } else {
                        $action .= uri_escape_utf8($key) . '=' . uri_escape_utf8($value) . '&';
                }
        }

        #store the request guard so that we can cancel_request
        $self->{OUTSTANDING}->{$action->{'ActionID'}} = http_post($self->{url}, $action, $self->{HTTP_READ});

        return 1;
}

#Cancels a current http request
sub request_cancel {
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

1;

__END__
