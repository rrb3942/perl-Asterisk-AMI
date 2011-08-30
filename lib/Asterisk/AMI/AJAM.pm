package Asterisk::AMI::AJAM;

#Register warnings
use warnings::register;

use strict;
use warnings;

use AnyEvent::HTTP;
use URI::Escape;
use AnyEvent;
use Scalar::Util qw/weaken/;
use Carp qw/carp/;
use MIME::Base64;
use Digest::MD5 qw/md5/;

#Duh
use version; our $VERSION = qv(0.2.9_01);

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

#Generate a nonce
#terribly not secure, but should atleast be unique enough
sub _nonce {
	return md5( rand(1000000) . time . rand(10000000) );
}

#Sets variables for this object Also checks for minimum settings Returns 1 if everything was set, 0 if options were 
#missing
sub _configure {
        my ($self, %config) = @_;

	my @required = ( 'peeraddr', 'peerport', 'uri', 'username', 'secrect', 'ssl' );

        while (my ($key, $value) = each %config) {
                $self->{lc($key)} = $value;
        }

	#Make we have all we need
	foreach (@required) {
		return unless (defined $self->{$_});
	}

	$self->{url} = do { $self->{ssl} ? 'https' : 'http' } .  '://' . $self->{peeraddr} . ':' . $self->{peerport} . $self->{uri};

	#Preload some auth headers incase they are needed
	$self->{auth}->{username} = $self->{username};
	$self->{auth}->{nc} = 0;
	$self->{auth}->{qop} = 'auth';
	$self->{auth}->{algorithm} = 'MD5';
	$self->{auth}->{uri} = $self->{uri};
	$self->{auth}->{Authorization} = 'Digest';

        $self->{cookies} = {};

        return 1;
}

sub _on_error {
        my ($self, $message) = @_;

        $self->{on_error}->($self, 1, $message) if ( exists $self->{on_error} );
        
        $self->destroy();

        $self->{sockerr} = 1;

        return;
}

sub _get_ami_ver {
        my ($self, $headers) = @_;

        return unless (defined $headers->{'server'});

        #Initialize the key to indicate we atleast tried to find the version
        $self->{amiver} = undef;

        if ($headers->{'server'} =~ /Asterisk\/(\d)\.(\d)\..*/ ) {
                if ($1 >= 1)  {
                        if ($2 > 4) {
                                $self->{amiver} = 1.1;
                        } else {
                                $self->{amiver} = 1.0;
                        }
                } else {
                        warnings::warnif('Asterisk::AMI',
                                "Unknown Asterisk Version from $self->{url}");

                }
        } else {
                warnings::warnif('Asterisk::AMI',
                                "Unknown Server Type from $self->{url}");
        }
}

#Handles HTTP Response and passes the data off to the parser
sub _http_read {
        my ($self, $data, $headers) = @_;

        #If amiver does not exist examine headers to determine our version
        $self->_get_ami_ver($headers) unless (exists $self->{amiver});

        #2XX Responses are ok, anything else we don't really know how to handle
        if ($headers->{'Status'} > 199 && $headers->{'Status'} < 300) {
                $self->{on_packets}->($self, $data);
        } else {

                #Place ourselves in an error condition
                $self->{sockerr} = 1;

                #Internal AnyEvent::HTTP Errors
                if ($headers->{'Status'} > 549 && $headers->{'Status'} < 600) {
                        $self->_on_error($headers->{'Reason'});
                } else {
                        $self->_on_error("Received unhandled response of type $headers->{'Status'} when accessing $self->{url}");
                }
        } 
}

#Formats and escapes request for use in a HTTP GET or POST
sub _build_action {
        my ($actionhash) = @_;

        my $action;

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

        #Removes trailing &
        chop $action;

        return $action;
}

sub push_write {
        my ($self, $action) = @_;

	my $id = $action->{'ActionID'};
	my $stringified = _build_action($action);

	#Make sure requests clean up after themselves;
	weaken($self);
	my $read = sub {
		#Short circuit for http auth support
		my $headers = $_[2];

		delete $self->{outstanding}->{$id};

		if ($headers->{Status} == 401) {
		#Attempt http authentication and retry the request
			#Check if we support auth type
			if (lc($headers->{'WWW-authenticate'}) != 'digest' || lc($headers->{'algorithm'}) != 'md5') {
				$self->_on_error("Received 401 response with an unsupported authentication method (no digest or md5 support)");
				return;
			}

			my %resp;
			my @slice = ( 'nonce', 'realm', 'opaque' );
			#Read essential headers from response and use as base for our own
			@{$self->{auth}}{@slice} = @$headers{@slice};

			$self->{auth}->{nc}++;			
			#delete;

		} else {
			$self->_http_read(@_);
		}
	};

        if ($self->{use_get}) {
                #store the request guard so that we can cancel_request
                $self->{outstanding}->{$id} = http_get $self->{url}, $stringified,
                                                                        cookie_jar => $self->{cookies}, $read;
        } else {
                #store the request guard so that we can cancel_request
                $self->{outstanding}->{$id} = http_post $self->{url}, $stringified, 
                                                                        cookie_jar => $self->{cookies}, $read;
        }

        return 1;
}

