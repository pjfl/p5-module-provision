use t::boilerplate;

use Test::More;

use_ok 'Module::Provision::MetaData';

my $o = Module::Provision::MetaData->new;

my $res = $o->read_file;

ok exists $res->{ 'Module::Provision' }, 'Expected result';

done_testing;
