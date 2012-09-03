package OpenBC::Controller;
use Dancer;
 
get '/' => sub {
    return 'Hello World! Woop Woop!';
};

get '/view' => sub {
    return template 'view', {}, {layout => undef};
};

get '/*' => sub {
    return 'Not Found';
};

start;
