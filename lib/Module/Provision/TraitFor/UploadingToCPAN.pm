# @(#)Ident: UploadingToCPAN.pm 2013-05-12 16:07 pjf ;

package Module::Provision::TraitFor::UploadingToCPAN;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);

# Public methods
sub cpan_upload : method {
   my $self = shift;
   my $file = shift @{ $self->extra_argv }
           || $self->distname.'-v'.$self->dist_version.'.tar.gz';

   -f $file or throw error => 'File [_1] not found', args => [ $file ];

   my $args = $self->_read_pauserc; $args->{subdir} = lc $self->distname;

   $self->ensure_class_loaded( 'CPAN::Uploader' );

   exists $args->{dry_run} or $args->{dry_run}
      = not $self->yorn( 'Really upload to CPAN', FALSE, TRUE, 0 );

   CPAN::Uploader->upload_file( $file, $args );
   return OK;
}

# Private methods
sub _read_pauserc {
   my $self = shift; my $dir = $self->config->my_home; my $attr = {};

   for ($self->io( [ $dir, q(.pause) ] )->chomp->getlines) {
      ($_ and $_ !~ m{ \A \s* \# }mx) or next;
      my ($k, $v) = m{ \A \s* (\w+) \s+ (.+) \z }mx;
      exists $attr->{ $k } and throw "Multiple enties for ${k}";
      $attr->{ $k } = $v;
   }

   return $attr;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::UploadingToCPAN - Uploads distributions to CPAN

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::UploadingToCPAN';

=head1 Version

This documents version v0.15.$Rev: 2 $ of
L<Module::Provision::TraitFor::UploadingToCPAN>

=head1 Description

Uploads distributions to CPAN

=head1 Configuration and Environment

Reads PAUSE account data from F<~/.pauserc>

Defines no attributes

=head1 Subroutines/Methods

=head2 cpan_upload

   $exit_code = $self->cpan_upload;

Uploads a distribution to CPAN

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<CPAN::Uploader>

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
