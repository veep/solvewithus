package SolveWith::Puzzle;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::DOM;
use Mojo::JSON;

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
  my @info = $puzzle->chat->search_related('messages',
                                           { type => 'puzzleinfo', },
                                           {order_by => 'id'});
  my $status_msg = $puzzle->chat->get_latest_of_type('state');
  my $state = 'open';
  if ($status_msg) {
      $state = $status_msg->text;
  }
  $self->stash( toggle_small => $self->session->{toggle_small});
  $self->stash( small_screen => ($self->session->{toggle_small} ? 'checked' : '') );
  $self->stash( current => $puzzle);
  $self->stash( event => $event);
  $self->stash( tree => $event->get_puzzle_tree());
  $self->stash( ss_url => $self->url_for('puzzle_ss', id => $id));
  $self->stash( state => $state );
  $self->stash( info => \@info );
}

sub modal {
    my $self = shift;
    my $form = $self->param('formname');
    my $id = $self->param('puzzleid');
    my $token = $self->param('token');
    my ($puzzle, $remove_id);
    my $json = Mojo::JSON->new();

    if ($token) {
        $puzzle = $self->db->resultset('Puzzle')->find_by_token($token);
    } elsif ($id) {
        $puzzle = $self->db->resultset('Puzzle')->find($id);
    }
    if ( $remove_id = $self->param('remove') ) {
        if ($remove_id) {
            my $message = $self->db->resultset('Message')->find($remove_id);
            my $puzzle_from_message;
            if ($message) {
                $puzzle_from_message = $message->chat->puzzle;
            }
            if ($puzzle && $puzzle_from_message && ($puzzle->id != $puzzle_from_message->id)) {
                return $self->render(text => 'There has been a problem.', status => 500);
            }
            if ($puzzle_from_message) {
                $puzzle = $puzzle_from_message;
            }
        }
    }
    if (!$puzzle) {
        return $self->render(text => 'There has been a problem.', status => 500);
    }
    my ($event,$team);
    if (! $token) {
        $event = $puzzle->rounds->first->event;
        $team = $event->team;
        my $access = 0;
        eval {
            $access = $team->has_access($self->session->{userid},$self->session->{token});
        };
        if ($@) {
            warn $@;
        }
        return $self->render(text => 'There has been a problem.', status => 500) unless $access;
    }

    if ($form and $form eq 'Puzzle Info') {
        my $url = $self->param('url');
        if (defined($url) && $url =~ /\S/) {
            my $url_encoded = $self->render("chat/chat-text", partial => 1, string => $url);
            my $old_url = $puzzle->chat->get_latest_of_type('puzzleurl');
            if (!defined($old_url) or $old_url->text ne $url_encoded) {
                $puzzle->chat->add_of_type('puzzleurl',$url_encoded,$self->session->{userid});
            }
        }
        my $summary = $self->param('summary');
        if (defined($summary) && $summary =~ /\S/) {
            my $summary_encoded = $self->render("chat/chat-text", partial => 1, string => $summary);
            my $old_summary = $puzzle->chat->get_latest_of_type('summary');
            if (!defined($old_summary) or $old_summary->text ne $summary_encoded) {
                $puzzle->chat->add_of_type('summary',$summary_encoded,$self->session->{userid});
            }
        }
        my $newinfo = $self->param('newinfo');
        if (defined($newinfo) and $newinfo =~ /\S/) {
            my $encoded = $self->render("chat/chat-text", partial => 1, string => $newinfo);
            $puzzle->chat->add_of_type('puzzleinfo',$encoded,$self->session->{userid});
        }
        my $newsolution = $self->param('newsolution');
        if (defined($newsolution) and $newsolution =~ /\S/) {
            $puzzle->chat->add_of_type('solution',$newsolution,$self->session->{userid});
            if ($event) {
                $event->chat->add_of_type('puzzle',join(
                    '','<B>Puzzle Solved: </B><a href="/puzzle/',
                    $puzzle->id,'">',Mojo::Util::html_escape($puzzle->display_name),'</a>',
                    ' Solution: ', Mojo::Util::html_escape($newsolution)
                ),$self->session->{userid});
            }
        }
        if (! $token) {
            my @round_ids = $self->param('puzzle-round');
            my @new_rounds = $self->db->resultset('Round')->search(
                {
                    id => [ -1, @round_ids ],
                    event_id => $event->id,
                } );
            if (! @new_rounds) {
                @new_rounds = $self->db->resultset('Round')->search(
                    {
                        display_name => '_catchall',
                        event_id => $event->id,
                    } );
            }
            $puzzle->set_rounds(\@new_rounds);
        }
        my $status_msg = $puzzle->chat->get_latest_of_type('state');
        my $newstate = $self->param('puzzle-status');
        my $oldstate = ($status_msg ? $status_msg->text : 'open');
        if ($newstate ne $oldstate  and $newstate =~ m/^(open|closed|dead)$/) {
            $puzzle->chat->add_of_type('state',$newstate,$self->session->{userid});
            $puzzle->set_column('state',$newstate);
            $puzzle->update;
        }
        if (! $token) {
            my $priority_msg = $puzzle->chat->get_latest_of_type('priority');
            my $newpriority = $self->param('puzzle-priority');
            my $oldpriority = ($priority_msg ? $priority_msg->text : 'normal');
            if ($newpriority ne $oldpriority  and $newpriority =~ m/^(normal|low|high)$/) {
                $puzzle->chat->add_of_type('priority',$newpriority,$self->session->{userid});
            }
            SolveWith::Event->expire_puzzle_table_cache($self, $event->id);
        }
        return $self->render(text => 'OK', status => 200);
    }
    if ($form and $form eq 'event_puzzle_priority') {
        my $pri = $self->param('priority');
        if ($pri) {
            my $rv = $puzzle->priority($pri, $self->session->{userid});
            if ($rv == 1) {
                my $round_name = '';
                my $round = $puzzle->rounds->first->display_name;
                if ($round ne '_catchall') {
                    $round_name = $round;
                }
                $event->chat->add_of_type('puzzlejson',
                                          $json->encode({ type => 'priority',
                                                          puzzle => Mojo::Util::html_escape($puzzle->display_name),
                                                          puzzleid => $puzzle->id,
                                                          round =>  Mojo::Util::html_escape($round_name),
                                                          text => Mojo::Util::html_escape($pri)}),
                                          ,$self->session->{userid},
                                      );
#                SolveWith::Event->expire_puzzle_table_cache($self, $event->id);
            }
            return $self->render(text => 'OK', status => 200);
        }
    }
    if ($form and $form eq 'revive_puzzle') {
        $puzzle->chat->add_of_type('state','open',$self->session->{userid});
        $puzzle->set_column('state', 'open');
        $puzzle->update;
        return $self->render(text => 'OK', status => 200);
    }
    if ($remove_id) {
        $puzzle->chat->remove_message($remove_id, $self->session->{userid});
        return $self->render(text => 'OK', status => 200);
    }
    return $self->render(text => 'There has been a problem.', status => 500);
}

