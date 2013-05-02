# @(#)Ident: AddingFiles.pm 2013-05-02 03:34 pjf ;

package Module::Provision::TraitFor::AddingFiles;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(classfile throw);

requires qw(_appldir default_module_abstract exec_perms _stash);

# Construction
around '_generate_metadata' => sub {
   my ($next, $self, @args) = @_; my $mdf = $self->$next( @args );

   $mdf and $self->_appldir->catfile( $mdf )->exists
        and $self->_add_to_vcs( $mdf );

   return $mdf;
};

# Public methods
sub module : method {
   my $self = shift; my $target = $self->_get_target( '_libdir', \&classfile );

   $self->output( $self->loc( 'Adding new module' ) );
   $target = $self->render_template( 'perl_module.pm', $target );
   $self->_add_to_vcs( $target, 'module' );
   return OK;
}

sub program : method {
   my $self = shift; my $target = $self->_get_target( '_binsdir' );

   $self->output( $self->loc( 'Adding new program' ) );
   $target = $self->render_template( 'perl_program.pl', $target );
   chmod $self->exec_perms, $target->pathname;
   $self->_add_to_vcs( $target, 'program' );
   return OK;
}

sub test : method {
   my $self = shift; my $target = $self->_get_target( '_testdir' );

   $self->output( $self->loc( 'Adding new test' ) );
   $target = $self->render_template( '10test_script.t', $target );
   $self->_add_to_vcs( $target, 'test' );
   return OK;
}

# Private methods
sub _add_to_git {
   my ($self, $target, $type) = @_;

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd( "git add ${target}", $params );
   return;
}

sub _add_to_svn {
   my ($self, $target, $type) = @_;

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd( "svn add ${target} --parents", $params );
   $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}",
                   $params );
   $type and $type eq 'program'
      and $self->run_cmd( "svn propset svn:executable '*' ${target}", $params );
   return;
}

sub _add_to_vcs {
   my ($self, $target, $type) = @_; $target or throw 'VCS target not specified';

   $self->vcs eq 'git' and $self->_add_to_git( $target, $type );
   $self->vcs eq 'svn' and $self->_add_to_svn( $target, $type );
   return;
}

sub _default_program_abstract {
   return $_[ 0 ]->loc( 'One-line description of the programs purpose' );
}

sub _get_target {
   my ($self, $dir, $f) = @_; my $argv = $self->extra_argv;

   my $car      = shift @{ $argv } or throw 'No target specified';
   my $abstract = shift @{ $argv } || ($self->method eq 'program'
                                     ? $self->_default_program_abstract
                                     : $self->default_module_abstract );

   $self->project; # Force evaluation of lazy attribute

   my $target   = $self->$dir->catfile( $f ? $f->( $car ) : $car );

   $target->perms( $self->perms )->assert_filepath;

   if    ($self->method eq 'module')  { $self->_stash->{module      } = $car }
   elsif ($self->method eq 'program') { $self->_stash->{program_name} = $car }

   $self->method ne 'test' and $self->_stash->{abstract} = $abstract;

   return $target;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::AddingFiles - Adds additional files to the project

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::AddingFiles';

=head1 Version

This documents version v0.9.$Rev: 1 $ of L<Module::Provision::TraitFor::AddingFiles>

=head1 Description

Adds additional modules, programs, and tests to the project

=head1 Configuration and Environment

Requires the following attributes to be defined in the consuming
class; C<_appldir>, C<default_module_abstract>, C<exec_perms>, C<loc>,
C<output>, and C<_stash>

Modifies the C<_generate_metadata> method. If C<_generate_metadata> returns
a pathname and the file exists it is added to the VCS

Defines no attributes

=head1 Subroutines/Methods

=head2 module

   module_provision module Foo::Bat 'Optional one line abstract'

Creates a new module specified by the class name on the command line

=head2 program

   module_provision program bar-cli 'Optional one line abstract'

Creates a new program specified by the program name on the command line

=head2 test

   module_provision test 11another-one.t

Creates a new test specified by the test file name on the command line

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moose::Role>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
