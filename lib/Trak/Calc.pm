package Trak::Calc;

use v5.24;
use Carp;
use Moose;
use Try::Tiny;
use namespace::autoclean; # Clean up imported symbols after compilation

sub calculate {
    my ( $self, $formula ) = @_;
    die "Trak::Calc::calculate(): No formula provided!" unless $formula;
    return "Trak::Calc::calculate(): formula is '$formula'";
}

# TODO: _parse()

# Speed up object construction, but make classes immutable
__PACKAGE__->meta->make_immutable;
1;
