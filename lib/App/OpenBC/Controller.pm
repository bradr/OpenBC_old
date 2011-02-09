package OpenBC::Controller;
use feature 'switch';
use Moose;
use Fatal qw/open/;
use Template;
use JSON qw/encode_json decode_json/;
use Plack::Request;
use Plack::Response;

has 'request'   => (is => 'rw', isa => 'Plack::Request');
has 'env'   => (is=> 'rw', isa => 'HashRef');

sub run {
    my $self = shift;
    my $env = shift;
    my $req = $self->request;

    my $path = $req->path;
    my %func_map = (
        GET => [
            [ qr{^/$}           => \&ui_html ], # Landing page
            [ qr{^/m/?$}        => \&ui_html ], # Mobile site
            [ qr{^/(.+)\.html$} => \&ui_html ], # Rendered pages
            [ qr{^/([\w-]+)$}   => \&ui_html ], # Same, but make the .html optional
        ]
    );

    my $method = $req->method;
    for my $match (@{ $func_map{$method}}) {
        my ($regex, $todo) = @$match;
        if ($path =~ $regex) {
            return $todo->($self, $req, $1, $2, $3, $4);
        }
    }

    return $self->redirect("/404.html");
}

sub is_mobile {
    my ($self, $req) = @_;
    my $headers = $req->headers;
    my $ua_str = $headers->{'user-agent'} || '';
    return $ua_str =~ m{Android|iPhone|BlackBerry}i ? 1 : 0;
}

sub default_page {
    my ($self, $req) = @_;
    return $self->is_mobile($req) ? 'm/index' : 'index';
}

sub ui_html {
    my ($self, $req, $tmpl) = @_;
    $tmpl ||= $self->default_page($req);
    my $params = $req->parameters;
    $params->{host_port} = $req->uri->host_port;
    $params->{twitter} = $self->config->{twitter_username};
    return $self->process_template("$tmpl.tt2", $params)->finalize;
}
