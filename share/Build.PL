# @(#)$Ident: Build.PL 2013-03-29 19:02 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 31 $ =~ /\d+/gmx );

Bob->new( {
   module    => q([% appclass %]),
   home_page => q([% home_page %]),
   requires  => {
      'perl'             => 5.010,
      'version'          => 0.77,
      'Class::Usul'      => q(0.12.0),
      'File::DataClass'  => q(0.15.0),
   },
   recommends            => {
      'App::cpanminus'   => 1.6005,
      'Pod::Markdown'    => 1.322, },
   configure_requires    => {
      'version'          => 0.77,
      'Module::Build'    => 0.38, },
   build_requires        => {
      'Exception::Class' => 1.23,
      'Test::More'       => 0.74, },
} )->create_build_script; # Goal!

# Local Variables:
# eval: (load-project-state "[% appbase %]")
# mode: perl
# tab-title: [% appclass %]
# tab-width: 3
# End:
