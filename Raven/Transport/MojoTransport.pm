package Raven::Transport::MojoTransport;
use Mojo::Base 'Raven::Transport';
use Mojo::UserAgent;
use Core::Error ':try';

use Data::Dumper;

has scheme => sub{['http', 'https']};
has ua => sub{Mojo::UserAgent->new()};

has 'parsed_url';
has debug => 1;

sub send {
    my ($self, $data, $headers) = @_;

    my $tx = $self->ua->post($self->parsed_url, $headers->to_hash, $data);

    if($tx->success){
        return $tx->res;
    }
    else {
        my $msg = "ua error: " . $tx->error;

        # TODO реализовать класс exception для 
        # ошибок сети() NetworkError
        Core::Error->throw(-context => $msg);
    }
}

sub compute_scope {
    my ($self, $url, $scope) = @_;

    $scope ||= {};

    my $netloc = $url->host;
    if($url->port){
        $netloc =  sprintf('%s:%s', $netloc, $url->port);
    }

    my ($path, $project);
    if(scalar @{$url->path->parts} > 1){
        
        my $clone_path = $url->path->clone();
        my $path_parts = $clone_path->parts;

        $project = pop @$path_parts;
        $clone_path->parts($path_parts);
        $path = "$clone_path";
    } 
    else {
        $path = '';
        $project = $url->path->parts->[-1];
    }

    my($username, $password)  = split(':', $url->userinfo);
    my $server = sprintf('%s://%s%s/api/store/', $url->scheme, $netloc, $path,);
    my $scope_extras = {
        'SENTRY_SERVERS' => [$server],
        'SENTRY_PROJECT' => $project,
        'SENTRY_PUBLIC_KEY' => $username,
        'SENTRY_SECRET_KEY' => $password,
    };
    
    # Merge hash
    %$scope = (%$scope_extras, %$scope);

    return $scope;
}

1;
