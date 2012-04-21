package SolveWith::Event;
use Mojo::Base 'Mojolicious::Controller';
use SolveWith::Auth;
use Net::Google::DocumentsList;

sub single {
  my $self = shift;
  my $id = $self->stash('id');
  my $event = $self->db->resultset('Event')->find($id);
  return $self->redirect_to($self->url_for('event')) unless $event;
  my $team = $event->team;
  return $self->redirect_to($self->url_for('event')) unless $team;
  return $self->redirect_to($self->url_for('event')) unless 
      $team->has_access($self->session->{userid},$self->session->{token});
  $self->stash(event => $event);
  my @catchall_puzzles;
  if (my $catchall = $event->rounds->search({display_name => '_catchall'})->first) {
      foreach my $puzzle ($catchall->puzzles) {
          push @catchall_puzzles, $puzzle;
      }
  }
  $self->stash(catchall => \@catchall_puzzles);
}

sub all {
  my $self = shift;

  my $gs = $self->db->resultset('Team');
  my @teams;
  my $user = $self->db->resultset('User')->find($self->session->{userid});

  while (my $team = $gs->next) {
      next unless $team->has_access($self->session->{userid},$self->session->{token});
      push @teams, $team;
  }
  $self->stash(teams => \@teams);

}


1;
