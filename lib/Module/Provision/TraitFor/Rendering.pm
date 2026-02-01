package Module::Provision::TraitFor::Rendering;

use Class::Usul::Cmd::Constants qw( EXCEPTION_CLASS FALSE NUL OK TRUE );
use File::DataClass::Types      qw( ArrayRef Bool Directory Path SimpleStr );
use Class::Usul::Cmd::Util      qw( app_prefix distname dump_file load_file
                                    throw );
use File::DataClass::IO         qw( io );
use Ref::Util                   qw( is_arrayref );
use Scalar::Util                qw( blessed weaken );
use Unexpected::Functions       qw( Unspecified );
use File::ShareDir                ( );
use Template;
use Moo::Role;
use Class::Usul::Cmd::Options;

requires qw( add_leader appldir builder config dist_module exec_perms
             incdir initial_wd log perms stash testdir vcs yorn );

# Object attributes (public)
option 'force'   =>
   is            => 'ro',
   isa           => Bool,
   documentation => 'Overwrite files if they already exist',
   default       => FALSE,
   short         => 'f';

option 'templates' =>
   is            => 'ro',
   isa           => SimpleStr,
   documentation => 'Non default location of the code templates',
   default       => NUL,
   format        => 's';

has 'template_dir' =>
   is       => 'lazy',
   isa      => Directory,
   init_arg => undef,
   coerce   => TRUE;

has 'template_list' => is => 'lazy', isa => ArrayRef, init_arg => undef;

# Object attributes (private)
has '_template_index' =>
   is       => 'lazy',
   isa      => Path,
   init_arg => undef,
   coerce   => TRUE;

# Public methods
sub dump_stash : method {
   my $self = shift;

   $self->dumper($self->stash);

   return OK;
}

sub expand_tuple {
   my ($self, $tuple) = @_;

   for (my $i = 0, my $max = @{$tuple}; $i < $max; $i++) {
      if (is_arrayref $tuple->[$i]) {
         $tuple->[$i]->[0] = $self->_deref_tmpl($tuple->[$i]->[0]);
         $tuple->[$i] = io($tuple->[$i]);
      }
      else {
         $tuple->[$i] = $self->_deref_tmpl($tuple->[$i]);
      }
   }

   return $tuple;
}

sub init_templates : method {
   my $self = shift;

   $self->template_list;
   return OK;
}

sub render_template {
   my ($self, $template, $target) = @_;

   throw Unspecified, ['Template'] unless $template;
   throw Unspecified, ['Template target'] unless $target;

   $target = $target->catfile($template)
      if $target->exists and $target->is_dir;

   $template = $self->template_dir->catfile($template);

   return $self->log->warn("Path ${template} not found")
      unless $template->exists;

   my $file  = $target->filename;

   if ($target->exists && !$self->force) {
      my $prompt = "File ${file} exists, overwrite?";

      return $target
         unless $self->yorn($self->add_leader($prompt), FALSE, TRUE);
   }

   my $tmplt = Template->new($self->_template_args) or throw $Template::ERROR;
   my $text  = NUL;

   throw $tmplt->error()
      unless $tmplt->process($template->pathname, $self->stash, \$text);

   $target->perms($self->perms)->print($text);
   $target->close;
   return $target;
}

sub render_templates {
   my $self = shift;

   $self->output('Rendering templates') unless $self->quiet;

   for my $tuple (map { $self->expand_tuple($_) } @{$self->template_list}) {
      $self->render_template(@{$tuple});
   }

   return;
}

# Construction
sub _build_template_dir {
   my $self  = shift;
   my $class = blessed $self;
   my $tgt   = $self->templates
             ? io([ $self->templates ])->absolute($self->initial_wd)
             : io([ $self->config->my_home, '.' . (app_prefix $class) ]);

   return $tgt if $tgt->exists;

   $tgt->mkpath($self->exec_perms);

   my $dist = io(File::ShareDir::dist_dir(distname $class));

   $_->copy($tgt) for ($dist->all_files);

   return $tgt;
}

