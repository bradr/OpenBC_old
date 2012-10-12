package OpenBC::wiki;
use Encode;
use Moose;
use Redis;
use WebService::Solr;
use JSON;
use JSON::Parse;
use HTML::Scrubber;
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

    $value = Encode::encode("utf8", $value);

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
    if ($code =~ m/([^:]*)/) {
        $code = $1;
    }
    my $len = $self->db->llen($code.":ch");
    my $out = "<ul>";
    for (my $i=0; $i<$len; $i++) {
        my $chapter = $self->db->lpop($code.":ch");
        $out = $out."<li><a href=\"../edit/".$chapter."\">".$chapter."</a></li>";
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
        $out = $out . $self->listchapters($code);
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
        $self->db->rpush($file, $file.$chapnum);
        return $file.$chapnum;
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
    my $solr = WebService::Solr->new("http://localhost:8888/solr");
    my $html = HTML::Scrubber->new();

    if ($file =~ m/([^:]*)(:ch[\d]+)?:content$/) {
        $file = $1 . $2;
        my $base = $1;

        my $id = "101.1";
        my $name = "";
        
        my $content = "";
        my @lines = split(/^/, $self->db->get($file.":content"));

        while (my $line = shift(@lines)) {
#            if ($line =~ /<div class="subsection" id="([\d\.]+)"><span class="title">([^<]*)/) {
            if ($line =~ /<p id="([\d\.]+)"><b>[\d\.]+ ([^\.]+)[^<]*<\/b>([^<]+)/) {
                my @fields = ( WebService::Solr::Field->new(contents => $html->scrub($content)) );
                push(@fields,WebService::Solr::Field->new(id => $id ));
                push(@fields,WebService::Solr::Field->new(name => $name ));
                push(@fields,WebService::Solr::Field->new(codename => $self->db->get($base.":title")) );
                push(@fields,WebService::Solr::Field->new(codeurl => $file) );
                my $doc = WebService::Solr::Document->new(@fields);

                $solr->add($doc);
                $content = $3;#$line;
                $id = $1;
                $name = $2;
            } else {
                $content = $content . $line;
            }
        }
#        $solr->commit;
    }
}

sub search {
    my $self = shift;
    my $query = shift;

    my $solr = WebService::Solr->new("http://localhost:8888/solr");
    my $response = $solr->search( $query, {rows => 1000, hl => 'on', 'hl.fl' => 'contents'} );

    my @results;
    my $i = 0;
    my $doc = $response->content;
    my $jsontext = JSON->new->encode($doc);
    my $perltext = JSON::Parse::json_to_perl($jsontext);
    my $num = $perltext->{response}->{numFound};
    while ($i<$num) {
        my $id = $perltext->{response}->{docs}[$i]->{id};
        my $html = HTML::Scrubber->new( allow => [ "em" ]);
        $results[$i]{hl} = $html->scrub($perltext->{highlighting}->{$id}->{contents}[0]); 
        $results[$i]{name} = $perltext->{response}->{docs}[$i]->{name}; 
        $results[$i]{id} = $perltext->{response}->{docs}[$i]->{id};
        $results[$i]{content} = $html->scrub($perltext->{response}->{docs}[$i]->{contents}[0]);
        $results[$i]{codename} = $perltext->{response}->{docs}[$i]->{codename};
        $results[$i]{codeurl} = $perltext->{response}->{docs}[$i]->{codeurl};

        $i++;
    }

    return \@results;
}


sub _build_db { Redis->new } 1;
