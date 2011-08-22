package Asterisk::AMI::Async;

use strict;
use warnings;
use parent qw(Asterisk::AMI);
use Asterisk::AMI::Shared;

use version; our $VERSION = qv(0.2.9_01);

sub new {
        my ($class, %options) = @_;

        #Copy with all UC options so we can check for what is set
        my %upper;

        while (my ($key, $val) = each %options) {
                $upper{uc($key)} = $val;
        }

        #Set some new defaults
        $upper{block} = 0 unless (exists $upper{block});
        $upper{autodrop} = 1 unless (exists $upper{autodrop});
        $upper{default_cb} = $class->warn_on_bad() unless (exists $upper{default_cb});

        return $class->SUPER::new(%upper);
}

#Allow for slimmed syntax and utilizing defaults
# $astman->fast_action({Action => Ping}, $userdata);
#maybe name smart_action?
sub fast_action {
        my ($ami, $action, $arg1, $arg2) = @_;

        #Will the user ever want to just pass a coderef (and no callback) as userdata?
        if (ref($arg1) eq 'CODE') {
                return $ami->send_action($action, $arg1, undef, $arg2);
        }

        return $ami->send_action($action, undef, undef, $arg1);
}

#Checks original action for keys like 'Channel', 'Extension', and 'Context' and passes them 
#On through the response object
sub _generic_body_cb {
        my ($callback) = @_;

	return unless ($callback);

        return sub {
                my ($ami, $resp, $userdata) = @_;

		if ($resp->{Success}) {
	                my $generic = $resp->{Body};

			foreach (keys %{$resp->{Request}}) {
				if (/^(?:Exten|Context|Channel)/) {
					$generic->{$_} = $resp->{Request}->{$_};
				}
			}

	                $callback->($ami, $resp, $generic, $userdata);
		} else {			
	                $callback->($ami, $resp, undef, $userdata);
		}
        }
}

#Supplies a callback that runs the response through a formatter before passing to the users callback
sub _format_cb {
        my ($callback, $shared) = @_;

	return unless ($callback);

        return sub {
                        my ($ami, $response, $userdata) = @_;

			if ($response->{Success}) {
	                        $callback->($ami, $response, $shared->($response), $userdata);
			} else {
				$callback->($ami, $response, undef, $userdata);
			}
                }
}

sub attended_transfer {
        my ($self, $channel, $exten, $context, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action  => 'Atxfer',
                                        Channel => $channel,
                                        Exten   => $exten,
                                        Context => $context,
                                        Priority => 1 }, $callback, $timeout, $userdata);
}

sub bridge {
        my ($self, $chan1, $chan2, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action  => 'Bridge',
                                        Channel1 => $chan1,
                                        Channel2 => $chan2,
                                        Tone    => 'Yes' }, $callback, $timeout, $userdata);
}

sub commands {
        my ($self, $callback, $timeout, $userdata) = @_;

        return $self->send_action({ Action => 'ListCommands' }, _format_cb($callback, \&Asterisk::AMI::Shared::format_commands), $timeout, $userdata);
}

sub _db_get_cb {
        my ($callback, $family, $key) = @_;

        return sub {
                my ($ami, $resp, $userdata) = @_;

		if ($resp->{Success}) {

	                my %dbgot = (   Family => $family,
        	                        Key => $key,
               	           		Val => $resp->{Events}->[0]->{Val}
               	         	);

                	$callback->($ami, $resp, \%dbgot, $userdata);
		} else {
                	$callback->($ami, $resp, undef, $userdata);
		}
        };
}

sub db_get {
        my ($self, $family, $key, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'DBGet',
                                        Family => $family,
                                        Key => $key }, _db_get_cb($callback, $family, $key), $timeout, $userdata);
}

sub db_put {
        my ($self, $family, $key, $value, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action  => 'DBPut',
                                        Family  => $family,
                                        Key     => $key,
                                        Val     => $value }, $callback, $timeout, $userdata);
}

sub db_show {
        my ($self, $callback, $timeout, $userdata) = @_;

        return $self->send_action({    Action => 'Command',
                                       Command => 'database show' }, _format_cb($callback, \&Asterisk::AMI::Shared::format_db_show), $timeout, $userdata);
}

sub db_del {
        my ($self, $family, $key, $callback, $timeout, $userdata) = @_;

        my $ver = $self->amiver();

        if (defined($ver) && $ver >= 1.1) {
                return $self->send_action({     Action => 'DBDel',
                                                Family => $family,
                                                Key => $key }, $callback, $timeout, $userdata);
        } else {
                return $self->send_action({     Action => 'Command',
                                                Command => 'database del ' . $family . ' ' . $key }, $callback, $timeout, $userdata);
        }

        return;
}

sub db_deltree {
        my ($self, $family, $key, $callback, $timeout, $userdata) = @_;

        my $ver = $self->amiver();

        if (defined($ver) && $ver >= 1.1) {

                my %action = (  Action => 'DBDelTree',
                                Family => $family );

                $action{Key} = $key if (defined $key);

                return $self->send_action(\%action, $callback, $timeout, $userdata);
        } else {
                
                my $cmd = 'database deltree ' . $family;

                if (defined $key) {
                        $cmd .= ' ' . $key;
                }

                return $self->send_action({     Action => 'Command',
                                                Command => $cmd }, $callback, $timeout, $userdata);
        }

        return;
}

