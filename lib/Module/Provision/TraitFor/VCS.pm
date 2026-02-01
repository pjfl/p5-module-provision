package Module::Provision::TraitFor::VCS;

use Class::Usul::Cmd::Constants qw( EXCEPTION_CLASS FALSE OK TRUE );
use Class::Usul::Cmd::Types     qw( Bool HashRef Str );
use Class::Usul::Cmd::Util      qw( is_win32 throw );
use File::DataClass::IO         qw( io );
use Scalar::Util                qw( blessed );
use Unexpected::Functions       qw( Unspecified );
use Perl::Version;
use Moo::Role;
use Class::Usul::Cmd::Options;

requires qw( add_leader appbase appldir branch build_distribution chdir config
             cpan_upload default_branch dist_version distname editor exec_perms
             extra_argv generate_metadata get_line next_argv output quiet
             run_cmd test_upload update_version vcs );

# Public attributes
option 'no_auto_rev' =>
   is            => 'ro',
   isa           => Bool,
   documentation => 'Do not turn on Revision keyword expansion',
   default       => FALSE;

has 'cmd_line_flags' =>
   is      => 'lazy',
   isa     => HashRef[Bool],
   builder => '_build_cmd_line_flags';

# Private attributes
has '_new_version' => is => 'rwp', isa => Str;

# Construction
around 'dist_post_hook' => sub {
   my ($next, $self, @args) = @_;

   $self->_initialize_vcs;

   my $r = $self->$next(@args);

   $self->_reset_rev_file(TRUE) if $self->vcs eq 'git';

   $self->_svn_ignore_meta_files if $self->vcs eq 'svn';

   return $r;
};

around 'release_distribution' => sub {
   my ($orig, $self) = @_;

   if ($self->cmd_line_flags->{test}) {
      $self->_wrap('build_distribution');
      $self->_wrap('test_upload', $self->dist_version);
   }

   return $orig->($self);
};

around 'release_distribution' => sub {
   my ($orig, $self) = @_;

   my $res = $orig->($self);

   if ($self->cmd_line_flags->{upload}) {
      $self->_wrap('build_distribution');
      $self->_wrap('cpan_upload');
      $self->_wrap('clean_distribution');
   }

   return $res;
};

around 'release_distribution' => sub {
   my ($orig, $self) = @_;

   my $res = $orig->($self);

   $self->_push_to_remote unless $self->cmd_line_flags->{nopush};

   return $res;
};

around 'substitute_version' => sub {
   my ($next, $self, $path, @args) = @_;

   my $r = $self->$next($path, @args);

   $self->_reset_rev_keyword($path) if $self->vcs eq 'git';

   return $r;
};

around 'update_version_pre_hook' => sub {
   my ($next, $self, @args) = @_;

   return $self->$next($self->_get_version_numbers(@args));
};

around 'update_version_post_hook' => sub {
   my ($next, $self, @args) = @_;

   $self->_set__new_version($args[1]);
   $self->clear_dist_version;
   $self->clear_module_metadata;

   my $result = $self->$next(@args);

   $self->_reset_rev_file(FALSE) if $self->vcs eq 'git';

   return $result;
};

# Public methods
sub add_hooks : method {
   my $self = shift;

   $self->_add_git_hooks(@{$self->config->hooks}) if $self->vcs eq 'git';

   return OK;
}

sub add_to_vcs {
   my ($self, $target, $type) = @_;

   throw Unspecified, ['VCS target'] unless $target;

   $self->_add_to_git($target, $type) if $self->vcs eq 'git';
   $self->_add_to_svn($target, $type) if $self->vcs eq 'svn';
   return;
}

sub get_emacs_state_file_path {
   my ($self, $file) = @_;

   my $home = $self->config->my_home;

   return $home->catfile('.emacs.d', 'config', "state.${file}");
}

sub release : method {
   my $self = shift;

   $self->release_distribution;
   return OK;
}

sub release_distribution {
   my $self = shift;

   $self->update_version;
   $self->generate_metadata;
   $self->_commit_release($self->_new_version);
   $self->_add_tag($self->_new_version);
   return TRUE;
}

sub set_branch : method {
   my $self       = shift;
   my $bfile      = $self->branch_file;
   my $old_branch = $self->branch;
   my $new_branch = $self->next_argv // $self->default_branch;

   return OK if !$new_branch && $bfile->exists && $bfile->unlink;

   $bfile->println($new_branch) if $new_branch;

   my $method = 'get_'.$self->editor.'_state_file_path';

   return OK if $self->can($method);

   my $sfname = _get_state_file_name($self->project_file);
   my $sfpath = $self->$method($sfname);
   my $sep    = is_win32 ? "\\" : '/';

   $sfpath->substitute(
      "${sep}\Q${old_branch}\E${sep}", "${sep}${new_branch}${sep}"
   );

   return OK;
}

