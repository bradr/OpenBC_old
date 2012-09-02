#!perl
use lib '/var/www/openbc/lib';
#use Plack::Builder;
#use Plack::Response;
#use diagnostics;
use Dancer;
use OpenBC::Controller;

my $root = '/var/www/openbc';
my $log = '/var/log/openbc.log';
#builder {
#    enable "Plack::Middleware::AccessLog::Timed",
#            format => "%h %l %u %t \"%r\" %>s %b %D";
#    mount "/" => sub { OpenBC::Controller->new->run(@_) }
#};

dance;