#Cancels a current http request
sub request_cancel {
        my ($self, $id) = @_;
        delete $self->{outstanding}->{$id};
}

#Returns server AMI version
sub amiver {
        my ($self) = @_;
        return $self->{amiver};
}

#Should only be passed a logoff action
#Clean up any current outstanding requests
#Create a circular reference to keep ourselves around for a few seconds to let the logoff finish
sub linger_destroy {
        my ($self, $logoff) = @_;

        #Nuke current requests
        delete $self->{outstanding};

        #Don't care what we get back, just that we close up
        my $circle = sub { $self->destroy };

        #Store our request guards so if we hit our timeout they will get canceled
        if ($self->{use_get}) {
                $self->{linger_request} = http_get $self->{url}, _build_action($logoff),
                                                                cookie_jar => $self->{cookies}, $circle;
        } else {
                $self->{linger_request} = http_post $self->{url}, _build_action($logoff), 
                                                                cookie_jar => $self->{cookies}, $circle;
        }

        #Set a timer for the max time we will stick around
        #Prevents us from lingering for long when the remote end is none-responsive
        #This creates our circular reference (as do the request guards above)
        $self->{linger_timer} = AE::timer 5, 0, $circle;

        return 1;
}

sub destroy {
        my ($self) = @_;
        $self->DESTROY;
}

sub DESTROY {   
        my ($self) = @_;
        #Cancel all requests
        delete $self->{outstanding};
        #Make sure to get rid of the lingering stuff
        delete $self->{linger_request};
        delete $self->{linger_timer};

        #poof
        %$self = ();
}

1;

__END__

=head1 NAME

Asterisk::AMI::AJAM - Provides AJAM IO layer to Asterisk::AMI

=head1 VERSION

0.2.4_01

=head1 SYNOPSIS

        You should never use this module directly. Instead you should enable AJAM support in Asterisk::AMI.

        use Asterisk::AMI;

        my $astman = Asterisk::AMI->new(        PeerAddr => 'http://127.0.0.1:8080/asterisk/rawman',
                                                Username => 'admin',
                                                Secret  =>  'supersecret',
                                                AJAM => 1
                                );

        die "Unable to connect to asterisk" unless ($astman);

        my $db = $astman->action({ Action => 'Ping'});

=head1 DESCRIPTION

This module creates a wrapper around AnyEvent::HTTP. It maintains a persistant session (through cookies) and provides
methods and functionality somewhat similiar to AnyEvent::Handle.

You should never use this module directly, but instead enable AJAM in Asterisk::AMI through the constructor option.

=head1 What is AJAM?

The Aynchronous Javascript Asterisk Manager (AJAM) provides access to the Asterisk Manager Interface (AMI) via HTTP.

It is primarily intended to provided access to the manager interface for use by HTTP enabled applications
that may not have access to a normal TCP socket (think javascript).

We use it as an alternative transport for accessing the AMI, which can be usefull when direct access to the AMI is not
available.

=head1 Implementation Details and Important Notes

=head2 Asterisk Version Compatability

AJAM was added to Asterisk in Asterisk 1.4. Any version before that does not have any support for it.

By default the HTTP POST method is used for accessing AJAM. This is to prevent things like login information and
action details from getting stored in web logs.

Some testing has shown that Asterisk 1.8 supports POSTs but that older version of Asterisk may not. If you are working
with an older version of Asterisk you can force the use of GETs instead through the Asterisk::AMI constructor option.

=head2 Session Authentication

Session Authentication is done through cookies. To prevent the authentication from expiring a keepalive (every 20 seconds)
is enabled in Asterisk::AMI when using AJAM. This usually good enough if you are running an event loop.

You may run into issues if you are not running an event loop (or disable keepalives) and have long periods of inactivity.
If this occurs you will need to re-connect to Asterisk.

=head2 Error Handling

Error handling for AJAM is currently not very granular. All but login errors get lumped under 'on_error'. Future mapping
of http error codes may remedy this.

=head2 Event Polling

In order to provide continuous event updating we do continuous long-polls with the 'WaitEvent' action. As soon as one poll
ends we begin another.

If no events are enabled we disable the above polling.

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