# Private methods
sub _add_git_hooks {
   my ($self, @hooks) = @_;

   for my $hook (grep { -e ".git${_}" } @hooks) {
      my $dest = $self->appldir->catfile('.git', 'hooks', $hook);

      $dest->unlink if $dest->exists;

      link ".git${hook}", $dest;
      chmod $self->exec_perms, ".git${hook}";
   }

   return;
}

sub _add_tag_to_git {
   my ($self, $tag) = @_;

   my $message = $self->config->tag_message;
   my $sign    = $self->config->signing_key;

   $sign = "-u ${sign}" if $sign;

   $self->run_cmd("git tag -d v${tag}", { err => 'null', expected_rv => 1 });
   $self->run_cmd("git tag ${sign} -m '${message}' v${tag}");
   return;
}

sub _add_to_git {
   my ($self, $target, $type) = @_;

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd("git add ${target}", $params);
   return;
}

sub _add_to_svn {
   my ($self, $target, $type) = @_;

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd("svn add ${target} --parents", $params);
   $self->run_cmd(
      "svn propset svn:keywords 'Id Revision Auth' ${target}", $params
   );
   $self->run_cmd("svn propset svn:executable '*' ${target}", $params)
      if $type and $type eq 'program';

   return;
}

sub _build_cmd_line_flags {
   my $self = shift;
   my $opts = {};

   for my $k (qw( release test upload nopush )) {
      $self->next_argv and $opts->{ $k } = TRUE
         if $self->extra_argv->[0] and $self->extra_argv->[0] eq $k;
   }

   return $opts;
}

sub _commit_release_to_git {
   my ($self, $msg) = @_;

   $self->run_cmd('git add .');
   $self->run_cmd("git commit -m '${msg}'");

   return;
}

sub _commit_release_to_svn {
   # TODO: Fill this in
}

sub _get_rev_file {
   my $self = shift;

   return if $self->no_auto_rev or $self->vcs ne 'git';

   return $self->appldir->parent->catfile(lc '.'.$self->distname.'.rev');
}

sub _get_svn_repository {
   my $self = shift;
   my $info = $self->run_cmd('svn info')->stdout;

   return (split m{ : \s }mx, (grep { m{ \A Repository \s Root: }mx }
                               split  m{ \n }mx, $info)[0])[1];
}

sub _get_version_numbers {
   my ($self, @args) = @_;

   return @args if $args[0] and $args[1];

   my $prompt = '+Enter major/minor 0 or 1';
   my $comp = $self->get_line($prompt, 1, TRUE, 0);

   $prompt = '+Enter increment/decrement';

   my $bump = $self->get_line($prompt, 1, TRUE, 0) or return @args;

   my ($from, $ver);

   if ($from = $args[0]) { $ver = Perl::Version->new($from) }
   else {
      return @args unless $ver = $self->dist_version;

      $from = _tag_from_version($ver);
   }

   $ver->component($comp, $ver->component($comp) + $bump);

   $ver->component(1, 0) if $comp == 0;

   return ($from, _tag_from_version($ver));
}

sub _initialize_svn {
   my $self  = shift;
   my $class = blessed $self;

   $self->chdir($self->appbase);

   my $repository = $self->appbase->catdir($self->repository);

   $self->run_cmd("svnadmin create ${repository}");

   my $branch = $self->branch;
   my $url    = 'file://'.$repository->catdir( $branch );
   my $msg    = "Initialised by ${class}";

   $self->run_cmd("svn import ${branch} ${url} -m '${msg}'");

   my $appldir = $self->appldir;

   $appldir->rmtree;
   $self->run_cmd("svn co ${url}");
   $appldir->filter(sub { $_ !~ m{ \.git }msx and $_ !~ m{ \.svn }msx });

   for my $target ($appldir->deep->all_files) {
      $self->run_cmd( "svn propset svn:keywords 'Id Revision Auth' ${target}" );
   }

   $msg = 'Add RCS keywords to project files';
   $self->run_cmd("svn commit ${branch} -m '${msg}'");
   $self->chdir($self->appldir);
   $self->run_cmd('svn update');
   return;
}

sub _push_to_git_remote {
   my $self = shift;
   my $info = $self->run_cmd('git remote -v')->stdout;

   return unless (grep { m{ \(push\) \z }mx } split m{ \n }mx, $info)[0];

   my $params = $self->quiet ? {} : { out => 'stdout' };

   $self->run_cmd('git push --all',  $params);
   $self->run_cmd('git push --tags', $params);
   return;
}

sub _push_to_remote {
   my $self = shift;

   $self->_push_to_git_remote if $self->vcs eq 'git';

   return;
}

sub _svn_ignore_meta_files {
   my $self = shift;

   $self->chdir($self->appldir);

   my $ignores = "LICENSE\nMANIFEST\nMETA.json\nMETA.yml\nREADME\nREADME.md";

   $self->run_cmd("svn propset svn:ignore '${ignores}' .");
   $self->run_cmd('svn commit -m "Ignoring meta files" .');
   $self->run_cmd('svn update');
   return;
}

