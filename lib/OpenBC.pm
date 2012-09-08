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
    return 'Hello World!!';
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

    template 'view.tt', { file => $file, toc => $toc, content => $wiki->read($file,"content") };
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
        $out = $out."<br><br><br><div class='span4'><div class='well'><h1>Codes</h1>";
        $out = $out.$wiki->list;
        $out = $out."<br><a href='edit/new/' class='btn'>Add a new code</a></div></div>";
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
#    $wiki->write($file, 'codeid', param "codeid");
#    $wiki->write($file, 'tocid', param "tocid");
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
    my $content = $wiki->read($file,"content");
    my $toc = $wiki->read($file, "toc");
    my $title = $wiki->read($file,'title');
    my $txturl = $wiki->read($file,'txturl');
    my $pdfurl = $wiki->read($file,'pdfurl');
    my $codetype = $wiki->read($file, 'codetype');
    my $location = $wiki->read($file, 'location');
    my $date = $wiki->read($file,'date');
    my $tocid = $wiki->read($file,'tocid');
    my $codeid = $wiki->read($file, 'codeid');

    my $revisions = $wiki->listrevisions( params->{file},5 );
    
    template 'edit.tt', { content => $content, filename => $file, title => $title, txturl => $txturl, pdfurl => $pdfurl, codetype => $codetype, location => $location, date => $date, toc => $toc, codeid => $codeid, revisions => $revisions };
};

post '/edit/:file' => sub {
    if ( session('user') ne "bradroger") { warn session('user'); redirect 'admin'; }
    my $wiki = OpenBC::wiki->new;
    $wiki->write(params->{file}, "content", param "content");
    $wiki->write(params->{file}, "toc", param "toc");
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
