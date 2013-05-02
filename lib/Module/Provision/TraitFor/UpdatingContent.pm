# @(#)Ident: UpdatingContent.pm 2013-05-02 02:59 pjf ;

package Module::Provision::TraitFor::UpdatingContent;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Moose::Role;
use Class::Usul::Constants;

requires qw(_appldir no_auto_rev vcs);

# Construction
after 'post_hook' => sub {
   $_[ 0 ]->_reset_rev_file( TRUE ); return;
};

# Public methods
sub update_copyright_year : method {
   my $self = shift; my ($from, $to) = $self->_get_update_args;

   my $prefix = 'Copyright (c)';

   $self->output( $self->loc( 'Updating copyright year' ) );

   for my $path (@{ $self->_get_manifest_paths }) {
      $path->substitute( "\Q${prefix} ${from}\E", "${prefix} ${to}" );
   }

   return OK;
}

sub update_version : method {
   my $self = shift; my ($from, $to) = $self->_get_update_args;

   # Zero variable prevents unwanted Rev keyword expansion
   my $ignore = $self->_get_ignore_rev_regex; my $zero = 0;

   $self->output( $self->loc( 'Updating version numbers' ) );

   for my $path (@{ $self->_get_manifest_paths }) {
      $ignore and $path =~ m{ (?: $ignore ) }mx and next;
      $path->substitute( "\Q\'${from}.%d\',\E", "\'${to}.%d\'," );
      $path->substitute( "\Q v${from}.\$Rev\E", " v${to}.\$Rev" );
      $self->_get_rev_file and $path->substitute
         ( '\$ (Rev (?:ision)?) (?:[:] \s+ (\d+) \s+)? \$',
           '$Rev: '.$zero.' $' );
   }

   $self->_reset_rev_file;
   return OK;
}

# Private methods
sub _get_ignore_rev_regex {
   my $self = shift;

   my $ignore_rev = $self->_appldir->catfile( '.gitignore-rev' )->chomp;

   return $ignore_rev->exists ? join '|', $ignore_rev->getlines : undef;
}

sub _get_manifest_paths {
   my $self = shift;

   return [ grep { $_->exists }
            map  { $self->io( __parse_manifest_line( $_ )->[ 0 ] ) }
            grep { not m{ \A \s* [\#] }mx }
            $self->_appldir->catfile( 'MANIFEST' )->chomp->getlines ];
}

sub _get_rev_file {
   my $self = shift; ($self->no_auto_rev or $self->vcs ne 'git') and return;

   return $self->_appldir->parent->catfile( lc '.'.$self->_distname.'.rev' );
}

sub _get_update_args {
   return (shift @{ $_[ 0 ]->extra_argv }, shift @{ $_[ 0 ]->extra_argv });
}

sub _reset_rev_file {
   my ($self, $create) = @_; my $file = $self->_get_rev_file;

   $file and ($create or $file->exists)
         and $file->println( $create ? '1' : '0' );
   return;
}

# Private functions
sub __parse_manifest_line { # Robbed from ExtUtils::Manifest
   my $line = shift; my ($file, $comment);

   # May contain spaces if enclosed in '' (in which case, \\ and \' are escapes)
   if (($file, $comment) = $line =~ m{ \A \' (\\[\\\']|.+)+ \' \s* (.*) }mx) {
      $file =~ s{ \\ ([\\\']) }{$1}gmx;
   }
   else {
       ($file, $comment) = $line =~ m{ \A (\S+) \s* (.*) }mx;
   }

   return [ $file, $comment ];
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Module::Provision::TraitFor::UpdatingContent - Perform search and replace on project file content

=head1 Synopsis

   use Moose;

   extends 'Module::Provision::Base';
   with    'Module::Provision::TraitFor::UpdatingContent';

=head1 Version

This documents version v0.9.$Rev: 2 $ of L<Module::Provision::TraitFor::UpdatingContent>

=head1 Description

Perform search and replace on project file content

=head1 Configuration and Environment

Requires the following attributes to be defined in the consuming
class; C<_appldir>, C<extra_argv>, C<loc>, C<no_auto_rev>, C<output>,
and C<vcs>

Defines no attributes

=head1 Subroutines/Methods

=head2 update_copyright_year

   module_provision update_copyright_year 2013 2014

Substitutes the existing copyright year for the new copyright year in all
files in the F<MANIFEST>

=head2 update_version

   module_provision update_version 0.1 0.2

Substitutes the existing version number for the new version number in all
files in the F<MANIFEST>

=head2 _reset_rev_file

Resets the revision keyword counter to zero

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
