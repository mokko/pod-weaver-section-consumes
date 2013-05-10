package Pod::Weaver::Section::Consumes;

# ABSTRACT: Add a list of roles to your POD.

use strict;
use warnings;

use Class::Inspector;
use Module::Load;
use Moose;
with 'Pod::Weaver::Role::Section';

use aliased 'Pod::Elemental::Element::Nested';
use aliased 'Pod::Elemental::Element::Pod5::Command';

sub weave_section {
    my ( $self, $doc, $input ) = @_;

    my $filename = $input->{filename};

    #consumes section is written only for lib/*.pm and for one package pro file
    #see Pod::Weaver::Section::ClassMopper for an alternative
    return if $filename !~ m{^lib};
    return if $filename !~ m{\.pm$};

    my $module = $filename;
    $module =~ s{^lib/}{};
    $module =~ s{/}{::}g;
    $module =~ s{\.pm$}{};

    #print "module:$module\n";
    if ( !Class::Inspector->loaded($module) ) {
        eval { local @INC = ( 'lib', @INC ); Module::Load::load $module };
        print "$@" if $@;    #warn
    }

    return unless $module->can('meta');
    my @roles = sort
      grep { $_ ne $module } $self->_get_roles($module);

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
no Moose;
1;

=pod

=head1 SYNOPSIS

In your C<weaver.ini>:

    [Consumes]

=head1 DESCRIPTION

This L<Pod::Weaver> section plugin creates a "CONSUMES" section in your POD
which will contain a list of all the roles consumed by your class. It accomplishes
this by attempting to compile your class and interrogating its metaclass object.

Classes which do not have a C<meta> method will be skipped.

It rewrites pod only for *.pm files in lib.

=head1 CAVEAT

=head2 dzil listdeps trouble?

When does this plugin run?

This plugin runs every time you run dzil (as far as I can see; it's probably 
part of the podweaver plugin so it runs in one of Dist::Zilla's phases). The
trouble is that it is always run when listdeps executed.

What does it do?

It loads (at runtime) all your packages (classes). To do so it needs all 
dependencies fulfilled. So basically, it requires that all dependencies 
have to be fulfilled to run already before you run listdeps. That defeats
the purpose.

A possible workaround is to move weaver.ini in place only after all 
requirements have been installed. The trouble is that Dist::Zilla can't do this
for you since basically listdeps and podweaver run in the same phase. 

Another alternative is to use authordep directive in your dist.ini and install
missing requirements as authordeps. That works ok, although it is not ideal
either.
