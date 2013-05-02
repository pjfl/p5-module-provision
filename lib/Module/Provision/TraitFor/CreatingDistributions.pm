# @(#)Ident: CreatingDistributions.pm 2013-05-02 03:34 pjf ;

package Module::Provision::TraitFor::CreatingDistributions;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);
use Cwd                    qw(getcwd);

requires qw(_appbase _appldir builder exec_perms
            _homedir _incdir  _project_file render_templates
            _stash   _testdir vcs);

# Public Methods
sub create_directories {
   my $self = shift; my $perms = $self->exec_perms;

   $self->output( $self->loc( 'Creating directories' ) );
   $self->_appldir->exists or $self->_appldir->mkpath( $perms );
   $self->builder eq 'MB'
      and ($self->_incdir->exists or $self->_incdir->mkpath( $perms ));
   $self->_testdir->exists or $self->_testdir->mkpath( $perms );
   $self->_homedir->parent->exists or $self->_homedir->parent->mkpath( $perms );
   return;
}

sub dist : method {
   my $self = shift;

   $self->pre_hook;
   $self->create_directories;
   $self->render_templates;
   $self->post_hook;
   return OK;
}

sub generate_metadata : method {
   shift->_generate_metadata( FALSE ); return OK;
}

sub post_hook {
   my $self = shift;

   $self->_initialize_vcs;
   $self->_generate_metadata( TRUE );
   $self->vcs eq 'svn' and $self->_svn_ignore_meta_files;
   $self->_test_distribution;
   return;
}

sub pre_hook {
   my $self = shift; my $argv = $self->extra_argv; umask $self->_create_mask;

   $self->_appbase->exists or $self->_appbase->mkpath( $self->exec_perms );
   $self->_stash->{abstract} = shift @{ $argv } || $self->_stash->{abstract};
   __chdir( $self->_appbase );
   return;
}

# Private methods
sub _add_hook {
   my ($self, $hook) = @_; -e ".git${hook}" or return;

   my $path = $self->_appldir->catfile( qw(.git hooks), $hook );

   link ".git${hook}", $path; chmod $self->exec_perms, ".git${hook}";
   return;
}

sub _create_mask {
   my $self = shift; return oct q(0777) ^ $self->exec_perms;
}

sub _generate_metadata {
   my ($self, $create) = @_; __chdir( $self->_appldir );

   my $mdf; my $verbose = $create ? FALSE : TRUE;

   if ($self->builder eq 'DZ') {
      $self->run_cmd( 'dzil build', $verbose ? { out => 'stdout' } : {} );
      $self->run_cmd( 'dzil clean' );
      $mdf = 'README.mkdn';
   }
   elsif ($self->builder eq 'MB') {
      $self->run_cmd( 'perl '.$self->_project_file );
      $self->run_cmd( './Build manifest', $verbose ? { out => 'stdout' } : {} );
      $self->run_cmd( './Build distmeta', $verbose ? { out => 'stdout' } : {} );
      $self->run_cmd( './Build distclean' );
      $mdf = 'README.md';
   }
   elsif ($self->builder eq 'MI') {
      $self->run_cmd( 'perl '.$self->_project_file );
      $self->run_cmd( 'make manifest', $verbose ? { out => 'stdout' } : {} );
      $self->run_cmd( 'make clean' );
      $mdf = 'README.mkdn';
   }

   return $create ? $mdf : undef;
}

sub _initialize_git {
   my $self = shift; __chdir( $self->_appldir );

   $self->run_cmd  ( 'git init'   );
   $self->_add_hook( 'commit-msg' );
   $self->_add_hook( 'pre-commit' );
   $self->run_cmd  ( 'git add .'  );
   $self->run_cmd  ( "git commit -m 'Initialized by ".__PACKAGE__."'" );
   return;
}

sub _initialize_svn {
   my $self = shift; __chdir( $self->_appbase );

   my $repository = $self->_appbase->catdir( $self->repository );

   $self->run_cmd( "svnadmin create ${repository}" );

   my $branch = $self->branch;
   my $msg    = 'Initialized by '.__PACKAGE__;
   my $url    = 'file://'.$repository->catdir( $branch );

   $self->run_cmd( "svn import ${branch} ${url} -m '${msg}'" );

   my $appldir = $self->_appldir; $appldir->rmtree;

   $self->run_cmd( "svn co ${url}" );
   $appldir->filter( sub { $_ !~ m{ \.git }msx and $_ !~ m{ \.svn }msx } );

   for my $target ($appldir->deep->all_files) {
      $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}" );
   }

   $msg = "Add RCS keywords to project files";
   $self->run_cmd( "svn commit ${branch} -m '${msg}'" );
   __chdir( $self->_appldir );
   $self->run_cmd( 'svn update' );
   return;
}

sub _initialize_vcs {
   my $self = shift;

   $self->vcs ne 'none' and $self->output( 'Initializing VCS' );
   $self->vcs eq 'git'  and $self->_initialize_git;
   $self->vcs eq 'svn'  and $self->_initialize_svn;
   return;
}

sub _svn_ignore_meta_files {
   my $self = shift; __chdir( $self->_appldir );

   my $ignores = "LICENSE\nMANIFEST\nMETA.json\nMETA.yml\nREADME";

   $self->run_cmd( "svn propset svn:ignore '${ignores}' ." );
   $self->run_cmd( 'svn commit -m "Ignoring meta files" .' );
   $self->run_cmd( 'svn update' );
   return;
}

sub _test_distribution {
   my $self = shift; __chdir( $self->_appldir );

   my $cmd = $self->builder eq 'DZ' ? 'dzil test' : 'prove t';

   $ENV{AUTHOR_TESTING} = TRUE; $ENV{TEST_SPELLING} = TRUE;
   $self->output ( 'Testing '.$self->_appldir );
   $self->run_cmd( $cmd, $self->quiet ? {} : { out => 'stdout' } );
   return;
}

# Private functions
sub __chdir {
   $_[ 0 ] or throw 'Directory not specified'; chdir $_[ 0 ];
   $_[ 0 ] eq getcwd or throw error => 'Path [_1] cannot change to',
                              args  => [ $_[ 0 ] ];
   return $_[ 0 ];
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::CreatingDistributions - Create distributions

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::CreatingDistributions';

=head1 Version

This documents version v0.9.$Rev: 1 $ of L<Module::Provision::TraitFor::CreatingDistributions>

=head1 Description

Create distributions

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 create_directories

Creates the required directories for the new distribution. If subclassed this
method can be modified to include additional directories

=head2 dist

   module_provision dist Foo::Bar 'Optional one line abstract'

Create a new distribution specified by the module name on the command line

=head2 generate_metadata

   module_provision generate_metadata

Generates the distribution metadata files

=head2 post_hook

Runs after the new distribution has been created. If subclassed this method
can be modified to perform additional actions after the templates have been
rendered

=head2 pre_hook

Runs before the new distribution is created. If subclassed this method
can be modified to perform additional actions before the project directories
are created

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
