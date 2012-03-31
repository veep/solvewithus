package SolveWith::Event;
use Mojo::Base 'Mojolicious::Controller';

sub single {
  my $self = shift;
  my $id = $self->stash('id');
  $self->render(text => "Event # single $id" );
}

sub all {
  my $self = shift;
  $self->render(text => "Event # all");
}


1;