sub _wrap {
   my ($self, $method, @args) = @_;

   return !$self->$method(@args);
}

sub _add_tag_to_svn {
   my ($self, $tag) = @_;

   my $params  = $self->quiet ? {} : { out => 'stdout' };
   my $repo    = $self->_get_svn_repository;
   my $from    = "${repo}/trunk";
   my $to      = "${repo}/tags/v${tag}";
   my $message = $self->config->tag_message ." v${tag}";
   my $cmd     = "svn copy --parents -m '${message}' ${from} ${to}";

   $self->run_cmd($cmd, $params);
   return;
}

sub _commit_release {
   my ($self, $tag) = @_;

   my $msg = $self->config->tag_message." v${tag}";

   $self->_commit_release_to_git($msg) if $self->vcs eq 'git';
   $self->_commit_release_to_svn($msg) if $self->vcs eq 'svn';
   return;
}

sub _initialize_git {
   my $self  = shift;
   my $class = blessed $self;
   my $msg   = "Initialised by ${class}";

   $self->chdir($self->appldir);
   $self->run_cmd('git init');
   $self->add_hooks;
   $self->_commit_release_to_git($msg);

  return;
}

sub _reset_rev_file {
   my ($self, $create) = @_;

   my $file = $self->_get_rev_file;

   $file->println($create ? '1' : '0') if $file && ($create || $file->exists);

   return;
}

sub _reset_rev_keyword {
   my ($self, $path) = @_;

   my $zero = 0; # Zero variable prevents unwanted Rev keyword expansion

   $path->substitute(
      '\$ (Rev (?:ision)?) (?:[:] \s+ (\d+) \s+)? \$', '$Rev: '.$zero.' $'
   ) if $self->_get_rev_file;

   return;
}

sub _add_tag {
   my ($self, $tag) = @_;

   throw Unspecified, [ 'VCS tag version' ] unless $tag;

   $self->output('Creating tagged release v[_1]', { args => [$tag] });

   $self->_add_tag_to_git($tag) if $self->vcs eq 'git';
   $self->_add_tag_to_svn($tag) if $self->vcs eq 'svn';

   return;
}

sub _initialize_vcs {
   my $self = shift;

   $self->output('Initialising VCS') if $self->vcs ne 'none';
   $self->_initialize_git if $self->vcs eq 'git';
   $self->_initialize_svn if $self->vcs eq 'svn';
   return;
}

# Private functions
sub _get_state_file_name {
   return (map  { m{ load-project-state \s+ [\'\"](.+)[\'\"] }mx; }
           grep { m{ eval: \s+ \( \s* load-project-state }mx }
           io($_[0])->getlines)[-1];
}

sub _tag_from_version {
   my $ver = shift;

   return $ver->component(0).'.'.$ver->component(1);
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

Module::Provision::TraitFor::VCS - Version Control

=head1 Synopsis

   use Module::Provision::TraitFor::VCS;
   # Brief but working code examples

=head1 Description

Interface to Version Control Systems

=head1 Configuration and Environment

Modifies
L<Module::Provision::TraitFor::CreatingDistributions/dist_post_hook>
where it initialises the VCS, ignore meta files and resets the
revision number file

Modifies
L<Module::Provision::TraitFor::UpdatingContent/substitute_version>
where it resets the Revision keyword values

Modifies
L<Module::Provision::TraitFor::UpdatingContent/update_version_pre_hook>
where it prompts for version numbers and creates tagged releases

Modifies
L<Module::Provision::TraitFor::UpdatingContent/update_version_post_hook>
where it resets the revision number file

Requires these attributes to be defined in the consuming class;
C<appldir>, C<distname>, C<vcs>

Defines the following command line options;

=over 3

=item C<no_auto_rev>

Do not turn on automatic Revision keyword expansion. Defaults to C<FALSE>

=back

=head1 Subroutines/Methods

=head2 add_hooks - Adds and re-adds any hooks used in the VCS

   $exit_code = $self->add_hooks;

Returns the exit code

=head2 add_to_vcs

   $self->add_to_vcs( $target, $type );

Add the target file to the VCS

=head2 get_emacs_state_file_path

   $io_object = $self->get_emacs_state_file_path( $file_name );

Returns the L<File::DataClass::IO> object for the path to the Emacs editor's
state file

=head2 release - Update version, commit and tag

   $exit_code = $self->release;

Calls L</release_distribution>. Will optionally install the distribution
on a test server, upload the distribution to CPAN and push the repository
to the origin

=head2 release_distribution

Updates the distribution version, regenerates the metadata, commits the change
and tags the new release

=head2 set_branch - Set the VCS branch name

   $exit_code = $self->set_branch;

Sets the current branch to the value supplied on the command line

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd>

=item L<Moose::Role>

=item L<Perl::Version>

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
