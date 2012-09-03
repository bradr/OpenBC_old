package OpenBC;
use Dancer;
 
get '/' => sub {
    return 'Hello World!!';
};

get '/view' => sub {
    template 'view', {};
};

get '/*' => sub {
    return 'Not Found';
};

start;
