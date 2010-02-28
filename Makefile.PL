use 5.008000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.


WriteMakefile(
    NAME              => 'Asterisk::AMI',
    VERSION_FROM      => 'lib/Asterisk/AMI.pm', # finds $VERSION
    PREREQ_PM         => { "parent" => 0,
			   "version" => 0,
			   "AnyEvent" => "5.0",
			   "AnyEvent::Socket" => 0,
			   "AnyEvent::Handle" => 0
			},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Asterisk/AMI.pm', # retrieve abstract from module
       AUTHOR         => 'Ryan Bullock <rrb3942@gmail.com>') : ()),
);
