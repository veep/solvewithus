package SolveWith::Login;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub homepage {
  my $self = shift;

  return $self->redirect_to($self->url_for('event'));
}

sub welcome {
    my $self = shift;
}

sub thanks {
    my $self = shift;
}

1;