sub spreadsheet_url {
    my $self = shift;
    my $id = $self->stash('id');
    my $puzzle = $self->db->resultset('Puzzle')->find($id);
    return $self->redirect_to('about:blank') unless $puzzle;
    my $access = 0;
    my $event;
    eval {
        $event = $puzzle->rounds->first->event;
        $access = $event->team->has_access($self->session->{userid},$self->session->{token});
    };
    if ($@ or not $access) {
        return $self->redirect_to('about:blank');
    }
    if ($puzzle->spreadsheet) {
        return $self->redirect_to($puzzle->spreadsheet);
    }
    $self->res->headers->add('Refresh', '2; url=' . $self->url_for('puzzle_ss', id => $id));
    $self->render('puzzle/waiting_for_spreadsheet');
}

sub spreadsheet_url_direct {
    my $self = shift;
    my $token = $self->stash('token');
    my $puzzle = $self->db->resultset('Puzzle')->find_by_token($token);
    return $self->redirect_to('about:blank') unless $puzzle;
    if ($puzzle->spreadsheet) {
        my $user = $self->db->resultset('User')->find($self->session->{userid});
        if ($user) {
            SolveWith::Spreadsheet::make_user_token_puzzle_editor($user, $puzzle->display_name, $token);
        }
        return $self->redirect_to($puzzle->spreadsheet);
    }
    $self->res->headers->add('Refresh', '2; url=' . $self->url_for('puzzle_ss_direct', token => $token));
    $self->render('puzzle/waiting_for_spreadsheet');
}

