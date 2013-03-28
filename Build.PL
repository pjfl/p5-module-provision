# @(#)Ident: Build.PL 2013-03-27 23:40 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 26 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(Module::Provision),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'             => 5.010,
      'version'          => 0.77,
      'Class::Usul'      => q(0.12.0),
      'File::DataClass'  => q(0.14.0),
      'Template'         => 2.22, },
   recommends            => {
      'App::cpanminus'   => 1.6005,
      'Git::Class'       => 0.12,
      'Pod::Markdown'    => 1.322,
      'SVN::Class'       => 0.16, },
   configure_requires    => {
      'version'          => 0.77,
      'Module::Build'    => 0.38, },
   build_requires        => {
      'Exception::Class' => 1.23,
      'Test::More'       => 0.74, },
   create_readme_md      => 1,
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Provision
# eval: (load-project-state "module-provision")
# mode: perl
# tab-width: 3
# End:
