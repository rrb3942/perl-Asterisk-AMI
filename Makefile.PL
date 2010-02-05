use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.


WriteMakefile(
    NAME              => 'AMI',
    VERSION_FROM      => 'lib/AMI.pm', # finds $VERSION
    PREREQ_PM         => { "IO::Socket::INET" => 0,
			   "Digest::MD5" => 0},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/AMI.pm', # retrieve abstract from module
       AUTHOR         => 'Ryan Bullock <rrb3942@gmail.com>') : ()),
);
