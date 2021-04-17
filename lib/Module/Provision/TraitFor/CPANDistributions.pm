package Module::Provision::TraitFor::CPANDistributions;

use namespace::autoclean;

use Class::Usul::Constants   qw( EXCEPTION_CLASS FALSE NUL OK TRUE );
use Class::Usul::Crypt::Util qw( decrypt_from_config encrypt_for_config
                                 is_encrypted );
use Class::Usul::Functions   qw( ensure_class_loaded throw );
use Class::Usul::Types       qw( NonEmptySimpleStr );
use English                  qw( -no_match_vars );
use HTTP::Request::Common    qw( POST );
use HTTP::Status;
use Scalar::Util             qw( blessed );
use Unexpected::Functions    qw( PathNotFound Unspecified );
use Moo::Role;

requires qw( add_leader config debug distname dist_version dumper
             info loc log next_argv output run_cmd yorn );

# Private attributes
has '_debug_http_method' =>
   is      => 'ro',
   isa     => NonEmptySimpleStr,
   builder => sub {
      return $ENV{CPAN_DELETE_FILES_DISPLAY_HTTP_BODY}
         ? 'as_string' : 'headers_as_string';
   };

# Public methods
sub cpan_upload : method {
   my ($self, $ver) = @_;

   $ver //= $self->next_argv;

   my $file = $self->_dist_path($ver);
   my $args = $self->_read_rc_file;

   $args->{subdir} //= lc $self->distname;

   my $prompt = $self->add_leader($self->loc('Really upload to CPAN'));

   $args->{dry_run} = !$self->yorn($prompt, FALSE, TRUE, 0)
      unless exists $args->{dry_run};

   ensure_class_loaded('CPAN::Uploader');

   CPAN::Uploader->upload_file($file, $args);
   return OK;
}

sub delete_cpan_files : method {
   my $self = shift;
   my $args = $self->_read_rc_file;

   $args->{subdir} //= lc $self->distname;

   my $files  = $self->_convert_versions_to_paths($self->extra_argv, $args);
   my $prompt = $self->loc('Really delete files from CPAN');

   $prompt = $self->add_leader($prompt);

   $args->{dry_run} = !$self->yorn($prompt, FALSE, TRUE, 0)
      unless exists $args->{dry_run};

   if ($args->{dry_run}) {
      $self->output('By request, cowardly refusing to do anything at all');
      $self->output("The following would have been used to delete files:\n");
      $self->dumper($args);
      $self->dumper($files);
   }
   else { $self->_delete_files($files, $args) }

   return OK;
}

sub set_cpan_password : method {
   my $self = shift;
   my $args = $self->_read_rc_file;

   throw Unspecified, ['password'] unless $args->{password} = $self->next_argv;

   $self->_write_rc_file($args);
   return OK;
}

sub test_upload : method {
   my ($self, $ver) = @_;

   $ver //= $self->next_argv;

   my $conf   = $self->config;
   my $id     = $conf->remote_test_id;
   my $script = $conf->remote_script;
   my $file   = $self->_dist_path($ver);
   my $args   = { in => 'stdin', out => 'stdout', };

   $self->run_cmd([ 'scp', $file, "${id}:/tmp" ]);
   $self->run_cmd([ 'ssh', '-t', $id, "${script} ${file}" ], $args);

   return OK;
}

# Private methods
sub _convert_versions_to_paths {
   my ($self, $versions, $args) = @_;

   $args //= {};

   my $paths    = [];
   my $distname = $self->distname;
   my $subdir   = $args->{subdir} ? $args->{subdir}.'/' : NUL;

   for my $version (@{$versions // []}) {
      for my $extn (qw(meta readme tar.gz)) {
         push @{$paths}, "${subdir}${distname}-${version}.${extn}";
      }
   }

   return $paths;
}

sub _delete_files {
   my ($self, $files, $args) = @_;

   my $target = $args->{target} || 'PAUSE';

   $self->info('Registering to delete files with the [_1] web server',
               { args => [$target]});

   ensure_class_loaded('LWP::UserAgent');

   my $agent = LWP::UserAgent->new;

   $agent->agent($self->_ua_string);
   $agent->env_proxy;
   $agent->proxy(http => $args->{http_proxy}) if $args->{http_proxy};

   my $uri     = $args->{delete_files_uri} // $self->config->delete_files_uri;
   my $request = $self->_get_delete_request($files, $args, $uri);

   $self->info('POSTing delete files request to [_1]', { args => [$uri]});
   $self->_throw_on_error($uri, $target, $agent->request($request));
   return;
}

sub _dist_path {
   my ($self, $ver) = @_;

   my $file;

   if ($ver) { $file = $self->distname."-${ver}.tar.gz" }
   else {
      $file = $self->distname.'-'.$self->dist_version.'.tar.gz';

      $file = $self->distname.'-v'.$self->dist_version.'.tar.gz'
         unless -f $file;
   }

   throw PathNotFound, [$file] unless -f $file;

   return $file
}

sub _get_delete_request {
   my ($self, $files, $args, $uri) = @_;

   my @body = ( HIDDENNAME => $args->{user},
                SUBMIT_pause99_delete_files_delete => 'Delete', );

   for my $file (@{$files}) {
      push @body, 'pause99_delete_files_FILE', $file;
   }

   my $request = POST($uri, \@body);

   $request->authorization_basic($args->{user}, $args->{password});
   $self->_log_http_debug('REQUEST', $request);
   return $request;
}

sub _log_http_debug {
   my ($self, $type, $obj, $msg) = @_;

   return unless $self->debug;

   my $method = $self->_debug_http_method;
   my @lines  = (
      $msg ? $msg : (),
      "----- ${type} BEGIN -----\n",
      $obj->$method()."\n",
      "----- ${type} END -------\n",
   );

   $self->log->debug($_) for (@lines);

   return;
}

sub _read_rc_file {
   my $self = shift;
   my $conf = $self->config;
   my $attr = {};

   for ($conf->my_home->catfile('.pause')->chomp->getlines) {
      next unless $_ and $_ !~ m{ \A \s* \# }mx;

      my ($k, $v) = m{ \A \s* (\w+) (?: \s+ (.+))? \z }mx;

      throw 'Multiple entries for [_1]', [$k] if exists $attr->{$k};

      $attr->{$k} = $v // NUL;
   }

   if (my $pword = $attr->{password}) {
      $attr->{password} = decrypt_from_config $conf, $pword
         if is_encrypted $pword;
   }

   return $attr;
}

sub _throw_on_error {
   my ($self, $uri, $target, $response) = @_;

   throw 'Request completely failed - we got undef back: [_1]', [$OS_ERROR]
      unless defined $response;

   if ($response->is_error) {
      my $class = blessed $self || $self;

      throw
         "PAUSE's CGI for handling messages seems to have moved!\n".
         "(HTTP response code of 404 from the [_1] web server)\n".
         "It used to be: [_2]\nPlease inform the maintainer of [_3]\n",
         [$target, $uri, $class] if $response->code == RC_NOT_FOUND;

      throw "Request failed error code [_1]\n  Message: [_2]\n",
            [$response->code, $response->message];
   }

   $self->_log_http_debug('RESPONSE', $response, 'Looks OK!');
   $self->info('[_1] delete request sent ok [[_2]]',
               { args => [$target, $response->code]});
   return;
}

sub _ua_string {
   my $self  = shift;
   my $class = blessed $self || $self;
   my $ver   = $class->VERSION // 'dev';

   return "${class}/${ver}";
}

sub _write_rc_file {
   my ($self, $attr) = @_;

   my $conf = $self->config;
   my $file = $conf->my_home->catfile('.pause');

   $attr->{password} = encrypt_for_config $conf, $attr->{password};

   $file->println("${_} ".$attr->{$_}) for (sort keys %{$attr});

   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::CPANDistributions - Uploads/Deletes distributions to/from CPAN

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::CPANDistributions';

=head1 Description

Uploads/Deletes distributions to/from CPAN

=head1 Configuration and Environment

Reads PAUSE account data from F<~/.pause>

Defines no attributes

=head1 Subroutines/Methods

=head2 cpan_upload - Uploads a distribution to CPAN

   $exit_code = $self->cpan_upload;

Uses L<CPAN::Uploader> to do the heavy lifting

=head2 delete_cpan_files - Deletes a distribution from CPAN

   $exit_code = $self->delete_cpan_files;

You must specify the version of the distribution to delete

=head2 test_upload - Upload and install distribution on the test server

   $exit_code = $self->test_upload;

Upload and install distribution on the test server

=head2 set_cpan_password - Set the PAUSE server password

   $exit_code = $self->set_cpan_password;

Sets the password used to connect to the PAUSE server. Once used the
command line program C<cpan-upload> will not work since it cannot
decrypt the password in the configuration file F<~/.pause>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<CPAN::Uploader>

=item L<HTTP::Message>

=item L<LWP::UserAgent>

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
