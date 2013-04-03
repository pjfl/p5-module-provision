# @(#)Ident: perl_module.pm 2013-04-01 02:18 pjf ;

package [% module %];

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 31 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

[% module %] - <One-line description of module's purpose>

=head1 Synopsis

   use [% module %];
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 31 $ of L<[% module %]>

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

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

[% author %], C<< <[% author_email %]> >>

=head1 License and Copyright

Copyright (c) [% copyright_year %] [% copyright %]. All rights reserved

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