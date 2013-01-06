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
  my $access = 0;
  eval {
      $access = $team->has_access($self->session->{userid},$self->session->{token});
  };
  if ($@) {
      warn $@;
      return $self->redirect_to('reset');
  }
  return $self->redirect_to($self->url_for('event')) unless $access;

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
  $self->stash( tree => $event->get_puzzle_tree($self->app));
  $self->stash( current => undef);
}

sub all {
  my $self = shift;

  my $gs = $self->db->resultset('Team');
  my @teams;
  my $user = $self->db->resultset('User')->find($self->session->{userid});

  while (my $team = $gs->next) {
      my $has_access = 0;
      eval {
          warn join(" ","Trying access with", $self->session->{userid}, $self->session->{token}, "\n");
          $has_access = $team->has_access($self->session->{userid},$self->session->{token});
      };
      if ($@) {
          warn $@;
          return $self->redirect_to('reset');
      }
      next unless $has_access;
      push @teams, $team;
  }
  if (! @teams) {
      return $self->redirect_to($self->url_for('thanks'));
  }
  $self->stash(user => $user);
  $self->stash(teams => \@teams);
}

sub add {
    my $self = shift;
    my $team_id = $self->param('team-id');
    my $name = $self->param('event-name');
    my $team = $self->db->resultset('Team')->find($team_id);
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if ($name && $team && $user) {
        my $access = 0;
        eval {
            $access = $team->has_access($self->session->{userid},$self->session->{token});
        };
        if ($@) {
            warn $@;
            return $self->redirect_to('reset');
        }
        unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

        my $event = $team->find_or_create_related ('events', {
            display_name => $name,
        });
        $event->state('open');
        $self->stash(team => $team);
        $self->render('event/oneteam');
        SolveWith::Spreadsheet::trigger_folder($self, $event);
        return;
    }
    $self->render(text => 'There has been a problem.', status => 500);
}

sub refresh {
    my $self = shift;
    my $team_id = $self->param('team-id');
    my $team = $self->db->resultset('Team')->find($team_id);
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if ($team && $user) {
        my $access = 0;
        eval {
            $access = $team->has_access($self->session->{userid},$self->session->{token});
        };
        if ($@) {
            warn $@;
            return $self->redirect_to('reset');
        }
        unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

        $self->stash(team => $team);
        $self->render('event/oneteam');
        return;
    }
    $self->render(text => 'There has been a problem.', status => 500);
}

sub modal {
    my $self = shift;
    my $event_id = $self->param('eventid');
    my $round_id = $self->param('roundid');
    my $event;
    if ($event_id) {
        $event = $self->db->resultset('Event')->find($event_id);
    }
    if (!$event && $round_id) {
        my $round = $self->db->resultset('Round')->find($round_id);
        if ($round) {
            $event = $round->event;
        }
    }
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    my $form = $self->param('formname') || '';
    if ($event && $user && $form) {
        my $access = 0;
        eval {
            $access = $event->team->has_access($self->session->{userid},$self->session->{token});
        };
        if ($@) {
            warn $@;
            return $self->redirect_to('reset');
        }
        unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

        if ($form eq 'New Round' && $self->param('roundname') =~ /\S/) {
            my $round = $event->find_or_create_related ('rounds', {
                display_name => $self->param('roundname'),
                state => 'open',
            });
            $self->render(text => 'OK', status => 200);
            SolveWith::Spreadsheet::trigger_folder($self, $round);
            return;
        }
        if ($form eq 'New Puzzle' && $self->param('puzzlename') =~ /\S/) {
            my $round;
            if ($round_id == 0) {
                $round = $event->find_or_create_related ('rounds', {
                    display_name => '_catchall',
                    state => 'open',
                });
            } else {
                $round = $self->db->resultset('Round')->find($round_id);
            }
            if ($round && $round->event->id == $event_id) {
                my $puzzle = $self->db->resultset('Puzzle')->create({
                    display_name => $self->param('puzzlename'),
                    state => 'open',
                });
                if ($puzzle) {
                    $round->add_puzzle( $puzzle );
                    $self->render(text => 'OK', status => 200);
                    SolveWith::Spreadsheet::trigger_puzzle_spreadsheet($self, $puzzle);
                    return;
                }
            }
        }
        if ($form eq 'kill_round' && $round_id) {
            my $round = $self->db->resultset('Round')->find($round_id);
            if ($round) {
                $round->set_column('state','dead');
                $round->update;
              PUZ:
                for my $puzzle ($round->puzzles) {
                    next if ($puzzle->state eq 'dead');
                    for my $puzzle_round ($puzzle->rounds) {
                        if ($puzzle_round->state ne 'dead') {
                            next PUZ;
                        }
                    }
                    my $catchall = $event->find_or_create_related ('rounds', {
                        display_name => '_catchall',
                        state => 'open',
                    });
                    $catchall->add_to_puzzles($puzzle);
                }
                $self->render(text => 'OK', status => 200);
                return;
            }
        }
        if ($form eq 'revive_round' && $round_id) {
            my $round = $self->db->resultset('Round')->find($round_id);
            if ($round) {
                $round->set_column('state','open');
                $round->update;
                for my $puzzle ($round->puzzles) {
                    my $catchall = $event->find_or_create_related ('rounds', {
                        display_name => '_catchall',
                        state => 'open',
                    });
                    $catchall->remove_from_puzzles($puzzle);
                }
                $self->render(text => 'OK', status => 200);
                return;
            }
        }
        if ($form eq 'hide_closed') {
            $self->session->{hide_closed} = $self->param('hide_closed');
            $self->render(text => 'OK', status => 200);
            return;
        }
    }
    $self->render(text => 'There has been a problem.', status => 500);
}

sub status {
    my $self = shift;
    my $id = $self->param('id');
    my $puzzle_id = $self->param('puzzle_id');
    my $event = $self->db->resultset('Event')->find($id);
    my $team = $event->team if $event;
    warn "no team" unless $team;
    unless ($team) { $self->render_exception('Bad updates request: no team'); return; }
        my $access = 0;
    eval {
        $access = $team->has_access($self->session->{userid},$self->session->{token});
    };
    warn "no access" unless $access;
    unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

    my @results;
    my $open_puzzles_html = $self->render('puzzle/tree_ul',
                                          tree => $event->get_puzzle_tree($self->app),
                                          current_id => $puzzle_id, partial => 1);
    push @results, {type => 'tree_html', content => $open_puzzles_html };
    $self->render_json(\@results);
}

sub get_puzzle_table_html {
    my (undef, $self, $event) = @_;
    my $all_html;
    my $cache;
    eval { $cache = $self->app->cache; };
    $cache //= CHI->new( driver => 'Memory', global => 1 );
    return $cache->compute('puzzle_table '  . $event->id . ' all_html',
                                {expires_in => 5, busy_lock => 10},
                                sub {
                                    $self->stash(tree => $event->get_puzzle_tree($self->app));
                                    return $self->render('event/puzzle_table', partial=>1);
                                }
                            );
}

sub expire_puzzle_table_cache {
    my (undef, $self,$event_id) = @_;
    my $cache;
    eval { $cache = $self->app->cache; };
    $cache //= CHI->new( driver => 'Memory', global => 1 );
    $cache->expire('puzzle_table '  . $event_id . ' all_html');
}

1;