sub _get_var_cb {
        my ($callback, $channel, $variable) = @_;

        return sub {
                my ($ami, $resp, $userdata) = @_;

		if ($resp->{Success}) {
	                my %vargot = (  Channel => $channel,
        	                        Variable => $variable,
                        	        Value => $resp->{Value}
                       		 );

	                $callback->($ami, $resp, \%vargot, $userdata);
		} else {
	                $callback->($ami, $resp, undef, $userdata);
		}
        };
}

sub get_var {
        my ($self, $channel, $variable, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'GetVar',
                                        Channel => $channel,
                                        Variable => $variable }, _get_var_cb($callback, $channel, $variable), $timeout, $userdata);
}

sub set_var {
        my ($self, $channel, $varname, $value, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'Setvar',
                                        Channel => $channel,
                                        Variable => $varname,
                                        Value => $value }, $callback, $timeout, $userdata);
}

sub hangup {
        my ($self, $channel, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'Hangup',
                                        Channel => $channel }, $callback, $timeout, $userdata);
}

sub _exten_state_cb {
        my ($callback, $exten, $context) = @_;

        return sub {
                my ($ami, $resp, $userdata) = @_;

		if ($resp->{Success}) {
	                my %extstate = ( Exten => $exten,
        	                         Context => $context,
               	        	         Status => $resp->{Body}->{Status}
               		 	);

	                $callback->($ami, $resp, \%extstate, $userdata);
		} else {
	                $callback->($ami, $resp, undef, $userdata);			
		}
        };
}

sub exten_state {
        my ($self, $exten, $context, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action  => 'ExtensionState',
                                        Exten   => $exten,
                                        Context => $context }, _exten_stat_cb($callback, $exten, $context), $timeout, $userdata);
}

sub park {
        my ($self, $chan1, $chan2, $parktime, $callback, $timeout, $userdata) = @_;

        my %action = (  Action  => 'Park',
                        Channel => $chan1,
                        Channel2 => $chan2 );

        $action{Timeout} = $parktime if (defined $parktime);

        return $self->send_action(\%action, $callback, $timeout, $userdata);
}

sub parked_calls {
        my ($self, $callback, $timeout, $userdata) = @_;

        return $self->send_action({ Action => 'ParkedCalls' }, _format_cb($callback, \&Asterisk::AMI::Shared::format_parked_calls), $timeout, $userdata);
}

sub sip_peers {
        my ($self, $callback, $timeout, $userdata) = @_;

        return $self->send_action({ Action => 'Sippeers' }, _format_cb($callback, \&Asterisk::AMI::Shared::format_sip_peers), $timeout, $userdata);
}

sub _sip_peer_cb {
        my ($callback, $peername) = @_;

        return sub {
                my ($ami, $resp, $userdata) = @_;

		if ($resp->{Success}) {
	                my $peer = $resp->{Body};

	                $peer->{PeerName} = $peername;

        	        $callback->($ami, $resp, $peer, $userdata);
		} else {
        	        $callback->($ami, $resp, undef, $userdata);
		}
        };
}

sub sip_peer {
        my ($self, $peername, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'SIPshowpeer',
                                        Peer => $peername }, _sip_peer_cb($callback, $peername), $timeout, $userdata);
}

sub sip_notify {
        my ($self, $peer, $event, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'SIPnotify',
                                        Channel => 'SIP/' . $peer,
                                        Variable => 'Event=' . $event }, $callback, $timeout, $userdata);
}

sub mailboxcount {
        my ($self, $exten, $context, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'MailboxCount',
                                        Mailbox => $exten . '@' . $context }, _generic_body_cb($callback, $exten, $context), $timeout, $userdata);
}

sub mailboxstatus {
        my ($self, $exten, $context, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'MailboxStatus',
                                        Mailbox => $exten . '@' . $context }, _generic_body_cb($callback, $exten, $context), $timeout, $userdata);
}

sub chan_timeout {
        my ($self, $channel, $chantimeout, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'AbsoluteTimeout',
                                        Channel => $channel,
                                        Timeout => $chantimeout }, $callback, $timeout, $userdata);
}

sub queues {
        my ($self, $callback, $timeout, $userdata) = @_;

        return $self->send_action({ Action => 'QueueStatus' }, _format_cb($callback, \&Asterisk::AMI::Shared::format_queues), $timeout, $userdata);
}

sub queue_status {
        my ($self, $queue, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'QueueStatus',
                                        Queue => $queue }, _format_cb($callback, \&Asterisk::AMI::Shared::format_queue_status), $timeout, $userdata);
}

sub queue_member_pause {
        my ($self, $queue, $member, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'QueuePause',
                                        Queue => $queue,
                                        Interface => $member,
                                        Paused => 1 }, $callback, $timeout, $userdata);
}

sub queue_member_unpause {
        my ($self, $queue, $member, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'QueuePause',
                                        Queue => $queue,
                                        Interface => $member,
                                        Paused => 0 }, $callback, $timeout, $userdata);
}

sub queue_add {
        my ($self, $queue, $member, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'QueueAdd',
                                        Queue => $queue,
                                        Interface => $member }, $callback, $timeout, $userdata);
}

sub queue_remove {
        my ($self, $queue, $member, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'QueueRemove',
                                        Queue => $queue,
                                        Interface => $member }, $callback, $timeout, $userdata);
}

sub _play_dtmf_cb {
        my ($callback, $channel, $digit) = @_;

        return sub {
                my ($ami, $resp, $userdata) = @_;

		if ($resp->{Success}) {
	                my %queued = (  Channel => $channel,
                                	Digit => $digit,
                	);

                	$callback->($ami, $resp, \%queued, $userdata);
		} else {
                	$callback->($ami, $resp, undef, $userdata);
		}
        };
}

sub play_dtmf {
        my ($self, $channel, $digit, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'PlayDTMF',
                                        Channel => $channel,
                                        Digit => $digit }, _play_dtmf_cb($callback, $channel, $digit), $timeout, $userdata);
}

sub channels {
        my ($self, $callback, $timeout, $userdata) = @_;

        return $self->send_action({ Action => 'Status' }, _format_cb($callback, \&Asterisk::AMI::Shared::format_channels), $timeout, $userdata);
}

sub chan_status {
        my ($self, $channel, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action  => 'Status',
                                        Channel => $channel}, _format_cb($callback, \&Asterisk::AMI::Shared::format_chan_status), $timeout, $userdata);
}

sub transfer {
        my ($self, $channel, $exten, $context, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'Redirect',
                                        Channel => $channel,
                                        Exten => $exten,
                                        Context => $context,
                                        Priority => 1 }, $callback, $timeout, $userdata);

}

sub meetme_list {
        my ($self, $callback, $timeout, $userdata) = @_;

        my $amiver = $self->amiver();

        #1.8+
        if (defined($amiver) && $amiver >= 1.1) {
                return $self->send_action({ Action => 'MeetmeList' }, _format_cb($callback, \&Asterisk::AMI::Shared::format_meetme_list), $timeout, $userdata);
        #Compat mode for 1.4
        } else {
                #We need to collect the output for multiple manager commands to build our output

                #Callback to fetch meetme members from list
                my $cb = sub {
                                my ($self, $actionid, $meetmelist) = @_;

                                #Number of meetmes = number of outstanding actions
                                #Use a count to ensure we wait for them all
                                my $count = scalar @{$meetmelist};

                                #Hash to return to callback
                                my %meetmes;

                                #Bailout on no conferences
                                unless ($count) { 
                                        $callback->($self, \%meetmes, $userdata);
                                }

				my @resps;

                                #Callback to handle each meetme room request
                                my $mmcb = sub {
                                        my ($ami, $meetme, $confnum) = @_;

					push $meetme, @resps;

                                        #Looks like we timed out?
                                        return unless ($count);

                                        unless ($meetme) {
                                                undef $count;
                                                $callback->($ami, \@resps, undef, $userdata);
                                        }

                                        #Looks good, add to list
                                        $meetmes{$confnum} = $meetme;

                                        #One action down
                                        $count--;

                                        #More to go?
                                        unless ($count) {
                                                #Done, do final callback to user
                                                $callback->($ami, \@resps, \%meetmes, $userdata);
                                        }
                                };

                                #Send requests for each room
                                foreach my $conf (@{$meetmelist}) {
                                        $self->meetme_members($conf, $mmcb, $timeout, $conf);
                                }
                        };

                #Get our list of meetmes
                return $self->send_action({ Action => 'Command', Command => 'meetme' },
                                _format_cb($cb, \&Asterisk::AMI::Shared::parse_meetme_list_1_4), $timeout, $userdata);

        }
}

sub meetme_members {
        my ($self, $conf, $callback, $timeout, $userdata) = @_;

        my $amiver = $self->amiver();

        #1.8+
        if (defined($amiver) && $amiver >= 1.1) {
                return $self->send_action({     Action => 'MeetmeList',
                                                Conference => $conf },
                                                _format_cb($callback, \&Asterisk::AMI::Shared::format_meetme_members),
                                                $timeout, $userdata);
        #1.4 Compat
        } else {
                return $self->send_action({     Action => 'Command',
                                                Command => 'meetme list ' . $conf . ' concise' },
                                                _format_cb($callback, \&Asterisk::AMI::Shared::format_meetme_members_1_4),
                                                $timeout, $userdata);
        }
        
        return;
}

sub meetme_mute {
        my ($self, $conf, $user, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'MeetmeMute',
                                        Meetme => $conf,
                                        Usernum => $user }, $callback, $timeout, $userdata);
}

sub meetme_unmute {
        my ($self, $conf, $user, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'MeetmeUnmute',
                                        Meetme => $conf,
                                        Usernum => $user }, $callback, $timeout, $userdata);
}

sub mute_chan {
        my ($self, $chan, $dir, $callback, $timeout, $userdata) = @_;

        $dir = 'all' if (!defined $dir);

        return $self->send_action({     Action => 'MuteAudio',
                                        Channel => $chan,
                                        Direction => $dir,
                                        State => 'on' }, $callback, $timeout, $userdata);
}

sub unmute_chan {
        my ($self, $chan, $dir, $callback, $timeout, $userdata) = @_;

        $dir = 'all' if (!defined $dir);

        return $self->send_action({     Action => 'MuteAudio',
                                        Channel => $chan,
                                        Direction => $dir,
                                        State => 'off' }, $callback, $timeout, $userdata);
}

