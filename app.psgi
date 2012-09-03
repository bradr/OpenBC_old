use lib 'lib';
use Plack::Builder;
use Dancer ':syntax';
use OpenBC;

my $root = './';
setting apphandler => 'PSGI';

my $app1 = sub {
    my $env = shift;
    setting appdir => $root;
    load_app "OpenBC";
    Dancer::App->set_running_app('OpenBC');
    Dancer::Config->load;
    my $request = Dancer::Request->new( env => $env );
    Dancer->dance($request);
};

builder {
    mount "/" => builder {$app1};
};
