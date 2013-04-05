# @(#)Ident: test_script.t 2013-03-27 23:44 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 37 $ =~ /\d+/gmx );
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

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
