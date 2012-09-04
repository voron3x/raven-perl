use Mojo::Base -strict;

use Test::More;

use Mojolicious::Lite;
use Mojo::UserAgent;
use Mojo::URL;

use Data::Dumper;

use Raven::Transport::MojoTransport;

my $UDP_DSN  = 'udp://a209a9f99d3f4f7cac9fd002d3f40439:2a475333e73f4981a3c84e2e52d109f7@192.168.144.153:9001/3';
my $HTTP_DSN = 'http://a209a9f99d3f4f7cac9fd002d3f40439:2a475333e73f4981a3c84e2e52d109f7@192.168.144.153:9000/hhh/aaa/3';

# POST
post '/' => {json => {test => 'ok'}};
post '/test' => {json => {test => 'ok'}};

# GET
get '/' => {text => 'hello'};
{
    local $ENV{MOJO_USERAGENT_DEBUG};

    my $ua = Mojo::UserAgent->new();
    my $url = Mojo::URL->new($HTTP_DSN);
    my $tr = Raven::Transport::MojoTransport->new(parsed_url => $url);
    print Dumper($tr->compute_scope($url, {SENTRY_PROJECT => "hahaha"}));
    #say $tr->send('test', {Accept=>'haha/hohoh'})->json('/test');
    #say $ua->post($url)->res->body;
}



1;
