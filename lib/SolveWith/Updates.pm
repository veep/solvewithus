package SolveWith::Updates;
use Mojo::Base 'Mojolicious::Controller';
use Encode qw/encode decode/;

sub getnew {
    my $self = shift;
    my $type = $self->stash('type');
    my $id = $self->stash('id');
    my $last_update = $self->stash('last') || 0;
    my ($item, $team);

    if ($type eq 'event') {
        $item = $self->db->resultset('Event')->find($id);
        $team = $item->team if $item;
    } elsif ($type eq 'puzzle') {
        $item = $self->db->resultset('Puzzle')->find($id);
        $team = $item->rounds->first->event->team if $item;
    }
    my $chat = $item->chat if $item;
    unless ($item) { $self->render_exception('Bad updates request: no item'); return; }
    unless ($chat) { $self->render_exception('Bad updates request: no chat'); return; }
    unless ($team) { $self->render_exception('Bad updates request: no team'); return; }
    my $access = 0;
    eval {
        $access = $team->has_access($self->session->{userid},$self->session->{token});
    };
    unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

    my @types = qw/created chat spreadsheet url aha note puzzle state solution/;
    my $messages_rs = $chat->search_related('messages',
#    my $messages_rs = $self->db->resultset('Message')->search(
                                            { type => \@types, 
                                              id => { '>', $last_update}
                                          },
                                            {order_by => 'id'});
    my @results;
    while (my $message = $messages_rs->next) {
        my $data = { map { ($_ => $message->$_)} qw/type id text timestamp/ };
        if (my $user = $message->user) {
            $data->{author} = $user->display_name;
        }
        $data->{text} = decode('UTF-8', $data->{text});
        push @results, $data;
    }
    $self->render_json(\@results);
}


sub event {
    my $self = shift;
    my $type = $self->stash('type');
    my $id = $self->stash('id');
    my $last_update = $self->stash('last') || 0;
    my ($item, $team, $chat, @results);

    $item = $self->db->resultset('Event')->find($id);
    unless ($item) { $self->render_exception('Bad updates request: no item'); return; }
    $chat = $item->chat;
    unless ($chat) { $self->render_exception('Bad updates request: no chat'); return; }
    $team = $item->team;
    unless ($team) { $self->render_exception('Bad updates request: no team'); return; }
    my $access = 0;
    eval {
        $access = $team->has_access($self->session->{userid},$self->session->{token});
    };
    unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

    # Two cursors, event->chat->message > last order by id
    #              event->(puzzles)->chat->message > last order by id
    # feed out the results of both cursors, intermingled in order by message id (i.e. chronological order)

    my $event_messages_rs = $chat->search_related('messages',
                                                  {
#                                                      type => \@types,
                                                      id => { '>', $last_update}
                                                  },
                                                  {order_by => 'id'});
    my $puzzle_messages_rs = $self->db->resultset('Message')->search(
        { 
            'me.id' => { '>', $last_update },
            'round_id.id' => $id,
        },
        {
            join => {
                'chat' => { 'puzzle' => { 'puzzle_rounds' => 'round_id' }}
            },
            order_by => 'me.id',
        }
    );
    
    my $pmessage = $puzzle_messages_rs->next;
    my $emessage = $event_messages_rs->next;
    while ($pmessage || $emessage) {
        my $data;
        if (!$emessage or ($pmessage and $pmessage->id < $emessage->id)) {
            $data = { map { ($_ => $pmessage->$_)} qw/type id text timestamp user/ };
            $data->{parent} = ['puzzle', $pmessage->chat->puzzle->id];
            $pmessage = $puzzle_messages_rs->next;
        } else {
            $data = { map { ($_ => $emessage->$_)} qw/type id text timestamp user/ };
            $data->{parent} = ['event',$id];
            $emessage = $event_messages_rs->next;
        }
        next unless $data;
        if (my $user = $data->{user}) {
            $data->{author} = $user->display_name;
        }
        delete $data->{user};
        $data->{text} = decode('UTF-8', $data->{text});
        push @results, $data;
    }
    $self->render_json(\@results);
}

sub chat {
    my $self = shift;
    my $type = $self->param('type');
    my $id = $self->param('id');
    my $text = $self->param('text');
    warn ("$type : $id : $text");
    my ($item, $team);

    if ($type eq 'event') {
        $item = $self->db->resultset('Event')->find($id);
        $team = $item->team if $item;
    } elsif ($type eq 'puzzle') {
        $item = $self->db->resultset('Puzzle')->find($id);
        $team = $item->rounds->first->event->team if $item;
    }
    my $chat = $item->chat if $item;
    unless ($item) { $self->render_exception('Bad updates request: no item'); return; }
    unless ($chat) { $self->render_exception('Bad updates request: no chat'); return; }
    unless ($team) { $self->render_exception('Bad updates request: no team'); return; }
    my $access = 0;
    eval {
        $access = $team->has_access($self->session->{userid},$self->session->{token});
    };
    unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

    $chat->add_of_type('chat',$text,$self->session->{userid});
    $self->render(text => 'OK', status => 200);
}
    
1;
