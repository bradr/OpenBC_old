package OpenBC;
use Dancer;
use OpenBC::wiki;

get '/' => sub {
    return 'Hello World!!';
};

get '/view' => sub {
    template 'view.tt', {};
};

get '/admin/sign_out' => sub {
    session user => '';
    session->destroy;
    return "Signed Out";
};

get '/admin/*' => sub {
    my $self = shift;
    my $env = request->env(); 
    my $doorman = $env->{'doorman.admin.twitter'};
    my $out;

    # Check sign-in status, and provide sign-out link or sign-in link in the output.
    if ($doorman->is_sign_in) {
        $out = qq{Hi, @{[ $doorman->twitter_screen_name ]}, <a href="@{[ $doorman->sign_out_path ]}">Logout</a>};
        session user => $doorman->twitter_screen_name;
    }
    else {
        $out = "<a href=\"@{[ $doorman->sign_in_path ]}\">Login</a>";
    }
    return $out;
};

get '/edit/:file' => sub {
    if ( session('user') ne "bradroger") { warn session('user'); redirect 'admin/start'; }
    my $wiki = OpenBC::wiki->new;
    my $string = $wiki->read(params->{file});
    template 'edit.tt', { file => $string };
};

post '/edit/:file' => sub {
    my $wiki = OpenBC::wiki->new;
    $wiki->write(params->{file}, param "content");
    redirect '/edit/'.params->{file};
};

get '/*' => sub {
    return 'Not Found';
};

start;
