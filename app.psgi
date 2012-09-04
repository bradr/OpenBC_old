use Dancer;
use OpenBC;
use Plack::Builder;

my $app = sub {
        my $env = shift;
        my $request = Dancer::Request->new(env => $env);
        Dancer->dance($request);
};
 
builder {
    enable "Session::Cookie";
    enable "DoormanTwitter", root_url => 'http://openbuildingcodes.com:2080', scope => 'admin',
        consumer_key => "uo79K3wkTKIYC0HIHRfyAA",
        consumer_secret => "xRRqz4rddnfDYe63v7pCT2Gpan2cBDFvpu4ZwHJrxnM";
    $app;
};
