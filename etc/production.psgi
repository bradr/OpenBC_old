use lib '/var/www/openbc/lib';
use Plack::Builder;
use Dancer ':syntax';
use OpenBC;

my $root = '/var/www/openbc';
my $log = '/var/log/openbc.log';
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
