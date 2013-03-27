# @(#)$Id: Build.PL 25 2013-03-26 22:42:17Z pjf $

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 25 $ =~ /\d+/gmx );

Bob->new( {
   module     => q(Module::Provision),
   home_page  => q(http://www.roxsoft.co.uk),
   requires   => {
      'perl'             => 5.010,
      'version'          => 0.77,
      'Class::Usul'      => q(0.12.0),
      'File::DataClass'  => q(0.14.0),
      'Template'         => 2.22,
   },
   recommends            => {
      'App::cpanminus'   => 1.6005 },
   configure_requires    => {
      'version'          => 0.77,
      'Module::Build'    => 0.38, },
   build_requires        => {
      'Exception::Class' => 1.23,
      'Test::More'       => 0.74, },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Provision
# eval: (load-project-state "module-provision")
# mode: perl
# tab-width: 3
# End:
