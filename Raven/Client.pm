package Raven::Client;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::Log;
use Mojo::Cache;
use Mojo::Loader;
use Mojo::Headers;
use Mojo::JSON;
use Mojo::Util qw'md5_sum b64_encode';
use Data::UUID;
use DateTime;
use Core::Error ':try';

use Raven::Transport::MojoTransport;

has protocol_version => '2.0';
has client => 'raven-perl 1.0';
has loger => sub { Mojo::Log->new };
has [qw(dsn servers key public_key secret_key project processors)];

has name => sub {require Sys::Hostname; Sys::Hostname->hostname};
has include_paths => sub{ [] };
has exclude_paths => sub{ [] };
has timeout => sub{$ENV{SENTRY_TIMEOUT}};
has site => sub{$ENV{SENTRY_SITE} or 'default'};
has auto_log_stacks => 0;

has module_cache => sub{Mojo::Cache->new(max_keys => 50)};

# Client-side data processors to apply
# has processors => 'raven.processors.SanitizePasswordsProcessor';

sub new {
    my $self = shift->SUPER::new(@_);
        
    if($self->servers){
        if($self->dsn){
            require Core::Error::InvalidArgs;
            my $msg = "Incorect params to constructor";
            Core::Error::InvalidArgs->throw(-context => $msg);
        }

        $self->dsn($self->server);
        $self->server(undef);
    }

    if(!$self->dsn && exists $ENV{DSN} ){
        $self->loger->info('get dsn from env'); 
        $self->dsn($ENV{DSN});
    }

    if($self->dsn){
        my $url = Mojo::URL->new($self->dsn);

        my $msg = sprintf("Configuring Raven for host: %s://%s%s", 
            $url->scheme(), $url->authority(), $url->path());
        $self->loger->info($msg);

        my $ts = Raven::Transport::MojoTransport->new(parsed_url => $url); 
        my $options = $self->load($url, $ts);

        $self->servers($options->{'SENTRY_SERVERS'});
        $self->project($options->{'SENTRY_PROJECT'});
        $self->public_key($options->{'SENTRY_PUBLIC_KEY'});
        $self->secret_key($options->{'SENTRY_SECRET_KEY'});
    }

    return $self;
}


# Обрабатывает и сериализует сообщение в хеш
# Params:
# * event_type - Тип сообщения
# * data - 
# * date - Дата в формате UTC
# * time_spent
# * extra
# * stack - bool автоматический stacktrace всех сообщений.
# * public_key
# * culprit -
# * tags - доп. теги
sub build_msg {
    my ($self, $args) = @_;

    my $data = $args->{data} || {};
    my $extra = $args->{extra} || {};
    my $stack = $args->{stack} || $self->auto_log_stacks;

    # Date in UTC
    my $date = $args->{date} || DateTime->now->iso8601();

    my $event_id = Data::UUID->new()->create_hex();

    # TODO Вынести в отдельный метод
    my $loader = Mojo::Loader->new;
    my $module = 'Raven::Events::'.$args->{event_type};
    
    my $e = $loader->load($module);
    Core::Error->throw(-text => "Loading \"$module\" failed:") if ref $e;

    my $handler = $module->new;

    my $result = $handler->capture($args);

    # Merge result to data
    @{$data}{keys %$result} = values %$result;

    $data->{level} = 'error'
        unless defined $data->{level};

    $data->{server_name} = $self->name;
    $data->{tags} = $args->{tags};

    my $checksum_bits;
    unless(exists $data->{checksum}){
        $checksum_bits = $handler->get_hash($data);
    } else {
        $checksum_bits = $data->{checksum};
    }

    $data->{checksum} = md5_sum($checksum_bits);

    $data->{message} = $handler->to_string($data)
        unless exists $data->{message};

    $data->{timestamp} = $date;
    $data->{time_spent} = $args->{time_spent};
    $data->{event_id} = $event_id;
    $data->{project} = $self->project;
    $data->{site} = $self->site;

    return $data;
}

sub capture {
    my ($self, $args) = @_;
    my $data = $self->build_msg($args);
    $self->send($data);
    return [$data->{event_id}, $data->{checksum}];
}

sub send {
    my ($self, $data, $public_key, $auth_header) = @_;

    my $json = Mojo::JSON->new;

    my $message = $json->encode($data);
    Core::Error->throw(-text => "json error: $json->error")
        if $json->error;

    unless ($self->servers) {
        Core::Error->throw(-text => "No server configured");
        return;
    }

    my $header = [
        {'sentry_timestamp' => time()},
        {'sentry_client' => $self->client},
        {'sentry_version' => $self->protocol_version},
        {'sentry_key' => $public_key || $self->public_key},
    ];

    my $els;
    foreach (@$header){
        my ($k, $v) = each %{$_};
        push @$els, sprintf("%s=%s", $k, $v);
    }

    $auth_header = 'Sentry ' . join(',', @$els)
        unless $auth_header;

    foreach (@{$self->servers}){
        my $headers = Mojo::Headers->new;
        $headers->content_type('application/json');
        $headers->add('X-Sentry-Auth', $auth_header);


        my $url = Mojo::URL->new($_);

        my $ts = Raven::Transport::MojoTransport->new(parsed_url => $url); 
        
        my $res = $ts->send($message, $headers);
    }


    return;

}



# Парсит DSN и проставляет доп параметры
sub load {
    my ($self, $url, $transport, $scope) = @_;

    unless($scope){
        $scope = {};
    }

    my $scope_extras = $transport->compute_scope($url, $scope);

    # Merge hash
    %$scope = (%$scope_extras, %$scope);

    return $scope;
}

1;
