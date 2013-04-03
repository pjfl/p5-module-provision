use [% perl %];
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => '[% appclass %]',
    AUTHOR           => q{[% author %]},
    VERSION_FROM     => '[% dist_module %]',
    ABSTRACT_FROM    => '[% dist_module %]',
    LICENSE          => '[% license %]',
    PL_FILES         => {},
    MIN_PERL_VERSION => [% perl %],
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => '[% distname %]-*' },
);
