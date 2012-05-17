package SolveWith::Puzzle;
use Mojo::Base 'Mojolicious::Controller';

sub single {
  my $self = shift;
  my $id = $self->stash('id');
  my $puzzle = $self->db->resultset('Puzzle')->find($id);
  return $self->redirect_to($self->url_for('event')) unless $puzzle;
  return $self->redirect_to($self->url_for('event')) unless $puzzle->rounds->first->event->team->has_access($self->session->{userid},$self->session->{token});
  my $event = $puzzle->rounds->first->event;
  $self->stash( current => $puzzle);
  $self->stash( event => $event);
  $self->stash( tree => $event->get_puzzle_tree());
}

1;
