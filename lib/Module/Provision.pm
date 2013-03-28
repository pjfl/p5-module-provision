# @(#)Ident: Provision.pm 2013-03-28 16:01 pjf ;
# Must patch Module::Build from Class::Usul/inc/M_B_*

package Module::Provision;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 26 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(class2appdir classdir classfile distname
                                    home2appldir prefix2class throw trim);
use Class::Usul::Time            qw(time2str);
use Cwd                          qw(getcwd);
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(Directory Path);
use File::Spec::Functions        qw(catdir);
use Template;
use User::pwent;

extends q(Class::Usul::Programs);

MooseX::Getopt::OptionTypeMap->add_option_type_to_map( Path, '=s' );

has 'appclass'    => is => 'lazy', isa => NonEmptySimpleStr,
   documentation  => 'The class name of the new project';

has 'base'        => is => 'lazy', isa => Path, coerce => TRUE,
   documentation  => 'The directory which will contain the new project',
   default        => sub { $_[ 0 ]->config->my_home };

has 'branch'      => is => 'ro',   isa => NonEmptySimpleStr,
   documentation  => 'The name of the initial branch to create',
   default        => 'trunk';

has 'create_mask' => is => 'ro',   isa => PositiveInt, default => 0750,
   documentation  => 'Default permission for directory creation';

has 'force'       => is => 'ro',   isa => Bool, default => FALSE,
   documentation  => 'Overwrite the output file if it already exists',
   traits         => [ 'Getopt' ], cmd_aliases => q(f), cmd_flag => 'force';

has 'repository'  => is => 'ro',   isa => NonEmptySimpleStr,
   documentation  => 'Name of the directory containing the VCS repository',
   default        => 'repository';

has 'templates'   => is => 'ro',   isa => NonEmptySimpleStr,
   documentation  => 'Location of the code templates in the users home dir',
   default        => '.code_templates';

has 'vcs'         => is => 'ro',   isa => NonEmptySimpleStr,
   documentation  => 'The version control system to use',
   default        => 'svn';


has '_appbase'       => is => 'lazy', isa => NonEmptySimpleStr,
   default           => sub { class2appdir $_[ 0 ]->appclass };

has '_appldir'       => is => 'lazy', isa => Path, coerce => TRUE;

has '_author'        => is => 'lazy', isa => NonEmptySimpleStr;

has '_author_email'  => is => 'lazy', isa => NonEmptySimpleStr;

has '_binsdir'       => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_appldir, 'bin' ] };

has '_dist_module'   => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_homedir.'.pm' ] };

has '_home'          => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { $_[ 0 ]->config->my_home };

has '_homedir'       => is => 'lazy', isa => Path, coerce => TRUE;

has '_home_page'     => is => 'lazy', isa => NonEmptySimpleStr;

has '_incdir'        => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_appldir, 'inc' ] };

has '_libdir'        => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_appldir, 'lib' ] };

has '_project_file'  => is => 'lazy', isa => NonEmptySimpleStr;

has '_stash'         => is => 'lazy', isa => HashRef, reader => 'stash';

has '_template_list' => is => 'lazy', isa => ArrayRef,
   reader            => 'template_list';

has '_template_dir'  => is => 'lazy', isa => Directory, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_home, $_[ 0 ]->templates ] };

has '_testdir'       => is => 'lazy', isa => Path, coerce => TRUE,
   default           => sub { [ $_[ 0 ]->_appldir, 't' ] };

sub create_directories {
   my ($self, $args) = @_; my $perms = $self->create_mask;

   $self->_appldir->exists or $self->_appldir->mkpath( $perms );
   $self->_homedir->exists or $self->_homedir->mkpath( $perms );
   $self->_incdir->exists  or $self->_incdir->mkpath( $perms );
   $self->_testdir->exists or $self->_testdir->mkpath( $perms );
   return;
}

sub dist : method {
   my $self = shift; my $args = $self->pre_hook( {} );

   $self->create_directories( $args );
   $self->render_templates( $args );
   $self->post_hook( $args );
   return OK;
}

