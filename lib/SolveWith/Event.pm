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
  my %round_puzzles;
  foreach my $round ($event->rounds->all) {
      if ($round->display_name eq '_catchall') {
          foreach my $puzzle ($round->puzzles) {
              push @catchall_puzzles, $puzzle;
          }
          next;
      }
      $round_puzzles{$round->id}{name} = $round->display_name;
      $round_puzzles{$round->id}{puzzles} = [$round->puzzles->all];
  }
  $self->stash(catchall => \@catchall_puzzles);
  $self->stash(rounds => \%round_puzzles);
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
  if (! @teams) {
      return $self->redirect_to($self->url_for('thanks'));
  }
  $self->stash(teams => \@teams);

}

sub add {
    my $self = shift;
    my $team_id = $self->param('team-id');
    my $name = $self->param('event-name');
    my $team = $self->db->resultset('Team')->find($team_id);
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if ($name && $team && $user && $team->has_access($self->session->{userid},$self->session->{token})) {
        my $event = $team->find_or_create_related ('events', {
            display_name => $name,
        });
        $event->state('open');
        $self->stash(team => $team);
        $self->render('event/oneteam');
        return;
    }
    $self->render(text => 'There has been a problem.', status => 500);
}

sub modal {
    my $self = shift;
    my $event_id = $self->param('eventid');
    my $event = $self->db->resultset('Event')->find($event_id);
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if ($event && $user && $event->team->has_access($self->session->{userid},$self->session->{token}) ) {
        if ($self->param('formname') eq 'New Round' && $self->param('roundname') =~ /\S/) {
            my $round = $event->find_or_create_related ('rounds', {
                display_name => $self->param('roundname'),
                state => 'open',
            });
            $self->render(text => 'OK', status => 200);
            return;
        }
        if ($self->param('formname') eq 'New Puzzle' && $self->param('puzzlename') =~ /\S/) {
            my $round;
            if ($self->param('roundid') == 0) {
                $round = $event->find_or_create_related ('rounds', {
                    display_name => '_catchall',
                    state => 'open',
                });
            } else {
                $round = $self->db->resultset('Round')->find($self->param('roundid'));
            }
            if ($round && $round->event->id == $event_id) {
                my $puzzle = $round->add_to_puzzles({
                    display_name => $self->param('puzzlename'),
                    state => 'open',
                });
                $self->render(text => 'OK', status => 200);
                return;
            }
        }
    }
    $self->render(text => 'There has been a problem.', status => 500);
}

1;
