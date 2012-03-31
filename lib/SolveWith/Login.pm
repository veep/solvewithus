package SolveWith::Login;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub homepage {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render(text => 'homepage');
}

1;
