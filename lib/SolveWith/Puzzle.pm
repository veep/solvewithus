package SolveWith::Puzzle;
use Mojo::Base 'Mojolicious::Controller';

sub single {
  my $self = shift;
  my $id = $self->stash('id');
  my $puzzle = $self->db->resultset('Puzzle')->find($id);
  return $self->redirect_to('events') unless $puzzle;
  my $access = 0;
  my $event;
  eval {
      $event = $puzzle->rounds->first->event;
      $access = $event->team->has_access($self->session->{userid},$self->session->{token});
  };
  if ($@) {
      return $self->redirect_to('reset');
  }
  return $self->redirect_to('events') unless $access;
  $self->stash( current => $puzzle);
  $self->stash( event => $event);
  $self->stash( tree => $event->get_puzzle_tree());
}

1;
