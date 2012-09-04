package Raven::Events::Message;

use Mojo::Base 'Raven::Events';

sub to_string {
    my ($self, $data) = @_;

    my $msg = $data->{'sentry.interfaces.Message'};
    if (exists $msg->{params}){
        return sprintf($msg->{message}, @{$msg->{params}});
    }
    return $msg->{message};
}

sub get_hash {
    my ($self, $data) = @_;

    my $msg = $data->{'sentry.interfaces.Message'};
    return $msg->{message};
}

sub capture {
    my ($self, $args) = @_;
    return {
        'sentry.interfaces.Message' => {
            message => $args->{message},
            params => $args->{params}
        }
    }
}
1;
