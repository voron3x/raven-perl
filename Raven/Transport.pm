package Raven::Transport;
use Mojo::Base -base;
use Core::Error::PureVirtual;

sub check_scheme {
    Core::Error::PureVirtual->throw();
}

sub send {
    Core::Error::PureVirtual->throw();
}

sub compute_scope {
    Core::Error::PureVirtual->throw();
}

1;
