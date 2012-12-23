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
  $self->stash( ss_url => $self->url_for('puzzle_ss', id => $id));
}

sub modal {
    my $self = shift;
    my $form = $self->param('formname');
    my $action = $self->param('action');
    my $id = $self->param('puzzleid');
    my $puzzle = $self->db->resultset('Puzzle')->find($id);
    if (!$puzzle) {
        return $self->render(text => 'There has been a problem.', status => 500);
    }
    my $event = $puzzle->rounds->first->event;
    my $team = $event->team;
    my $access = 0;
    eval {
        $access = $team->has_access($self->session->{userid},$self->session->{token});
    };
    if ($@) {
        warn $@;
    }
    return $self->render(text => 'There has been a problem.', status => 500) unless $access;

    if ($form and $form eq 'Close Puzzle') {
        my $solution = $self->param('solution');
        my $has_solution = 0;
        if ($action eq 'Submit') {
            $has_solution = (defined($solution) &&  length($solution));
            if ($has_solution) {
                $puzzle->chat->add_of_type('solution',$solution,$self->session->{userid});
            }
        }
        if ($action eq 'Just Delete' or $action eq 'Submit') {
            $event->chat->add_of_type('puzzle',join(
                '','<B>Closed Puzzle: </B><a href="/puzzle/',
                $puzzle->id,'">',Mojo::Util::html_escape($puzzle->display_name),'</a>',
                ($has_solution ? ", Solution: " . Mojo::Util::html_escape($solution) : '')),0);
            $puzzle->chat->add_of_type('state','closed',$self->session->{userid});
            $puzzle->set_column('state','closed');
            $puzzle->update;
            return $self->render(text => 'OK', status => 200);
        }
    }
    if ($form and $form eq 'Puzzle Info') {
        my $url = $self->param('url');
        if (defined($url) && $url =~ /\S/) {
            my $url_encoded = $self->render("chat/chat-text", partial => 1, string => $url);
            warn "$url $url_encoded";
            my $old_url = $puzzle->chat->get_latest_of_type('puzzleurl');
            if (!defined($old_url) or $old_url ne $url_encoded) {
                $puzzle->chat->add_of_type('puzzleurl',$url_encoded,$self->session->{userid});
            }
        }
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
    $self->render(text => 'Hang on, Google Spreadsheets take time, like fine wine...');
}

1;
