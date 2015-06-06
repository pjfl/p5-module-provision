package Module::Provision::MetaData;

use namespace::autoclean;

use File::DataClass::Types qw( Object );
use Module::Provision;
use Moo;

has 'provider' => is => 'ro', isa => Object,
   builder     => sub { Module::Provision->new },
   handles     => [ 'appldir', 'dist_version', 'libdir' ];

sub read_file { # PPI is just *so* slow
   my $self     = shift;
   my $pack_pat = qr{ \A package \s+ ([^\#]+) ; \z }mx;
   my $version  = $self->dist_version->normal;
   my $res      = {};

   for my $file ($self->libdir->deep->all_files) {
      for my $line (grep { m{ $pack_pat }mx } $file->chomp->getlines) {
         my ($package) = $line =~ m{ $pack_pat }mx;

         $package and $res->{ $package } = {
            file => $file->abs2rel( $self->appldir ), version => $version };
      }
   }

   return $res;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Module::Provision::MetaData - Provides module metadata

=head1 Synopsis

   use Module::Provision::MetaData;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines these attributes;

=over 3

=item C<provider>

An instance of L<Module::Provision>

=back

=head1 Subroutines/Methods

=head2 C<read_file>

Returns a hash reference of metadata

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Provision.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
# vim: expandtab shiftwidth=3:
