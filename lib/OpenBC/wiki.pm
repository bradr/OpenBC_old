package OpenBC::wiki;
use Moose;
use Redis;
use WebService::Solr;
use Time::Stamp -stamps => { dt_sep => '_', date_sep => '.', us => 1 };

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
        $code =~ m/:[^_]*(.*)/;
        my $date = substr($1,1);
        if ($i < $num) {
            $out = $out."<li>$date<ul><li><a href=\"../view/".$code."\">View</a></li><li><a href=\"../edit/".$code."\">Edit</a></li></ul></li>"; 
        }
        $self->db->rpush($key.':backup',$code);
    }
    $out = $out."</ul>";
    return $out;
}

sub listchapters {
    my $self = shift;
    my $code = shift;
    my $len = $self->db->llen($code.":ch");
    my $out = "<ul>";
    for (my $i=0; $i<$len; $i++) {
        my $chapter = $self->db->lpop($code.":ch");
        $out = $out."<li><a href=\"edit/".$chapter."\">".$chapter."</a></li>";
        $self->db->rpush($code.":ch",$chapter);
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
        $out = $out."<li><a href=\"view/".$code."\">".$code."</a> <a class=\"btn btn-primary btn-mini\" href=\"edit/".$code.":content\">Edit</a><a href=\"edit/delete/" . $code . "\" class=\"btn btn-mini btn-danger\">Delete</a></li>";
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

    if (!$file) { die "Undefined File Variable"; }
    if ($file =~ m/(.+):ch/) {
        my $chapnum = $self->db->llen($1.":ch") + 1;
        $self->db->rpush($file, $file.":ch".$chapnum);
        return $file.":ch".$chapnum;
    }
    die "Can't add Chapter";
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

sub addToSolr {
    my $self = shift;
    my $file = shift;

    if ($file =~ m/:content$/) {
        $file = substr($file,0,-8);
    }
    
    my @fields = ( WebService::Solr::Field->new(contents => $self->db->get($file.":content")) );
    push(@fields,WebService::Solr::Field->new(id => "1") );
    push(@fields,WebService::Solr::Field->new(name => $self->db->get($file.":title")) );
    push(@fields,WebService::Solr::Field->new(codetype => $self->db->get($file.":codetype")) );

    my $doc = WebService::Solr::Document->new(@fields);

    my $solr = WebService::Solr->new("http://localhost:8888/solr");

    $solr->add($doc);

    $solr->commit;
}

sub search {
    my $self = shift;
    my $query = shift;

    my $solr = WebService::Solr->new("http://localhost:8888/solr");
    my $response = $solr->search( $query, {rows => 1000} );

    my @results;
    my $i = 0;
    for my $doc ($response->docs) {
        $results[$i]{'name'} = $doc->value_for( 'name' );
        $results[$i]{'content'} = $doc->value_for( 'contents' );
        $i++;
    }

    return \@results;
}


sub _build_db { Redis->new }

1;