sub module : method {
   my $self   = shift;
   my $module = $self->extra_argv->[ 0 ];
   my $target = $self->_get_target( '_libdir', \&classfile );

   $self->stash->{module} = $module;
   $target = $self->_render_template( 'perl_module.pm', $target );
   $self->_add_to_vcs( { target => $target, type => 'module' } );
   return OK;
}

sub post_hook {
   my ($self, $args) = @_;

   $self->_initialize_vcs( $args );
   $self->_initialize_distribution( $args );
   $self->_test_distribution( $args );
   return;
}

sub pre_hook {
   my ($self, $args) = @_; $args ||= {};

   my $appbase = $args->{appbase} = $self->base->catdir( $self->_appbase );

   $appbase->exists or $appbase->mkpath( $self->create_mask );

   __chdir( $appbase ); $args->{templates} = $self->template_list;

   return $args;
}

sub program : method {
   my $self    = shift;
   my $program = $self->extra_argv->[ 0 ];
   my $target  = $self->_get_target( '_binsdir' );

   $self->stash->{program_name} = $program;
   $target = $self->_render_template( 'perl_program.pl', $target );
   $self->_add_to_vcs( { target => $target, type => 'program' } );
   return OK;
}

sub render_templates {
   my ($self, $args) = @_; my $templates = $args->{templates};

   for my $tuple (@{ $templates }) {
      for (my $i = 0, my $max = @{ $tuple }; $i < $max; $i++) {
         my $method = $tuple->[ $i ];

         '_' eq substr $method, 0, 1 and $tuple->[ $i ] = $self->$method();
      }

      $self->_render_template( @{ $tuple } );
   }

   return;
}

sub test : method {
   my $self = shift; my $target = $self->_get_target( '_testdir' );

   $target = $self->_render_template( 'test_script.t', $target );
   $self->_add_to_vcs( { target => $target, type => 'test' } );
   return OK;
}

# Private methods

sub _add_to_git {
   my ($self, $args) = @_; my $target = $args->{target};

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd( "git add ${target}", $params );
   return;
}

sub _add_to_svn {
   my ($self, $args) = @_; my $target = $args->{target};

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd( "svn add ${target} --parents", $params );
   $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}",
                   $params );
   $args->{type} and $args->{type} eq 'program'
      and $self->run_cmd( "svn propset svn:executable '*' ${target}", $params );
   return;
}

sub _add_to_vcs {
   my ($self, $args) = @_; $args ||= {};

  $args->{target} or throw 'SVN target not specified';

   $self->vcs eq 'git' and $self->_add_to_git( $args );
   $self->vcs eq 'svn' and $self->_add_to_svn( $args );
   return;
}

sub _build_appclass {
   my $appclass = $_[ 0 ]->extra_argv->[ 0 ]
      or throw 'Application class not specified';

   return $appclass
}

sub _build__appldir {
   return [ $_[ 0 ]->base, $_[ 0 ]->_appbase, $_[ 0 ]->branch ];
}

sub _build__author {
   my $path      = $_[ 0 ]->_template_dir->catfile( 'author' );
   my $from_file = $path->exists ? trim $path->getline : FALSE;

   $from_file and return $from_file;

   my $user      = getpwuid( $UID );
   my $fullname  = (split m{ \s* , \s * }msx, $user->gecos)[ 0 ];
   my $author    = $ENV{AUTHOR} || $fullname || $user->name;

   $path->print( $author );
   return $author;
}

sub _build__author_email {
   my $path  = $_[ 0 ]->_template_dir->catfile( 'author_email' );

   my $from_file = $path->exists ? trim $path->getline : FALSE;

   $from_file and return $from_file;

   my $email = $ENV{EMAIL} || 'dave@example.com'; $path->print( $email );

   return $email;
}

sub _build__home_page {
   my $path = $_[ 0 ]->_template_dir->catfile( 'home_page' );

   return $path->exists ? trim $path->getline : 'http://example.com';
}

sub _build__homedir {
   return [ $_[ 0 ]->_libdir, classdir $_[ 0 ]->appclass ];
}

sub _build__project_file {
   my $self = shift; my $templates = $self->_template_dir;

   return $templates->catfile( 'Build.PL'    )->exists ? 'Build.PL'
        : $templates->catfile( 'Makefile.PL' )->exists ? 'Makefile.PL'
        : NUL;
}

