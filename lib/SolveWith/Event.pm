package SolveWith::Event;
use Mojo::Base 'Mojolicious::Controller';
use SolveWith::Auth;
use Net::Google::DocumentsList;
use Mojo::Util;

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
  # my @catchall_puzzles;
  # my %round_puzzles;
  # foreach my $round ($event->rounds->all) {
  #     if ($round->display_name eq '_catchall') {
  #         foreach my $puzzle ($round->puzzles) {
  #             push @catchall_puzzles, $puzzle;
  #         }
  #         next;
  #     }
  #     $round_puzzles{$round->id}{name} = $round->display_name;
  #     $round_puzzles{$round->id}{state} = $round->state;
  #     $round_puzzles{$round->id}{puzzles} = [$round->puzzles->all];
  # }
  # $self->stash(catchall => \@catchall_puzzles);
  # $self->stash(rounds => \%round_puzzles);
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

        if ($form eq 'New Round') {
            my $new_name = $self->param('RoundName');
            if ($new_name && $new_name =~ /\S/) {
                my $old_round = $event->find_related ('rounds', {
                    display_name => $new_name,
                });
                if (!$old_round) {
                    my $round = $event->find_or_create_related ('rounds', {
                        display_name => $new_name,
                    });
                    if ($round) {
                        $round->set_column('state','open');
                        $round->update;
                        $self->render(text => 'OK', status => 200);
                        SolveWith::Spreadsheet::trigger_folder($self, $round);
                        return;
                    }
                    $self->render(text => "Creating that round just didn't work.", status => 500);
                    return;
                } else {
                    if ($old_round->state eq 'dead') {
                        $self->render(text => 'That round exists and is marked &quot;Dead&quot;.', status => 500);
                    } else {
                        $self->render(text => "That round seems to exist already.", status => 500);
                    }
                    return;
                }
            }
            $self->render(text => "You didn't give a round name.", status => 500);
            return;
        }
        if ($form eq 'New Puzzle') {
            my $new_name = $self->param('PuzzleName');
            $new_name =~ s/^\s+//;
            $new_name =~ s/\s+$//;
            if (! ($new_name && $new_name =~ /\S/)) {
                $self->render(text => "You didn't give a puzzle name.", status => 500);
                return;
            }
            my $new_url = $self->param('PuzzleURL') || '';
            $new_url =~ s/^\s+//;
            $new_url =~ s/\s+$//;
            $new_url = $self->render("chat/chat-text", partial => 1, string => $new_url);
            chomp($new_url);
            my @round_ids = $self->param('round_ids');
            if (!@round_ids) {
                my $catchall = $event->find_or_create_related ('rounds', {
                    display_name => '_catchall',
                    state => 'open',
                });
                push @round_ids, $catchall->id;
            }
            my @rounds = map { $self->db->resultset('Round')->find($_) } @round_ids;
            for my $round (@rounds) {
                if ($round && $round->event->id == $event_id) {
                    for my $puzzle ($round->puzzles) {
                        if (lc($puzzle->display_name) eq lc($new_name)) {
                            my $round_name = Mojo::Util::html_escape($round->display_name);
                            if ($round_name eq '_catchall') {
                                $round_name = 'The top level';
                            } else {
                                $round_name = 'The round &quot;' . $round_name . '&quot;';
                            }
                            $self->render(text => $round_name .
                                          " already has a puzzle by that name.", status => 500);
                            return;
                        }
                    }
                } else {
                    $self->render(text => "Bad round data.", status => 500);
                    return;
                }

            }
            if ($new_url) {
                for my $round ($event->rounds) {
                    for my $puzzle ($round->puzzles) {
                        my $url_msg = $puzzle->chat->get_latest_of_type('puzzleurl');
                        my $puz_url = ($url_msg ? $url_msg->text : '');
                        if ($puz_url && $new_url eq $puz_url) {
                            $self->render(text => '&quot;' . Mojo::Util::html_escape($puzzle->display_name) . '&quot;' . 
                                          " already has that url.", status => 500);
                            return;
                        }
                    }
                }
            }
            my $puzzle = $self->db->resultset('Puzzle')->create({
                display_name => $new_name,
                state => 'open',
            });
            if ($puzzle) {
                for my $round (@rounds) {
                    $round->add_puzzle( $puzzle );
                }
                if ($new_url) {
                    $puzzle->chat->add_of_type('puzzleurl',$new_url,$self->session->{userid});
                }
                SolveWith::Spreadsheet::trigger_puzzle_spreadsheet($self, $puzzle);
                $self->render(text => 'OK', status => 200);
                return;
            }
            $self->render(text => "Puzzle creation failed.", status => 500);
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
        if ($form eq 'set_round_priority' && $round_id) {
            my $round = $self->db->resultset('Round')->find($round_id);
            if ($round) {
                my $priority = lc($self->param('priority'));
                $priority=~s/\s+//g;
                if ($priority) {
                    for my $puzzle ($round->puzzles) {
                        if ($puzzle->state eq 'open') {
                            $puzzle->priority($priority,$self->session->{userid});
                        }
                    }
                    $self->render(text => 'OK', status => 200);
                    return;
                }
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

sub get_form_round_list_html {
    my (undef, $self, $event) = @_;
    my $cache;
    eval { $cache = $self->app->cache; };
    $cache //= CHI->new( driver => 'Memory', global => 1 );
    return $cache->compute('form_round_list '  . $event->id . ' html',
                           {expires_in => 1, busy_lock => 10},
                           sub {
                               $self->stash(event => $event);
                               return $self->render('event/form_round_list', partial=>1);
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
