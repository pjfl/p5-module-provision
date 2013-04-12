# @(#)Ident: 10test_script.t 2013-04-09 18:44 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 42 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use_ok 'Module::Provision';

my $prog = Module::Provision->new_with_options
   ( appclass  => 'Module::Provision',
     base      => 't',
     builder   => 'DZ',
     method    => 'dist',
     nodebug   => 1,
     novcs     => 1,
     project   => 'Foo::Bar',
     templates => catdir( 't', 'code_templates' ) );

$prog->run;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
