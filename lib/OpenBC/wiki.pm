package OpenBC::wiki;
use Moose;
use Redis;
use Time::Stamp -stamps => { dt_sep => ' ', date_sep => '.', us => 1 };

has 'db' => (is => 'ro', lazy_build => 1);

sub read {
    my $self = shift;
    $self->db->get(shift);
}

sub write {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    if ($self->db->get($key)) {
        my $backup = $self->db->get($key);
        my $backupkey = $key."_".localstamp();
        $self->db->set( $backupkey => $backup );
        $self->db->lpush($key.":backup",$backupkey );
    }
    $self->db->set( $key => $value );
    return;
}

sub listrevisions {
    my $self = shift;
    my $key = shift;
    my $len = $self->db->llen($key.":backup");
    my $out = "<ul>";
    for (my $i=0; $i<$len; $i++) {
        my $code = $self->db->lpop($key.":backup");
        $out = $out."<li><a href=\"../view/".$code."\">".$code."</a></li>";
        $self->db->rpush($key.':backup',$code);
    }
    $out = $out."</ul>";
    return $out;
}

sub list {
    my $self = shift;
    my $len = $self->db->llen('codelist');
    my $out = "<ul>";
    for (my $i=0; $i<$len; $i++) {
        my $code = $self->db->lpop('codelist');
        $out = $out."<li><a href=\"view/".$code."\">".$code."</a> <a class=\"btn btn-primary btn-mini\" href=\"edit/".$code."\">Edit</a></span></li>";
        $self->db->rpush('codelist',$code);
    }
    $out = $out."</ul>";
    return $out;
}

sub add {
    my $self = shift;
    my $file = shift;
    $self->db->lpush('codelist',$file );
}

sub delete {
    my $self = shift;
    my $file = shift;
    $self->db->lrem('codelist',0,$file);
    $self->db->del($file);
}
sub _build_db { Redis->new }

1;