sub _build__stash {
   my $self     = shift;
   my $appclass = $self->appclass;
   my $author   = $self->_author;

   return { appbase        => $self->_appbase,
            appclass       => $appclass,
            author         => $author,
            author_email   => $self->_author_email,
            copyright      => $ENV{ORGANIZATION} || $author,
            copyright_year => time2str( '%Y' ),
            creation_date  => time2str,
            dist_module    => $self->_dist_module,
            distname       => distname $appclass,
            first_name     => lc ((split SPC, $author)[ 0 ]),
            home_page      => $self->_home_page,
            last_name      => lc ((split SPC, $author)[ -1 ]),
            license        => 'perl',
            module         => $appclass,
            perl           => $],
            prefix         => (split m{ :: }mx, lc $appclass)[ -1 ], };
}

sub _build__template_list {
   my $self = shift; my $index = $self->_template_dir->catfile( 'index.json' );

   my $list; $index->exists and $list = $self->file->data_load
      ( paths => [ $index ], storage_class => 'Any' )->{templates};

   $list and return $list;

   $list = [ [ '_project_file',   '_appldir'     ],
             [ 'Changes',         '_appldir'     ],
             [ 'MANIFEST.SKIP',   '_appldir'     ],
             [ 'Bob.pm',          '_incdir'      ],
             [ 'CPANTesting.pm',  '_incdir'      ],
             [ 'perl_module.pm',  '_dist_module' ],
             [ '01always_pass.t', '_testdir'     ],
             [ '02pod.t',         '_testdir'     ],
             [ '03podcoverage.t', '_testdir'     ],
             [ '04critic.t',      '_testdir'     ],
             [ '05kwalitee.t',    '_testdir'     ],
             [ '06yaml.t',        '_testdir'     ],
             [ '07podspelling.t', '_testdir'     ],
             [ 'test_script.t',   '_testdir'     ], ];

   $self->file->data_dump( data => { templates => $list }, path => $index,
                           storage_class => 'Any' );
   return $list;
}

sub _find_appldir {
   my $self = shift; my $dir = $self->io( getcwd ); my $prev;

   while (not $prev or $prev ne $dir) {
      $dir->catfile( 'Build.PL'    )->exists and return $dir;
      $dir->catfile( 'Makefile.PL' )->exists and return $dir;
      $prev = $dir; $dir = $dir->parent;
   }

   throw error => 'File [_1] not in path', args => [ $self->_project_file ];
   return; # Never reached
}

sub _get_target {
   my ($self, $dir, $f) = @_;

   my $car    = shift @{ $self->extra_argv } or throw 'No target specified';

   $self->extra_argv->[ 0 ] or $self->_push_appclass;

   my $target = $self->$dir->catfile( $f ? $f->( $car ) : $car );

   $target->assert_filepath;
   return $target;
}

sub _initialize_distribution {
   my ($self, $args) = @_; __chdir( $self->_appldir );

   my $builder = $self->_project_file eq 'Build.PL' ? './Build' : 'make';

   $self->run_cmd( 'perl '.$self->_project_file );
   $self->run_cmd( "${builder} manifest" );
   $self->run_cmd( "${builder} distmeta" );
   $self->run_cmd( "${builder} distclean" );
   return;
}

sub _initialize_git {
   my ($self, $args) = @_; __chdir( $self->_appldir );

   my $branch = $self->branch; my $msg = "Created ${branch}";

   $self->run_cmd( 'git init' ); $self->run_cmd( 'git add .' );

   $self->run_cmd( "git commit -m '${msg}' ." );
   return;
}

sub _initialize_svn {
   my ($self, $args) = @_; my $appbase = $args->{appbase}; __chdir( $appbase );

   my $repository = $appbase->catdir( $self->repository );

   $self->run_cmd( "svnadmin create ${repository}" );

   my $branch     = $self->branch;
   my $msg        = "Imported ${branch}";
   my $url        = 'file://'.catdir( $repository, $branch );

   $self->run_cmd( "svn import ${branch} ${url} -m '${msg}'" );

   my $appldir = $self->_appldir; $appldir->rmtree;

   $self->run_cmd( "svn co ${url}" );
   $appldir->filter( sub { $_ !~ m{ \.git }msx and $_ !~ m{ \.svn }msx } );

   for my $target ($appldir->deep->all_files) {
      $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}" );
   }

   $msg = "Add RCS keywords to ${branch}";
   $self->run_cmd( "svn commit ${branch} -m '${msg}'" );
   return;
}

