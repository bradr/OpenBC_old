package OpenBC;
use Dancer;
use OpenBC::wiki;
use OpenBC::code;

hook 'before' => sub {
    if (!session('user') && request->path_info =~ m{^/edit} && request->path_info =~ m{^/admin} && request->path_info ne '/admin/sign_out' && request->path_info ne 'admin/login') {
        request->path_info('/admin/login');
    }
};

hook 'before_template_render' => sub {
    my $tokens = shift;
    $tokens->{username} = session('user');
};

get '/' => sub {
    if (param "q" ) {
        my $query = param "q";
        my $wiki = OpenBC::wiki->new;
        my $results = $wiki->search($query);
        template 'search.tt', { query => $query, results => $results };
    } else {
        template 'index.tt', {};
    }
};

get '/view' => sub {
#    template 'view.tt', {};
    return 'View what?';
};

get '/view/:file' => sub {
    my $self = shift;
    my $wiki = OpenBC::wiki->new;
    my $file = params->{file};
    my $toc = $wiki->read($file,"toc");
    my $content = "";

    if ($file =~ m/([^:]*)(:ch\d+)?:(content$|toc$)/) {
        my $view = $1.$2;
        redirect '/view/' . $view;
    } else {
        $content = $wiki->read($file, "content");
    }
    template 'view.tt', { file => $file, toc => $toc, content => $content };
};

get '/admin/sign_out' => sub {
    session->destroy;
    redirect '/admin';
};

get '/admin/login' => sub {
    my $self = shift;
    my $env = request ->env();
    my $doorman = $env->{'doorman.admin.twitter'};
    my $content = "Please <a href=\"@{[ $doorman->sign_in_path ]}\">Login with Twitter</a>";
    template 'admin.tt', { content => $content };
};

get '/admin' => sub {
    my $self = shift;
    my $env = request->env(); 
    my $doorman = $env->{'doorman.admin.twitter'};
    my $wiki = OpenBC::wiki->new;
    my $out;

    # Check sign-in status, and provide sign-out link or sign-in link in the output.
    if ($doorman->is_sign_in) {
        $out = qq{Hi, @{[ $doorman->twitter_screen_name ]}, <a href="@{[ $doorman->sign_out_path ]}">Logout</a>};
        session user => $doorman->twitter_screen_name;
    }
    else {
        redirect '/admin/login';
    }
    if ( session('user') eq "bradroger") {
        $out = $out."<br><br><br><div class='span6'><div class='well'><h1>Codes</h1>";
        $out = $out.$wiki->list;
        $out = $out."<br><a href='edit/new/' class='btn'>Add a new code</a>  ";
        $out = $out."<a href=\"http://openbuildingcodes.com:8888/solr/update?stream.body=%3Cdelete%3E%3Cquery%3E*%3A*%3C%2Fquery%3E%3C%2Fdelete%3E&commit=true\" class='btn btn-danger'>Reset Search DB</a></div></div>";
    }
    template 'admin.tt', { content => $out, username => session('user') }; 
};

get '/admin/*' => sub {
    redirect '/admin';
};

get '/edit/new/' => sub {
    if ( session('user') ne "bradroger") { warn session('user'); redirect 'admin'; }
    template 'new.tt', {};
};

get '/edit/new/:file' => sub {
    if ( session('user') ne "bradroger") { warn session('user'); redirect 'admin'; }
    my $file = params->{file};
    if ($file =~ m/:ch/) {
        my $wiki = OpenBC::wiki->new;
        my $newchap = $wiki->addChapter($file);
        redirect '/edit/'.$newchap;
    }
    template 'new.tt', { file => params->{file} };
};

post '/edit/new/' => sub {
    my $wiki = OpenBC::wiki->new;
    my $file = param "codename";
    my $title = $file;
    $file =~ s/ /_/g;
    $wiki->write($file, 'title', $title);
    $wiki->add($file);
    $wiki->write($file, 'txturl', param "txturl");
    $wiki->write($file, 'pdfurl', param "pdfurl");
    $wiki->write($file, 'codetype', param "codetype");
    $wiki->write($file, 'location', param "location");
    $wiki->write($file, 'date', param "date");
    redirect '/edit/'. $file;
};

get '/edit/delete/:file' => sub {
    my $wiki = OpenBC::wiki->new;
    $wiki->delete(params->{file});
    redirect '/admin';
};

get '/edit/:file' => sub {
    if ( session('user') ne "bradroger") { warn session('user'); redirect 'admin'; }
    my $wiki = OpenBC::wiki->new;
    my $file = params->{file};
    my $basecode = $file;
    my $chapterNum = "";

    my $content="";
    if ($file =~ m/([^:]+):ch([\d]+):(content|toc)/) {
        $basecode = $1;
        $chapterNum = $2;
        $content = $wiki->read($file);
    } elsif ($file =~ m/([^:]+):ch([\d]+)/) {
        redirect '/edit/'.$file.":content";
    } elsif ($file =~ m/([^:]+)/) { 
#        redirect '/edit/' . $1 . ":ch1:content"; 
        $basecode = $1;
        $chapterNum = "0";
        $content = $wiki->read($1.":content");
    }


    my $toc = "";
    my $title = $wiki->read($basecode,'title');
    my $txturl = $wiki->read($basecode,'txturl');
    my $pdfurl = $wiki->read($basecode,'pdfurl');
    my $codetype = $wiki->read($basecode, 'codetype');
    my $location = $wiki->read($basecode, 'location');
    my $date = $wiki->read($basecode,'date');
    my $tocid = $wiki->read($basecode,'tocid');
    my $codeid = $wiki->read($basecode, 'codeid');

    my $revisions = $wiki->listrevisions($file, 5);
    my $chapters = $wiki->listchapters($file);

    template 'edit.tt', { content => $content, basecode => $basecode, filename => $file, chapterNum => $chapterNum, title => $title, txturl => $txturl, pdfurl => $pdfurl, codetype => $codetype, location => $location, date => $date, toc => $toc, codeid => $codeid, revisions => $revisions, chapters => $chapters};
};

post '/edit/:file' => sub {
    if ( session('user') ne "bradroger") { warn session('user'); redirect 'admin'; }
    my $wiki = OpenBC::wiki->new;
    my $file = params->{file};
    $wiki->write($file, param "content");

    #Add to Solr:
    $wiki->addToSolr($file);

    redirect '/edit/'.params->{file};
};

get '/edit/import/:file' => sub {
    my $wiki = OpenBC::wiki->new;
    my $file = params->{file};
    my $txturl = $file . ":txturl";
    my $url = $wiki->read($file, "txturl");
    OpenBC::code->importCode($file,$url);
    redirect '/edit/'.params->{file};
};

get '/*' => sub {
    return 'Not Found';
};

start;
