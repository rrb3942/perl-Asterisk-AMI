#!/usr/bin/perl

=head1 NAME

AMI::Common::Dev - Extends AMI::Common to include functions for the current development branch of asterisk

=head1 VERSION

0.1.2

=head1 SYNOPSIS

	use AMI::Common:Dev;

	my $astman = AMI::Common::Dev->new(	PeerAddr	=>	'127.0.0.1',
						PeerPort	=>	'5038',
						Username	=>	'admin',
						Secret		=>	'supersecrect'
					);

	die "Unable to connect to asterisk" unless ($astman);

	$astman->bridge($channel1, $channel2);

=head1 DESCRIPTION

This module extends AMI::Common::Dev to include additional functions for working with the development branch of Asterisk.
It will also be the launching ground for new functions be they are merged into AMI::Common.

=head2 Constuctor

=head3 new([ARGS])

Creates new a AMI::Common object which takes the arguments as key-value pairs.

This module inherits all options from the AMI module.

=head2 Methods

This module does nothing yet. Pending me getting an asteirsk 1.6 box up for testing.

=head1 See Also

AMI, AMI::Common, AMI::Events

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

package AMI::Common::Dev;

use strict;
use warnings;
use parent qw(AMI::Common);

return 1;
