# @(#)Ident: DeletingFromCPAN.pm 2013-05-12 15:51 pjf ;

package Module::Provision::TraitFor::DeletingFromCPAN;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);
use English                qw(-no_match_vars);
use HTTP::Request::Common  qw(POST);
use HTTP::Status;
use LWP::UserAgent;
use MooseX::Types::Common::String qw(NonEmptySimpleStr);

# Private attributes
has '_debug_http_method' => is => 'ro', isa => NonEmptySimpleStr,
   builder               => '_build__debug_http_method', init_arg => undef,
   reader                => 'debug_http_method';

# Public methods
sub delete_cpan_files : method {
   my ($self, $files) = @_;

   my $args = $self->_read_pauserc; $args->{subdir} //= lc $self->distname;

   exists $args->{dry_run} or $args->{dry_run}
      = not $self->yorn( 'Really delete files from  CPAN', FALSE, TRUE, 0 );

   if ($args->{dry_run}) {
      $self->output( 'By request, cowardly refusing to do anything at all.' );
      $self->output
         ( "The following arguments would have been used to delete files: \n".
           '$self: '.$self->dumper( $self  ).
           '$file: '.$self->dumper( $files ) );
   }
   else { $self->_delete_files( $files, $args ) }

   return OK;
}

# Private methods
sub _build__debug_http_method {
   return $ENV{CPAN_DELETE_FILES_DISPLAY_HTTP_BODY}
        ? 'as_string' : 'headers_as_string';
}

sub _delete_files {
   my ($self, $files, $args) = @_; my $target = $args->{target} || 'PAUSE';

   $self->info( "Registering delete_files with ${target} web server" );

   my $agent   = LWP::UserAgent->new;

   $agent->agent( $self->_ua_string ); $agent->env_proxy;
   $args->{http_proxy} and $agent->proxy( http => $args->{http_proxy} );

   my $uri     = $args->{delete_files_uri} || $self->config->delete_files_uri;
   my $request = $self->_get_request( $files, $args, $uri );

   $self->log->info( "POSTing delete files request to ${uri}" );
   $self->_throw_on_error( $uri, $target, $agent->request( $request ) );
   return;
}

sub _get_request {
   my ($self, $files, $args, $uri) = @_;

   my $request = POST
      ( $uri,
        Content_Type => 'form-data',
        Content      => {
           HIDDENNAME                      => $args->{user},
           CAN_MULTIPART                   => 1,
           pause99_delete_files_uri        => "",
           pause99_delete_files_FILE       => $files,
           ($args->{subdir}                ?
          (pause99_delete_files_subdirtext => $args->{subdir}) : ()),
        }, );

   $request->authorization_basic( $args->{user}, $args->{password} );
   $self->_log_http_debug( 'REQUEST', $request );
   return $request;
}

sub _log_http_debug {
   my ($self, $type, $obj, $msg) = @_; $self->debug or return;

   my $method = $self->debug_http_method;

   $self->log->debug( $_ ) for ( $msg ? $msg : (),
                                 "----- ${type} BEGIN -----\n",
                                          $obj->$method()."\n",
                                 "----- ${type} END -------\n" );
   return;
}

sub _throw_on_error {
   my ($self, $uri, $target, $response) = @_;

   defined $response
      or throw "Request completely failed - we got undef back: ${OS_ERROR}";

   if ($response->is_error) {
      $response->code == RC_NOT_FOUND
         and throw "PAUSE's CGI for handling messages seems to have moved!\n".
                   "(HTTP response code of 404 from the ${target}".
                   " web server)\nIt used to be: ${uri}\n".
                   "Please inform the maintainer of ${self}.\n";

      throw "Request failed with error code ".$response->code.
            "\n  Message: ".$response->message."\n";
   }

   $self->_log_http_debug( 'RESPONSE', $response, 'Looks OK!' );
   $self->log->info( "${target} request sent ok [".$response->code."]" );
   return;
}

sub _ua_string {
  my $class = blessed $_[ 0 ] || $_[ 0 ]; my $ver = $class->VERSION // 'dev';

  return "${class}/${ver}";
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::DeletingFromCPAN - One-line description of the modules purpose

=head1 Synopsis

   use Module::Provision::TraitFor::DeletingFromCPAN;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 2 $ of L<Module::Provision::TraitFor::DeletingFromCPAN>

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head2 delete_cpan_files

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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
