package Raven::Events;
use Mojo::Base -base;
use Mojo::Log;

has 'client';
has loger => sub { Mojo::Log->new };

sub to_string {
    my ($self, $data) = @_;
    require Core::Error::PureVirtual;
    Core::Error::PureVirtual->throw();
}

sub capture {
    my ($self, $args) = @_;
    require Core::Error::PureVirtual;
    Core::Error::PureVirtual->throw();
}

1;