sub monitor {
        my ($self, $channel, $file, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'Monitor',
                                        Channel => $channel,
                                        File => $file,
                                        Format => 'wav',
                                        Mix => '1' }, $callback, $timeout, $userdata);
}

sub monitor_stop {
        my ($self, $channel, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'StopMonitor',
                                        Channel => $channel }, $callback, $timeout, $userdata);
}

sub monitor_pause {
        my ($self, $channel, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'PauseMonitor',
                                        Channel => $channel }, $callback, $timeout, $userdata);
}

sub monitor_unpause {
        my ($self, $channel, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'UnpauseMonitor',
                                        Channel => $channel }, $callback, $timeout, $userdata);
}

sub monitor_change {
        my ($self, $channel, $file, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'ChangeMonitor',
                                        Channel => $channel,
                                        File => $file }, $callback, $timeout, $userdata);
}

sub mixmonitor_mute {
        my ($self, $channel, $dir, $callback, $timeout, $userdata) = @_;

        $dir = 'both' unless (defined $dir);

        return $self->send_action({     Action => 'MixMonitorMute',
                                        Direction => $dir,
                                        Channel => $channel,
                                        State => 1 }, $callback, $timeout, $userdata);
}

sub mixmonitor_unmute {
        my ($self, $channel, $dir, $callback, $timeout, $userdata) = @_;

        $dir = 'both' unless (defined $dir);

        return $self->send_action({     Action => 'MixMonitorMute',
                                        Direction => $dir,
                                        Channel => $channel,
                                        State => 0 }, $callback, $timeout, $userdata);
}

sub text {
        my ($self, $chan, $message, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'SendText',
                                        Channel => $chan,
                                        Message => $message }, $callback, $timeout, $userdata);
}

sub voicemail_list {
        my ($self, $callback, $timeout, $userdata) = @_;

        return $self->send_action({ Action => 'VoicemailUsersList' },
                                    _format_cb($callback, \&Asterisk::AMI::Shared::format_voicemail_list),
                                    $timeout, $userdata);
}

sub _module_cb {
        my ($callback, $module) = @_;

        return sub {
                my ($ami, $resp, $userdata) = @_;

	        $callback->($ami, $resp, $module, $userdata);
        };
}

sub module_check {
        my ($self, $module, $callback, $timeout, $userdata) = @_;

        my $ver = $self->amiver();

        if (defined $ver && $ver >= 1.1) {
                return $self->send_action({     Action => 'ModuleCheck',
                                                Module => $module }, $callback, $timeout, $userdata);
        } else {
                return $self->send_action({     Action => 'Command',
                                                Command => 'module show like ' . $module },
                                                _format_cb(_module_cb($callback, $module), \&Asterisk::AMI::Shared::check_module_check_1_4),
                                                $timeout, $userdata);
        }

        return;
}

sub module_load {
        my ($self, $module, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'ModuleLoad',
                                        LoadType => 'load',
                                        Module => $module }, _module_cb($callback, $module), $timeout, $userdata);
}

sub module_reload {
        my ($self, $module, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'ModuleLoad',
                                        LoadType => 'reload',
                                        Module => $module }, _module_cb($callback, $module), $timeout, $userdata);
}

sub module_unload {
        my ($self, $module, $callback, $timeout, $userdata) = @_;

        return $self->send_action({     Action => 'ModuleLoad',
                                        LoadType => 'unload',
                                        Module => $module }, _module_cb($callback, $module), $timeout, $userdata);
}

sub _originate_cb {
        my ($callback, $chan, $context, $exten) = @_;

        return sub {
                my ($ami, $resp, $userdata) = @_;

		if ($resp->{Success}) {
	                my $orig = $resp->{Events}->[0];

        	        $orig->{Channel} = $chan unless (defined $orig->{Channel});
	                $orig->{Context} = $context unless (defined $orig->{Context});
	                $orig->{Exten} = $exten unless (defined $orig->{Exten});

	                $callback->($ami, $resp, $orig, $userdata);
		} else {
	                $callback->($ami, $resp, undef, $userdata);
		}
        };
}

sub originate {
        my ($self, $chan, $context, $exten, $callerid, $ctime, $callback, $timeout, $userdata) = @_;

        my %action = (  Action => 'Originate',
                        Channel => $chan,
                        Context => $context,
                        Exten => $exten,
                        Priority => 1,
                        Async => 1
                        );

        $action{CallerID} = $callerid if (defined $callerid);

        if (defined $ctime) {
                $action{Timeout} = $ctime * 1000;

                if ($timeout) {
                        $timeout = $ctime + $timeout;
                }
        }

        return $self->send_action(\%action, _originate_cb($callback, $chan, $context, $exten), $timeout, $userdata);
}

1;

__END__

=head1 NAME

Asterisk::AMI::Async - Extends Asterisk::AMI to provide simple access to common AMI commands and functions Asynchronously

=head1 VERSION

0.2.4_01