sub _build__template_index {
   return $_[0]->template_dir->catfile($_[0]->config->template_index);
}

sub _build_template_list {
   my $self  = shift;
   my $index = $self->_template_index;

   return $self->_merge_lists(load_file($index)) if $index->exists;

   my $builders  = {
      DZ => [ [ 'dist.ini',      '_appldir' ],
              [ 'DZ_Build.PL', [ '_appldir', '.build.PL' ], ], ],
      MB => [ [ 'Build.PL',      '_appldir' ], ], };
   my $templates = [ [ 'Changes',         '_appldir'     ],
                     [ 'MANIFEST.SKIP',   '_appldir'     ],
                     [ 'travis.yml',    [ '_appldir', '.travis.yml' ] ],
                     [ 'perl_module.pm',  '_dist_module' ],
                     [ '02pod.t',         '_testdir'     ],
                     [ '03podcoverage.t', '_testdir'     ],
                     [ '05kwalitee.t',    '_testdir'     ],
                     [ '06yaml.t',        '_testdir'     ],
                     [ '07podspelling.t', '_testdir'     ],
                     [ '10test_script.t', '_testdir'     ],
                     [ 'boilerplate.pm',  '_testdir'     ], ];
   my $vcs = {
      git => [ [ 'gitcommit-msg', [ '_appldir', '.gitcommit-msg' ] ],
               [ 'gitignore',     [ '_appldir', '.gitignore'     ] ],
               [ 'gitpre-commit', [ '_appldir', '.gitpre-commit' ] ], ],
      svn => [], };

   $self->output('Creating index [_1]', { args => [$index] });

   my $data = { builders => $builders, templates => $templates, vcs => $vcs };

   dump_file($index, $data);

   return $self->_merge_lists($data);
}

# Private methods
sub _deref_tmpl {
   my ($self, $car) = @_;

   return $car if '_' ne substr $car, 0, 1;

   my $reader = substr $car, 1;

   return $self->$reader();
}

sub _merge_lists {
   my ($self, $args) = @_;

   my $list = $args->{templates};

   push @{$list}, @{$args->{builders}->{$self->builder}};

   push @{$list}, @{$args->{vcs}->{$self->vcs}} if $self->vcs ne 'none';

   return $list;
}

sub _template_args {
   my $self = shift; weaken( $self );
   my $args = { ABSOLUTE => TRUE, };

   $args->{VARIABLES}->{loc} = sub { @_ };

   return $args;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::Rendering - Renders Templates

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::Rendering';

=head1 Description

Renders templates. Uses a list stored in the index file F<index.json> which
by default is in the F<~/.module_provision> directory

=head1 Configuration and Environment

Requires the consuming class to define the attributes; C<appldir>,
C<builder>, C<dist_module>, C<incdir>, C<initial_wd>, C<stash>,
C<testdir>, and C<vcs>

Defines the following attributes;

=over 3

=item C<force>

Overwrite the output files if they already exist

=item C<templates>

Location of the code templates in the users home directory. Defaults to
F<.module_provision>

=item C<template_dir>

Directory where the templates live

=item C<template_list>

Data structure that maps the files in the template directory to the files
in the project directory

=back

=head1 Subroutines/Methods

=head2 dump_stash - Dump the hash ref used to render a template

   $exit_code = $self->dump_stash;

Uses the internal dumper method to produce a pretty coloured listing

=head2 expand_tuple

   $tuple = $self->expand_tuple( $tuple );

Expands the references in the passed tuple

=head2 init_templates - Initialise the template directory

   $exit_code = $self->init_templates;

Initialise the F<.module_provision> directory and create the F<index.json> file

=head2 render_template

   $target = $self->render_template( $template, $target );

Renders a single template using L<Template>

=head2 render_templates

   $self->render_templates;

Renders the list of templates in C<< $self->template_list >> be
repeatedly calling calling L</render_template>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd>

=item L<File::DataClass>

=item L<File::ShareDir>

=item L<Moose::Role>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2017 Peter Flanigan. All rights reserved

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
