use Mojo::Base -strict;

use Test::More tests => 3;

use Mojo::URL;

use_ok('Raven::Client');

my $UDP_DSN  = 'udp://a209a9f99d3f4f7cac9fd002d3f40439:2a475333e73f4981a3c84e2e52d109f7@192.168.144.153:9001/3';
my $HTTP_DSN = 'http://a209a9f99d3f4f7cac9fd002d3f40439:2a475333e73f4981a3c84e2e52d109f7@192.168.144.153:9000/3';

my $data = {
    'sentry.interfaces.Http' => {
        'url' => 'http://squirrel.ru',
        'data' => 'test message in body',
        'headers' => {Connection => 'keep-alive', Pragma => 'no-cache'},
        'query_string' => '?foo=bar',
        'method' => 'POST',
        'cookies' => 'cook=1;cook2=hahaha',
        'env' => \%ENV,
    },
    'sentry.interfaces.Query' => {
        query => 'SELECT 1',
        engine => 'psycopg2'
    },
    'sentry.interfaces.User' => {
        is_authenticated => 'true',
        id => 'unique_id',
        username => 'foo',
        email => 'foo@example.com',
    },
    logger => 'logger.test',
    site => 'squirrel',
    level => 'fatal',
};

my $extra={
    'key' => 'value',
};


my $url = Mojo::URL->new($HTTP_DSN);
my $tr = Raven::Client->new(dsn => $HTTP_DSN, project => 'test raven');
is(
    ref $tr->build_msg({
        event_type => 'Message',
        message => 'Test message %s',
        params => ['for sentry'],
        }), 
    'HASH', 
    'build_msg return hash');

is(
    ref $tr->capture({
        event_type => 'Message',
        message => 'Hah',
        data => $data,
        extra => $extra,
        }),
    'ARRAY',
    'capture return array ref');


1;