=head1 SYNOPSIS

        use Asterisk::AMI::Async;

        my $astman = Asterisk::AMI::Async->new(         PeerAddr => '127.0.0.1',
                                                        PeerPort => '5038',
                                                        Username => 'admin',
                                                        Secret  =>  'supersecret'
                                );

        die "Unable to connect to asterisk" unless ($astman);

        my $db = $astman->db_get();

=head1 DESCRIPTION

This module extends the AMI module to provide easier access to common actions and commands available
through the AMI.

This module is safe to, and designed to be used with an event-loop or in an event based application.

=head2 Constructor

=head3 new([ARGS])

Creates new a Asterisk::AMI::Async object which takes the arguments as key-value pairs.

This module inherits all options from the AMI module.

The following default settings are different from the base Asterisk::AMI settings:

        Blocking - Default is changed to 0 (non-blocking)
        AutoDiscard - Default is changed to 1 (enabled)
        Default_CB - Default is to use the callback provided by the Asterisk::AMI::warn_on_bad method

=head2 Manager Version and Privilege Requirements

Every method below indicates the minimum Manager version and Write (write= in manager.conf) privilige/permission
level required for it to properly execute. This section gives a brief overview of how to read these and what some
of them mean.

=head3 Manager Version

In Asterisk 1.6 the Manager version changed to 1.1 from 1.0 in Asterisk 1.4. We use this as an indication of what commands are supported
on the manager connection. We are a little bit lazy here and just assume a manager version of 1.1+ indicates an Asterisk
version of 1.8+. This means some of these methods that require 1.1+ may fail on some early 1.6.x versions of Asterisk.

Examples -
        Requires Manager version 1.0 (Asterisk 1.4) or higher:

                Manager Version: 1.0+

        Requires Manager version 1.1 (Asterisk 1.8) or higher:

                Manager Version: 1.1+

=head3 Privlege/Permission Level

Asterisk requires specific write privilege levels to run certain commands. Some methods below use cli commands to emulate
support for new manager commands on older versions of Asterisk and thus have different privilege requirements.

Examples - 
        Requires 'call' permissions (write=call in manager.conf) on all versions:

                Privilege: (call)

        Requires 'call' or 'reporting' permissions (write=call in manager.conf) on all versions:

                Privilege: (call, reporting)

        Requires 'call' permissions on Manager version 1.1+ and 'command' permissions on 1.0:

                Privilege: 1.0 (command), 1.1+ (call)

        Requires 'call' or 'reporting' permissions on Manager version 1.1+ and 'command' permissions on 1.0:

                Privilege: 1.0 (command), 1.1+ (call, reporting)

=head2 Methods

fast_action ( ACTION [ [ CALLBACK ], USERDATA ] )

        Sends the action to asterisk, taking advantage of preset default callbacks and timeouts.

        This method is equivalent to calling send_action with undef as the callback and timeout.

        fast_action($someaction) is equivalent to send_action($someaction)
        fast_action($someaction, $mystuff) is equivalent to send_action($someaction, undef, undef, $mystuff)
        fast_action($someaction, $callback, $mystuff) is equivalent to send_action($someaction, $callback, undef, $mystuff)

        Note: If the USERDATA you wish to supply is a code reference you will need to pass undef as the argument for
        the callback.

        ex. fast_action($someaction, undef, $mystuff)

