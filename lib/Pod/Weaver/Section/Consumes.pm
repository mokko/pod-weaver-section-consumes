package Pod::Weaver::Section::Consumes;
{
  $Pod::Weaver::Section::Consumes::VERSION = '0.0083';
}

# ABSTRACT: Add a list of roles to your POD.

use strict;
use warnings;
use Module::Load;
use Class::Unload;
use Moose;
with 'Pod::Weaver::Role::Section';

use aliased 'Pod::Elemental::Element::Nested';
use aliased 'Pod::Elemental::Element::Pod5::Command';

sub weave_section {
    my ( $self, $doc, $input ) = @_;

    my $filename = $input->{filename};

    #consumes section is written only for lib/*.pm and for one package pro file
    return if $filename !~ m{^lib};
    return if $filename !~ m{\.pm$};

    my $module = $filename;
    $module =~ s{^lib/}{};    #will there be a backslash on win32?
    $module =~ s{/}{::}g;
    $module =~ s{\.pm$}{};

    #print "module:$module\n";
    eval { local @INC = ( 'lib', @INC ); load $module }; 
    print "$@" if $@;

    return unless $module->can('meta');
    my @roles = sort
      grep { $_ ne $module } $self->_get_roles($module);
    #leave prestine environment for listdeps; 
    #I don't think that should be necessary, we sure loose time here.
    Class::Unload->unload( $module );
    return unless @roles;

    my @pod = (
        Command->new(
            {
                command => 'over',
                content => 4
            }
        ),

        (
            map {
                Command->new(
                    {
                        command => 'item',
                        content => "* L<$_>",
                    }
                  ),
            } @roles
        ),

        Command->new(
            {
                command => 'back',
                content => ''
            }
        )
    );

    push @{ $doc->children },
      Nested->new(
        {
            type     => 'command',
            command  => 'head1',
            content  => 'CONSUMES',
            children => \@pod
        }
      );

}

sub _get_roles {
    my ( $self, $module ) = @_;
    my @roles = map { $_->name } eval { $module->meta->calculate_all_roles };
    print "Possibly harmless: $@" if $@;

    #print "@roles\n";
    return @roles;
}

__PACKAGE__->meta->make_immutable;
1;


__END__
=pod

=head1 NAME

Pod::Weaver::Section::Consumes - Add a list of roles to your POD.

=head1 VERSION

version 0.0083

=head1 SYNOPSIS

In your C<weaver.ini>:

    [Consumes]

=head1 DESCRIPTION

This L<Pod::Weaver> section plugin creates a "CONSUMES" section in your POD
which will contain a list of all the roles consumed by your class. It accomplishes
this by attempting to compile your class and interrogating its metaclass object.

Classes which do not have a C<meta> method will be skipped.

=head1 AUTHOR

Mike Friedman <friedo@friedo.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Mike Friedman.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