sub _initialize_vcs {
   my ($self, $args) = @_;

   $self->vcs eq 'git' and $self->_initialize_git( $args );
   $self->vcs eq 'svn' and $self->_initialize_svn( $args );
   return;
}

sub _push_appclass {
   my $self = shift; my $meta = $self->get_meta( $self->_find_appldir );

   return push @{ $self->extra_argv }, prefix2class $meta->name;
}

sub _render_template {
   my ($self, $template, $target) = @_;

   $template or throw 'No template specified';
   $target   or throw 'No template target specified';

   $target->exists and $target->is_dir
      and $target = $target->catfile( $template );
   $template  = $self->_template_dir->catfile( $template );

   $template->exists or
      return $self->log->warn( $self->loc( 'Path [_1] not found', $template ) );

   my $prompt; $target->exists and not $self->force
      and $prompt = $self->add_leader( 'Specified file exists, overwrite?' )
      and not $self->yorn( $prompt, FALSE, FALSE )
      and return $target;

   my $conf   = { ABSOLUTE => TRUE, };

   $conf->{VARIABLES}->{loc} = sub { return $self->loc( @_ ) };

   my $tmplt  = Template->new( $conf ) or throw $Template::ERROR;
   my $text   = NUL;

   $tmplt->process( $template->pathname, $self->stash, \$text )
      or throw $tmplt->error();

   $target->print( $text );
   return $target;
}

sub _test_distribution {
   my ($self, $args) = @_; __chdir( $self->_appldir );

   $ENV{TEST_SPELLING} = TRUE;
   $self->output ( 'Testing '.$self->_appldir );
   $self->run_cmd( 'prove t', $self->quiet ? {} : { out => 'stdout' } );
   return;
}

# Private functions

sub __chdir {
   $_[ 0 ] or throw 'Directory not specified'; chdir $_[ 0 ];
   $_[ 0 ] eq getcwd or throw error => 'Path [_1] cannot change to',
                              args  => [ $_[ 0 ] ];
   return $_[ 0 ];
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Module::Provision - Create Perl distributions with VCS and Module::Build toolchain

=head1 Version

0.1.$Revision: 26 $

=head1 Synopsis

   use Module::Provision;

   exit Module::Provision->new_with_options
      ( appclass => 'Module::Provision', nodebug => 1 )->run;

=head1 Description

Create Perl distributions with VCS and Module::Build toolchain

=head1 Configuration and Environment

Defines the following list of attributes;

=over 3

=item C<appclass>

The class name of the new project. Should be the first extra argument on the
command line

=item C<base>

The directory which will contain the new project. Defaults to the users
home directory

=item C<branch>

The name of the initial branch to create. Defaults to F<trunk>

=item C<force>

Overwrite the output file if it already exists

=item C<repository>

Name of the directory containing the VCS repository. Defaults to F<repository>

=item C<templates>

Location of the code templates in the users home directory. Defaults to
F<.code_templates>

=item C<vcs>

The version control system to use. Defaults to C<vcs>

=back

=head1 Subroutines/Methods

=head2 create_directories

   $self->create_directories( $args );

Creates the required directories for the new distribution

=head2 dist

   $exit_code = $self->dist;

Create a new distribution specified by the module name on the command line

=head2 module

   $exit_code = $self->module;

Creates a new module specified by the class name on the command line

=head2 post_hook

   $self->post_hook( $args );

Runs after the new distribution has been created

=head2 pre_hook

   $args = $self->pre_hook( {} );

Runs before the new distribution is created

=head2 program

   $exit_code = $self->program;

Creates a new program specified by the program name on the command line

=head2 render_templates

   $self->render_templates( $args );

Renders the list of templates in C<<$args->templates>> be repeatedly calling
calling L<Template> passing in the C<stash>

=head2 test

   $exit_code = $self->test;

Creates a new test specified by the test file name on the command line

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<File::DataClass>

=item L<Template>

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

Peter Flanigan, C<< <Support at RoxSoft dot co dot uk> >>

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
