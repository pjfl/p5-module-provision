# @(#)$Ident: DZ_Build.PL 2013-08-13 15:09 pjf ;

use strict;
use warnings;

use Module::Build;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

[% IF perl -%]
$] >= [% perl %] or $ENV{PERL5_CPANPLUS_IS_VERSION}
   or whimper "Minimum required Perl version is [% perl %]";
[% END -%]

my $code = do { local $/; <DATA> };

Module::Build->subclass( code => $code )->new(
  'module_name'   => '[% project %]',
  'notes'         => {
     is_reporting => !! ($ENV{AUTOMATED_TESTING}
                     ||  $ENV{PERL_CR_SMOKER_CURRENT}
                     ||  $ENV{PERL5_CPANPLUS_IS_VERSION}
                     || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx), },
  'share_dir'     => -d 'share' ? 'share' : undef,
##{ $plugin->get_prereqs( 1 ) ##}
)->create_build_script;

exit 0;

__DATA__

sub _normalize_prereqs { # Dynamic config
   my $self = shift; my $p = $self->SUPER::_normalize_prereqs;

   my $osname = lc $^O;

   return $p;
}
