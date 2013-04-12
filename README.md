# Name

Module::Provision - Create Perl distributions with VCS and Module::Build toolchain

# Version

This documents version v0.3.$Rev: 42 $ of [Module::Provision](https://metacpan.org/module/Module::Provision)

# Synopsis

    # To reduce typing define a shell alias
    alias mp='module_provision --base ~/Projects'

    # Create a new distribution in your Projects directory
    mp dist Foo::Bar

    # Add another module
    cd ~/Projects/Foo-Bar
    mp module Foo::Bat

    # Add a program to the bin directory
    mp program foo-cli

    # Add another test script
    mp test 11another-one.t

    # Command line help
    mp -? | -H | -h [sub-command] | list_methods | dump_self

# Description

[Module::Provision](https://metacpan.org/module/Module::Provision) is used to create a skeletal CPAN distribution,
including basic builder scripts, tests, documentation, and module
code. It creates a VCS repository and, in the Git case, installs some
hooks that mimic the RCS Revision keyword expansion

On first use the directory `~/.code\_templates` is created and
populated with templates and an index file `index.json`. The author
name and email are derived from the system (the environment variables
`AUTHOR` and `EMAIL` take precedence) and stored in the `author`
and `author\_email` files

The project file `Build.PL` loads `inc::Bob` which instantiates an
inline subclass of [Module::Build](https://metacpan.org/module/Module::Build). The code for the subclass is in
`inc::SubClass`. The file `inc::CPANTesting` allows for fine grained
control over which tests are run by which CPAN Testing smokers

# Configuration and Environment

Defines the following list of attributes which can be set from the
command line;

- `base`

    The directory which will contain the new project. Defaults to the users
    home directory

- `branch`

    The name of the initial branch to create. Defaults to `master` for
    Git and `trunk` for SVN

- `builder`

    Which of the three build systems to use. Defaults to `MB`, which is
    [Module::Build](https://metacpan.org/module/Module::Build). Can be `EUMM` for [ExtUtils::MakeMaker](https://metacpan.org/module/ExtUtils::MakeMaker) or `MI`
    for [Module::Install](https://metacpan.org/module/Module::Install)

- `force`

    Overwrite the output files if they already exist

- `license`

    The name of the license used on the project. Defaults to `perl`

- `novcs`

    Do not create or use a VCS. Defaults to `FALSE`. Used by the test script

- `perms`

    Permissions used to create files. Defaults to `644`. Directories and
    programs have the execute bit turned on if the corresponding read bit
    is on

- `project`

    The class name of the new project. Should be the first extra argument on the
    command line

- `repository`

    Name of the directory containing the SVN repository. Defaults to `repository`

- `templates`

    Location of the code templates in the users home directory. Defaults to
    `.code\_templates`

- `vcs`

    The version control system to use. Defaults to `git`

# Subroutines/Methods

The following methods constitute the public API

## create\_directories

    $self->create_directories( $args );

Creates the required directories for the new distribution

## dist

    $exit_code = $self->dist;

Create a new distribution specified by the module name on the command line

## init\_templates

    $exit_code = $self->init_templates;

Initialise the `.code\_templates` directory and create the `index.json` file

## module

    $exit_code = $self->module;

Creates a new module specified by the class name on the command line

## post\_hook

    $self->post_hook( $args );

Runs after the new distribution has been created

## pre\_hook

    $args = $self->pre_hook( {} );

Runs before the new distribution is created

## program

    $exit_code = $self->program;

Creates a new program specified by the program name on the command line

## render\_templates

    $self->render_templates( $args );

Renders the list of templates in `<$args-`templates>> be repeatedly calling
calling [Template](https://metacpan.org/module/Template) passing in the `stash`

## test

    $exit_code = $self->test;

Creates a new test specified by the test file name on the command line

# Diagnostics

Add `-D` to command line to turn on debug output

# Dependencies

- [Class::Usul](https://metacpan.org/module/Class::Usul)
- [Date::Format](https://metacpan.org/module/Date::Format)
- [File::DataClass](https://metacpan.org/module/File::DataClass)
- [File::ShareDir](https://metacpan.org/module/File::ShareDir)
- [Module::Metadata](https://metacpan.org/module/Module::Metadata)
- [Perl::Version](https://metacpan.org/module/Perl::Version)
- [Pod::Markdown](https://metacpan.org/module/Pod::Markdown)
- [Template](https://metacpan.org/module/Template)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module.  Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Provision.  Source
code is on Github git://github.com/pjfl/Module-Provision.git. Patches
and pull requests are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

[Module::Starter](https://metacpan.org/module/Module::Starter) - For some of the documentation and tests

# Author

Peter Flanigan, `@ <Support at RoxSoft dot co dot uk>`

# License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/module/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
