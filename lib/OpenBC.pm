package OpenBC;
use Dancer;
use OpenBC::wiki;

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
    my $toc = $wiki->read($file.":toc");

    template 'view.tt', { file => $file, toc => $toc, content => $wiki->read($file) };
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
    $wiki->add($file);
    $wiki->write($file.':txturl', param "txturl");
    $wiki->write($file.':pdfurl', param "pdfurl");
    $wiki->write($file.':codetype', param "codetype");
    $wiki->write($file.':location', param "location");
    $wiki->write($file.':date', param "date");
#    $wiki->write($file.':codeid', param "codeid");
#    $wiki->write($file.':tocid', param "tocid");
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
    my $file = $wiki->read(params->{file});
    my $title = params->{file};
    my $txturl = $wiki->read(params->{file}.':txturl');
    my $pdfurl = $wiki->read(params->{file}.':pdfurl');
    my $codetype = $wiki->read(params->{file}.':codetype');
    my $location = $wiki->read(params->{file}.':location');
    my $date = $wiki->read(params->{file}.':date');
    my $tocid = $wiki->read(params->{file}.':tocid');
    my $codeid = $wiki->read(params->{file}.':codeid');

    my $revisions = $wiki->listrevisions( params->{file} );
    
    template 'edit.tt', { file => $file, title => $title, txturl => $txturl, pdfurl => $pdfurl, codetype => $codetype, location => $location, date => $date, tocid => $tocid, codeid => $codeid, revisions => $revisions };
};

post '/edit/:file' => sub {
    if ( session('user') ne "bradroger") { warn session('user'); redirect 'admin'; }
    my $wiki = OpenBC::wiki->new;
    $wiki->write(params->{file}, param "content");
    redirect '/edit/'.params->{file};
};

get '/*' => sub {
    return 'Not Found';
};

start;
