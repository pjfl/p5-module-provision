# @(#)$Id: 04critic.t 2 2012-11-05 20:16:55Z pjf $

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   if (!-e catfile( $Bin, updir, q(MANIFEST.SKIP) )) {
      plan skip_all => 'Critic test only for developers';
   }
}

eval "use Test::Perl::Critic -profile => catfile( q(t), q(critic.rc) )";

plan skip_all => 'Test::Perl::Critic not installed' if ($EVAL_ERROR);

unless ($ENV{TEST_CRITIC}) {
   plan skip_all => 'Environment variable TEST_CRITIC not set';
}

all_critic_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
