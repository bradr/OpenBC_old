package OpenBC::wiki;
use Moose;
use Redis;

has 'db' => (is => 'ro', lazy_build => 1);

sub read {
    my $self = shift;
    $self->db->get(shift);
}

sub write {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    $self->db->set( $key => $value );
    return;
}

sub list {


}

sub _build_db { Redis->new }

1;
