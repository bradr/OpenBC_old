package OpenBC::wiki;
use Moose;
use Redis;
use Time::Stamp -stamps => { dt_sep => ' ', date_sep => '.', us => 1 };

has 'db' => (is => 'ro', lazy_build => 1);

sub read {
    my $self = shift;
    my $file = shift;
    my $key = shift;
    my $out = "";

    if ($key) { $file = $file . ":" . $key;}

    if ($self->db->type($file) eq "string") {
        $out = $self->db->get($file);
    }
    elsif ($self->db->type($file) eq "list") {
        my $len = $self->db->llen($file);
        for (my $i=0;$i<$len;$i++) {
            my $val = $self->db->lpop($file);
            $self->db->rpush($file,$val);
            $out = $out.$val."\n";
        }
    }
    elsif ($self->db->type($file) eq "hash" && $key) {
        # if ($self->db->hexists($file,$key)) {
            $out = $self->db->hget($file,$key);
            #}
    }
    return $out;
}

sub readTOC {
    my $self = shift;
    my $file = shift;
    my $out = "";
    
   if ($self->db->type($file) eq "hash") {
       #if ($self->db->hexists($file,"toc")) {
            $out = $self->db->hget($file,"toc");
            #} else {
            #$out = $self->db->hget($file,"basecode");
            #}
    }
    return $out;
}

sub readContent {
    my $self = shift;
    my $file = shift;
    my $out = "";
    
   if ($self->db->type($file) eq "hash") {
        if ($self->db->hexists($file,"contents")) {
            $out = $self->db->hget($file,"contents");
        } else {
            $out = $self->db->hget($file,"basecode");
        }
    }
    return $out;
}

sub writeTOC {
    my $self = shift;
    my $key = shift;
    my $value = shift;

    if (!$key) {die "Key undef trying to write ".$value;}
    if (!$value) {die "Value undef. Trying to save to ".$key;}
    if ($self->db->type($key) ne "hash") { return; }

    if ($self->db->hget($key,"toc")) {
        my $backup = $self->db->hget($key,"toc");
        my $backupkey = $key.":toc_".localstamp();
        $self->db->set( $backupkey => $backup );
        $self->db->lpush($key.":toc:backup",$backupkey );
    }
    $self->db->hset( $key, "toc", $value );
    return;
}

sub writeContent {
    my $self = shift;
    my $key = shift;
    my $value = shift;

    if (!$key) {die "Key undef trying to write ".$value;}
    if (!$value) {die "Value undef. Trying to save to ".$key;}
    if ($self->db->type($key) ne "hash") { return; }

    if ($self->db->hget($key,"content")) {
        my $backup = $self->db->hget($key,"content");
        my $backupkey = $key.":content_".localstamp();
        $self->db->set( $backupkey => $backup );
        $self->db->lpush($key.":content:backup",$backupkey );
    }
    $self->db->hset( $key, "content", $value );
    return;
}
sub write {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    my $field = shift;

    if ($field) { my $fieldtemp = $value; $value = $field; $field = $fieldtemp; }

    if (!$key) {die "Key undef trying to write ".$value;}
    if (!$value) {die "Value undef. Trying to save to ".$key;}
    if ($key) { #$self->db->type($key) eq "string") {
        if ($field) { $key = $key . ":" . $field; }
        if ($self->db->get($key)) {
            my $backup = $self->db->get($key);
            my $backupkey = $key."_".localstamp();
            $self->db->set( $backupkey => $backup );
            $self->db->lpush($key.":backup",$backupkey );
        }
        $self->db->set( $key => $value );
    } elsif ($self->db->type($key) eq "hash" && $field) {
        if (0){#$self->db->hexists($key, $field)) {
            my $backup = $self->db->hget($key, $field);
            my $backupkey = $key.":".$field . localstamp();
            $self->db->set($backupkey=>$backup);
            $self->db->lpush($key.":".$field,$backupkey);
        }
        $self->db->hset($key, $field, $value);
    }
    return;
}

sub listrevisions {
    my $self = shift;
    my $key = shift;
    my $num = shift;
    my $len = $self->db->llen($key.":backup");
    if (!$num) { $num = $len; }
    my $out = "<ul>";
    for (my $i=0; $i<$len; $i++) {
        my $code = $self->db->lpop($key.":backup");
        if ($i < $num) { $out = $out."<li><a href=\"../view/".$code."\">".$code."</a></li>"; }
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
#    if (!$self->db->exists($file . ":title")) {
        $self->db->lpush('codelist',$file );
#    }
}

sub addChapter {
    my $self = shift;
    my $file = shift;
    my $num = shift;

    if (!$file) { die "Undefined File Variable"; }
    if (!$num) { die "Undefined chapter numner"; }
    $self->db->rpush($file.":ch", $file.":ch".$num);
}

sub delete {
    my $self = shift;
    my $file = shift;
    $self->db->lrem('codelist',0,$file);
    $self->db->del($file);
    $self->db->del($file . ":title");
    $self->db->del($file . ":txturl");
    $self->db->del($file . ":pdfurl");
    $self->db->del($file . ":codetype");
    $self->db->del($file . ":location");
    $self->db->del($file . ":date");
}
sub _build_db { Redis->new }

1;
