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
    unless ($team->has_access($self->session->{userid},$self->session->{token})) { $self->render_exception('Bad updates request: no access'); return; }

    my @types = qw/created chat spreadsheet url aha note/;
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
    unless ($team->has_access($self->session->{userid},$self->session->{token})) { $self->render_exception('Bad updates request: no access'); return; }
    $chat->add_of_type('chat',$text,$self->session->{userid});
    $self->render(text => 'OK', status => 200);
}

1;
