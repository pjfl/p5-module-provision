# Name

Module::Provision - Create Perl distributions with VCS and Module::Build toolchain

# Version

0.1.$Revision: 26 $

# Synopsis

    use Module::Provision;

    exit Module::Provision->new_with_options
       ( appclass => 'Module::Provision', nodebug => 1 )->run;

# Description

Create Perl distributions with VCS and Module::Build toolchain

# Configuration and Environment

Defines the following list of attributes;

- `appclass`

    The class name of the new project. Should be the first extra argument on the
    command line

- `base`

    The directory which will contain the new project. Defaults to the users
    home directory

- `branch`

    The name of the initial branch to create. Defaults to `trunk`

- `force`

    Overwrite the output file if it already exists

- `repository`

    Name of the directory containing the VCS repository. Defaults to `repository`

- `templates`

    Location of the code templates in the users home directory. Defaults to
    `.code\_templates`

- `vcs`

    The version control system to use. Defaults to `vcs`

# Subroutines/Methods

## create\_directories

    $self->create_directories( $args );

Creates the required directories for the new distribution

## dist

    $exit_code = $self->dist;

Create a new distribution specified by the module name on the command line

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
calling [Template](http://search.cpan.org/perldoc?Template) passing in the `stash`

## test

    $exit_code = $self->test;

Creates a new test specified by the test file name on the command line

# Diagnostics

None

# Dependencies

- [Class::Usul](http://search.cpan.org/perldoc?Class::Usul)
- [File::DataClass](http://search.cpan.org/perldoc?File::DataClass)
- [Template](http://search.cpan.org/perldoc?Template)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

# Author

Peter Flanigan, `<Support at RoxSoft dot co dot uk>`

# License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](http://search.cpan.org/perldoc?perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
