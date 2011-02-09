#!perl
use Plack::Builder;
use App::OpenBC::Controller;

my $root = '/var/www/openbc';
my $log = '/var/log/openbc.log';
builder {
    enable "Plack::Middleware::AccessLog::Timed",
            format => "%h %l %u %t \"%r\" %>s %b %D";

    mount "/" => sub {
        App::OpenBC::Controller->new(
            base_path => $root,
            log_file => $log,
        )->run(@_);
    }
};
