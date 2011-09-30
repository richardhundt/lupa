package Point;

sub new { bless { } }

sub move {
    my ($self, $x, $y) = @_;
    $self->{x} = $x;
    $self->{y} = $y;
}

package Point3D;

use base q/Point/;

sub new {
    my ($class) = @_;
    return bless $class->SUPER::new(), $class;
}

sub move {
    my ($self, $x, $y, $z) = @_;
    $self->SUPER::move($x, $y);
    $self->{z} = $z;
}

package main;
my $p = Point3D->new;
for (1..10_000_000) {
    $p->move($_, $_ + 1, $_ + 2);
}

