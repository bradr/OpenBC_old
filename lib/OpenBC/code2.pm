package OpenBC::code;
use Moose;
use Redis;
use YAML;
use LWP::Simple qw($ua get);

has 'db' => (is => 'ro', lazy_build => 1);

sub import {
    return;
}

1;