attended_transfer ( CHANNEL, EXTEN, CONTEXT [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (call)

        Performs an attended transfer on CHANNEL to EXTEN@CONTEXT. Returns 1 on success, 0 on failure, or undef on
        error or timeout. TIMEOUT is optional

bridge ( CHANNEL1, CHANNEL2 [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (call)

        Bridges CHANNEL1 and CHANNEL2. Returns 1 on success, 0 on failure, or undef on error or timeout.
        TIMEOUT is optional.

commands ( [ TIMEOUT ] )

        Manager Version: 1.0+
        Privilege Level: (none)

        Returns a hash reference of commands available through the AMI. TIMEOUT is optional

        $hashref->{CommandName}->{Desc}        Contains the command description
                                   {Priv}        Contains list of required privileges.

db_show ( [ TIMEOUT ] )

        Manager Version: 1.0+
        Privilege Level: (command)

        Returns a hash reference containing the contents of the Asterisk database, or undef on error or timeout.
        TIMEOUT is optional.

        Values in the hash reference are stored as below:
        $hashref->{FAMILY}->{KEY}

db_get ( FAMILY, KEY [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (system, reporting)

        Returns the value of the Asterisk database entry specified by the FAMILY and KEY pair, or undef if
        does not exist or an error occurred. TIMEOUT is optional.

db_put ( FAMILY, KEY, VALUE [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (system)

        Inserts VALUE for the Asterisk database entry specified by the FAMILY and KEY pair. Returns 1 on success, 0 if it
        failed or undef on error or timeout. TIMEOUT is optional.

db_del ( FAMILY, KEY [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (system)

        Support for Asterisk 1.4 is provided through CLI commands.        

        Deletes the Asterisk database for FAMILY/KEY. Returns 1 on success, 0 if it failed
        or undef on error or timeout. TIMEOUT is optional.

db_deltree ( FAMILY [, KEY, TIMEOUT ] )

        Manager Version: 1.1+
        Privilege Level: (system)

        Support for Asterisk 1.4 is provided through CLI commands.        

        Deletes the entire Asterisk database tree found under FAMILY/KEY. KEY is optional. Returns 1 on success, 0 if it failed
        or undef on error or timeout. TIMEOUT is optional.

get_var ( CHANNEL, VARIABLE [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call, reporting)

        Returns the value of VARIABLE for CHANNEL, or undef on error or timeout. TIMEOUT is optional.

set_var ( CHANNEL, VARIABLE, VALUE [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Sets VARIABLE to VALUE for CHANNEL. Returns 1 on success, 0 if it failed, or undef on error or timeout.
        TIMEOUT is optional.

hangup ( CHANNEL [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (system, call)

        Hangs up CHANNEL. Returns 1 on success, 0 if it failed, or undef on error or timeout. TIMEOUT is optional.

exten_state ( EXTEN, CONTEXT [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call, reporting)

        Returns the state of the EXTEN in CONTEXT, or undef on error or timeout. TIMEOUT is optional

        States:
        -1 = Extension not found
        0 = Idle
        1 = In Use
        2 = Busy
        4 = Unavailable
        8 = Ringing
        16 = On Hold

park ( CHANNEL, CHANNEL2 [, PARKTIME, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Parks CHANNEL and announces park information to CHANNEL2. CHANNEL2 is also the channel the call will return to if
        it times out. 
        PARKTIME is optional and can be used to control how long a person is parked for. TIMEOUT is optional.

        Returns 1 if the call was parked, or 0 if it failed, or undef on error and timeout.

parked_calls ( [ CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (none)

        Returns a hash reference containing parking lots and their members, or undef if an error/timeout or if no calls
        were parked. TIMEOUT is optional.

        Hash reference structure:

        $hashref->{lotnumber}->{Channel}
                               {Timeout}
                               {CallerID}
                               {CallerIDName}

sip_peers ( [ CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (system, reporting)

        Returns a hash reference containing all SIP peers, or undef on error or timeout. TIMEOUT is optional.

        Hash reference structure:

        $hashref->{peername}->{Channeltype}
                              {ChanObjectType}
                              {IPaddress}
                              {IPport}
                              {Dynamic}
                              {Natsupport}
                              {VideoSupport}
                              {ACL}
                              {Status}
                              {RealtimeDevice}

sip_peer ( PEERNAME [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (system, reporting)

        Returns a hash reference containing the information for PEERNAME, or undef on error or timeout.
        TIMEOUT is optional.

        Hash reference structure:

        $hashref->{SIPLastMsg}
                  {SIP-UserPhone}
                  {Dynamic}
                  {TransferMode}
                  {SIP-NatSupport}
                  {Call-limit}
                  {CID-CallingPres}
                  {LastMsgsSent}
                  {Status}
                  {Address-IP}
                  {RegExpire}
                  {ToHost}
                  {Codecs},
                  {Default-addr-port}
                  {SIP-DTMFmode}
                  {Channeltype}
                  {ChanObjectType}
                  {AMAflags}
                  {SIP-AuthInsecure}
                  {SIP-VideoSupport}
                  {Callerid}
                  {Address-Port}
                  {Context}
                  {ObjectName}
                  {ACL}
                  {Default-addr-IP}
                  {SIP-PromiscRedir}
                  {MaxCallBR}
                  {MD5SecretExist}
                  {SIP-CanReinvite}
                  {CodecOrder}
                  {SecretExist}

sip_notify ( PEER, EVENT [, CALLBACK, TIMEOUT, USERDATA ])

        Manager Version: 1.1+
        Privilege Level: (system)

        Sends a SIP NOTIFY to PEER with EVENT. Returns 1 on success 0 on failure or undef on error or timeout.

        Example - Sending a 'check-sync' event to to a SIP PEER named 'Polycom1':

        $astman->sip_notify('Polycom1', 'check-sync');

mailboxcount ( EXTENSION, CONTEXT [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call, reporting)

        Returns an hash reference containing the message counts for the mailbox EXTENSION@CONTEXT, or undef on error or
        timeout. TIMEOUT is optional.

        Hash reference structure:

        $hashref->{Mailbox}
                  {NewMessages}
                  {OldMessages}

mailboxstatus ( EXTENSION, CONTEXT [, CALLBACK, TIMEOUT, USERDATA ] )
        
        Manager Version: 1.0+
        Privilege Level: (call, reporting)

        Returns the status of the mailbox or undef on error or timeout. TIMEOUT is optional

chan_timeout ( CHANNEL, CHANNELTIMEOUT [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call, system)

        Sets CHANNEL to timeout in CHANNELTIMEOUT seconds. Returns 1 on success, 0 on failure, or undef on error or timeout.
        TIMEOUT is optional.

queues ( [ CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (none)

        Returns a hash reference containing all queues, queue members, and people currently waiting in the queue,
        or undef on error or timeout. TIMEOUT is optional

        Hash reference structure:

        $hashref->{queue}->{Max}
                           {Calls}
                           {Holdtime}
                           {Completed}
                           {Abandoned}
                           {ServiceLevel}
                           {ServicelevelPerf}
                           {Weight}
                           {MEMBERS}->{name}->{Location}
                                                {Membership}
                                                {Penalty}
                                                {CallsTaken}
                                                {LastCall}
                                                {Status}
                                                {Paused}
                           {ENTRIES}->{position}->{Channel}
                                                    {CallerID}
                                                    {CallerIDName}
                                                    {Wait}

queue_status ( QUEUE [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (none)

        Returns a hash reference containing the queue status, members, and people currently waiting in the queue,
        or undef on error or timeout. TIMEOUT is optional.

        Hash reference structure

        $hashref->{Max}
                  {Calls}
                  {Holdtime}
                  {Completed}
                  {Abandoned}
                  {ServiceLevel}
                  {ServicelevelPerf}
                  {Weight}
                  {MEMBERS}->{name}->{Location}
                                       {Membership}
                                       {Penalty}
                                       {CallsTaken}
                                       {LastCall}
                                       {Status}
                                       {Paused}
                  {ENTRIES}->{position}->{Channel}
                                           {CallerID}
                                           {CallerIDName}
                                           {Wait}

queue_member_pause ( QUEUE, MEMBER [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (agent)

        Pauses MEMBER in QUEUE.
        Returns 1 if the PAUSEVALUE was set, 0 if it failed, or undef on error or timeout. TIMEOUT is optional.

queue_member_unpause ( QUEUE, MEMBER [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (agent)

        Unpauses MEMBER in QUEUE.
        Returns 1 if the PAUSEVALUE was set, 0 if it failed, or undef on error or timeout. TIMEOUT is optional.

queue_add ( QUEUE, MEMEBER [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (agent)

        Adds MEMBER to QUEUE. Returns 1 if the MEMBER was added, or 0 if it failed, or undef on error or timeout.
        TIMEOUT is optional.

queue_remove ( QUEUE, MEMEBER [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (agent)

        Removes MEMBER from QUEUE. Returns 1 if the MEMBER was removed, 0 if it failed, or undef on error or timeout.
        TIMEOUT is optional.

play_dtmf ( CHANNEL, DIGIT [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Plays the dtmf DIGIT on CHANNEL. Returns 1 if the DIGIT was queued on the channel, or 0 if it failed, or
        undef on error or timeout.
        TIMEOUT is optional.

channels ( [ CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (system, call, reporting)

        Returns a hash reference containing all channels with their information, or undef on error or timeout.
        TIMEOUT is optional.

        Hash reference structure:

        $hashref->{channel}->{Context}
                             {CallerID}
                             {CallerIDNum}
                             {CallerIDName}
                             {Account}
                             {State}
                             {Context} 
                             {Extension}
                             {Priority}
                             {Seconds}
                             {Link}
                             {Uniqueid}

chan_status ( CHANNEL [, CALLBACK, TIMEOUT, USERDATA ] )
        
        Manager Version: 1.0+
        Privilege Level: (system, call, reporting)

        Returns a hash reference containing the status of the channel, or undef on error or timeout.
        TIMEOUT is optional.

        Hash reference structure:
        
        $hashref->{Channel}
                  {CallerID}
                  {CallerIDNum}
                  {CallerIDName}
                  {Account}
                  {State}
                  {Context} 
                  {Extension}
                  {Priority}
                  {Seconds}
                  {Link}
                  {Uniqueid}

transfer ( CHANNEL, EXTENSION, CONTEXT [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Transfers CHANNEL to EXTENSION at CONTEXT. Returns 1 if the channel was transferred, 0 if it failed, 
        or undef on error or timeout. TIMEOUT is optional.

meetme_list ( [ CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: 1.0 (command), 1.1+ (reporting)

        Partial support is provided on Asterisk 1.4 via cli commands. When using with asteirsk 1.4 the following
        keys are missing: Role, MarkedUser

        Returns a hash reference containing all meetme conferences and their members, or undef if an error occurred.
        TIMEOUT is optional.

        Hash reference:
        $hashref->{RoomNum}->{MemberChannels}->{Muted}
                                               {Role}
                                               {Talking}
                                               {UserNumber}
                                               {CallerIDName}
                                               {MarkedUser}
                                               {CallerIDNum}
                                               {Admin}

meetme_members ( ROOMNUM [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: 1.0 (command), 1.1+ (reporting)

        Partial support is provided on Asterisk 1.4 via cli commands. When using with asteirsk 1.4 the following
        keys are missing: Role, MarkedUser

        Returns a hash reference containing all members of a meetme conference, or undef if an error occurred.
        TIMEOUT is optional.

        Hash reference:
        $hashref->{MemberChannels}->{Muted}
                                    {Role}
                                    {Talking}
                                    {UserNumber}
                                    {CallerIDName}
                                    {MarkedUser}
                                    {CallerIDNum}
                                    {Admin}

meetme_mute ( CONFERENCE, USERNUM [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Mutes USERNUM in CONFERENCE. Returns 1 if the user was muted, 0 if it failed, or undef on error or timeout.
        TIMEOUT is optional.

meetme_unmute ( CONFERENCE, USERNUM [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Un-mutes USERNUM in CONFERENCE. Returns 1 if the user was un-muted, or 0 if it failed, or undef on error or timeout.
        TIMEOUT is optional.

mute_chan ( CHANNEL [, DIRECTION, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (system)

        Mutes audio on CHANNEL. DIRECTION is optiona and can be 'in' for inbound audio only, 'out' for outbound audio
        only or 'all' to for both directions. If not supplied it defaults to 'all'. Returns 1 on success, 0 if it failed,
        or undef on error or timeout. TIMEOUT is optional.

unmute_chan ( CHANNEL [, DIRECTION, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (system)

        UnMutes audio on CHANNEL. DIRECTION is optiona and can be 'in' for inbound audio only, 'out' for outbound audio
        only or 'all' to for both directions. If not supplied it defaults to 'all'. Returns 1 on success, 0 if it failed,
        or undef on error or timeout. TIMEOUT is optional.

monitor ( CHANNEL, FILE [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Begins recording CHANNEL to FILE. Uses the 'wav' format and also mixes both directions into a single file. 
        Returns 1 if the channel was set to record, or 0 if it failed, or undef on error or timeout. TIMEOUT is optional.

monitor_stop ( CHANNEL [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Stops recording CHANNEL. Returns 1 if recording on the channel was stopped, 0 if it failed, or undef on error
        or timeout.
        TIMEOUT is optional.

monitor_pause ( CHANNEL [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Pauses recording on CHANNEL. Returns 1 if recording on the channel was paused, 0 if it failed, or undef on error
        or timeout.
        TIMEOUT is optional.

monitor_unpause ( CHANNEL [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: (call)

        Un-pauses recording on CHANNEL. Returns 1 if recording on the channel was un-paused, 0 if it failed, or undef on error
        or timeout.
        TIMEOUT is optional.

monitor_change ( CHANNEL, FILE [, CALLBACK, TIMEOUT, USERDATA ] )
        
        Manager Version: 1.0+
        Privilege Level: (call)

        Changes the monitor file for CHANNEL to FILE. Returns 1 if the file was change, 0 if it failed, or undef on error
        or timeout.
        TIMEOUT is optional.

mixmonitor_mute ( CHANNEL [, DIRECTION, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (none)

        Mutes audio on CHANNEL. DIRECTION is optiona and can be 'read' for inbound audio only, 'write' for outbound audio
        only or 'both' to for both directions. If not supplied it defaults to 'both'. Returns 1 on success, 0 if it failed,
        or undef on error or timeout. TIMEOUT is optional.

mixmonitor_unmute ( CHANNEL [, DIRECTION, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (none)

        UnMutes audio on CHANNEL. DIRECTION is optiona and can be 'read' for inbound audio only, 'write' for outbound audio
        only or 'both' to for both directions. If not supplied it defaults to 'both'. Returns 1 on success, 0 if it failed,
        or undef on error or timeout. TIMEOUT is optional.

text ( CHANNEL, MESSAGE [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (call)

        Sends MESSAGE as a text on CHANNEL. Returns 1 on success, 0 on failure, or undef on error or timeout.
        TIMEOUT is optional.

voicemail_list ( [ CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (call, reporting)

        Returns a hash reference of all mailboxes on the system, or undef if an error occurred.
        TIMEOUT is optional.

        Hash reference:
        $hashref->{context}->{mailbox}->{AttachmentFormat}
                                        {TimeZone}
                                        {Pager}
                                        {SayEnvelope}
                                        {ExitContext}
                                        {AttachMessage}
                                        {SayCID}
                                        {ServerEmail}
                                        {CanReview}
                                        {DeleteMessage}
                                        {UniqueID}
                                        {Email}
                                        {MaxMessageLength}
                                        {CallOperator}
                                        {SayDurationMinimum}
                                        {NewMessageCount}
                                        {Language}
                                        {MaxMessageCount}
                                        {Fullname}
                                        {Callback}
                                        {MailCommand}
                                        {VolumeGain}
                                        {Dialout}

module_check ( MODULE [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: 1.0 (command), 1.1+ (system)

        Partial support is provided on Asterisk 1.4 via cli commands.

        Checks to see if MODULE is loaded. Returns 1 on success (loaded), 0 on failure (not loaded), or undef on error or timeout.
        MODULE is the name of the module minus its extension. To check for 'app_meetme.so' you would only use 'app_meetme'.
        TIMEOUT is optional.

module_load, module_reload, module_unload ( MODULE [, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.1+
        Privilege Level: (system)

        Attempts to load/reload/unload MODULE. Returns 1 on success, 0 on failure, or undef on error or timeout.
        MODULE is the name of the module with its extension or an asterisk subsystem. To load 'app_meetme.so' you would use 'app_meetme.so'.
        TIMEOUT is optional.

        Valid Asterisk Subsystems:

                cdr
                enum
                dnsmgr
                extconfig
                manager
                rtp
                http

originate ( CHANNEL, CONTEXT, EXTEN [, CALLERID, CTIMEOUT, CALLBACK, TIMEOUT, USERDATA ] )

        Manager Version: 1.0+
        Privilege Level: 1.0 (call), 1.1+ (originate)

        Attempts to dial CHANNEL and then drops it into EXTEN@CONTEXT in the dialplan. Optionally a CALLERID can be provided.
        CTIMEOUT is optional and determines how long the call will dial/ring for in seconds. TIMEOUT is optional.

        CTIMEOUT + TIMEOUT will be used for the command timeout. For example if CTIMEOUT is 30 seconds and TIMEOUT is 5 seconds, the entire
        command will timeout after 35 seconds.

        Returns 1 on success 0 on failure, or undef on error or timeout.

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