sub infomodal {
    my $self = shift;
    my $id = $self->stash('id');
    my $token = $self->stash('token');
    my $puzzle;
    my $event;
    if ($token) {
        $puzzle = $self->db->resultset('Puzzle')->find_by_token($token);
        if ($puzzle->id != $id) {
            undef $puzzle;
        }
    } else {
        $puzzle = $self->db->resultset('Puzzle')->find($id);
    }
    return $self->redirect_to('about:blank') unless $puzzle;
    if (! $token) {
        my $access = 0;
        eval {
            $event = $puzzle->rounds->first->event;
            $access = $event->team->has_access($self->session->{userid},$self->session->{token});
        };
        if ($@ or not $access) {
            return $self->redirect_to('about:blank');
        }
    }
    my $url;
    my $latest_url = $puzzle->chat->get_latest_of_type('puzzleurl');
    if ($latest_url) {
        my $url_html = $latest_url->text;
        my $dom = Mojo::DOM->new($url_html);
        $url = $dom->all_text;
    }
    my $latest_summary = $puzzle->chat->get_latest_of_type('summary');

    my @types = qw/solution puzzleinfo/;
    my $messages_rs = $puzzle->chat->search_related('messages',
                                            { type => \@types, },
                                            {order_by => 'id'});
    my $status_msg = $puzzle->chat->get_latest_of_type('state');
    my $priority_msg = $puzzle->chat->get_latest_of_type('priority');
    my (@rounds, @open_rounds);
    if (! $token) {
        @rounds  = $event->rounds->search(
            {
                state => ['open', 'closed'],
                display_name => { '!=', '_catchall'},
            },
            { order_by => 'id' },
        );
        @open_rounds  = $event->rounds->search(
            {
                state => ['open'],
                display_name => { '!=', '_catchall'},
            },
            { order_by => 'id' },
        );
    }
    $self->render('puzzle/info-modal', current => $puzzle,
                  url => $url,
                  latest_url => $latest_url,
                  latest_summary => $latest_summary,
                  status_msg => $status_msg,
                  priority_msg => $priority_msg,
                  messages => $messages_rs,
                  rounds => \@rounds,
                  open_rounds => \@open_rounds,
                  token => $token,
              );
}

sub testsolve_create {
    my $self = shift;
    my $title = $self->param('title');
    if (!defined($title)) {
        return $self->render(text => 'There has been a problem. Please include a title param', status => 500);
    }
    my $puzzle = $self->db->resultset('Puzzle')->create({
        display_name => $title,
        state => 'open',
    });
    my $token = `cat /proc/sys/kernel/random/uuid`;
    chomp $token;
    $puzzle->direct_token($token);
    return $self->render(text => $self->url_for(
        'puzzle_direct', token => $token)->to_abs->to_string, status => 200);
}

sub direct {
  my $self = shift;
  my $token = $self->stash('token');
  my $puzzle = $self->db->resultset('Puzzle')->find_by_token($token);
  return $self->redirect_to('events') unless $puzzle && $self->session->{userid};
  my $logged_in_row = $puzzle->find_or_create_related('puzzle_users',{user_id => $self->session->{userid}});
  $logged_in_row->timestamp(scalar time);
  $logged_in_row->update;
  my @info = $puzzle->chat->search_related('messages',
                                           { type => 'puzzleinfo', },
                                           {order_by => 'id'});
  my $status_msg = $puzzle->chat->get_latest_of_type('state');
  my $state = 'open';
  if ($status_msg) {
      $state = $status_msg->text;
  }
  $self->stash( toggle_small => $self->session->{toggle_small});
  $self->stash( small_screen => ($self->session->{toggle_small} ? 'checked' : '') );
  $self->stash( current => $puzzle);
  $self->stash( ss_url => $self->url_for('puzzle_ss_direct', token => $token));
  $self->stash( state => $state );
  $self->stash( info => \@info );
  $self->stash( token => $token);
}

1;
