package SolveWith::Schema::Result::Chat;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('chat');
__PACKAGE__->add_columns(
    id => {
        accessor => 'chat',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(messages => 'SolveWith::Schema::Result::Message', 'chat_id');
__PACKAGE__->might_have( puzzle => 'SolveWith::Schema::Result::Puzzle', 'chat_id');
__PACKAGE__->might_have( event => 'SolveWith::Schema::Result::Event', 'chat_id');

sub insert {
    my $self = shift;
    my $chat = $self->next::method( @_ );
    $chat->create_related(
        messages => {
            type => 'created',
            text => 'Created on',
        }
    );
    return $chat;
}

sub get_latest_of_type {
    my ($self, $type) = @_;
    my $latest = $self->search_related('messages', {type => $type}, {order_by => 'timestamp desc'})->first;
    return $latest if $latest;
    return;
}

sub get_all_of_type {
    my ($self, $type) = @_;
    my @all = $self->search_related('messages', {type => $type}, {order_by => 'timestamp'})->all;
    return \@all;
}

sub get_first_timestamp {
    my ($self, $type) = @_;
    my $first = $self->search_related('messages', ($type ? {type => $type} : {}) , {order_by => 'timestamp'})->first;
    return $first->timestamp if $first;
    return 0;
}

sub get_last_timestamp {
    my ($self, $type) = @_;
    my $last = $self->search_related('messages', ($type ? {type => $type} : {}) , {order_by => 'timestamp desc'})->first;
    return $last->timestamp if $last;
    return 0;
}

sub get_spreadsheet {
    my $self = shift;
    my $latest = $self->get_latest_of_type('spreadsheet');
    return $latest->text if $latest;
    return;
}

sub set_spreadsheet {
    my ($self,$url) = @_;
    return $self->add_of_type('spreadsheet',$url);
}

sub get_folder {
    my $self = shift;
    my $latest = $self->get_latest_of_type('folder');
    return $latest->text if $latest;
    return;
}

sub set_folder {
    my ($self,$url) = @_;
    return $self->add_of_type('folder',$url);
}

sub add_of_type {
    my ($self, $type, $text, $user_id) = @_;
    my $msg = $self->create_related('messages' => { 'type' => $type, 'text' => $text, 'user_id' => $user_id });
}

sub remove_message {
    my ($self, $id, $user_id) = @_;
    my $msg = $self->find_related('messages' => { 'id' => $id });
    if (! $msg or $msg->type =~ /^removed_/) {
        warn "Failed to remove message $id by $user_id";
        return;
    }
    $msg->set_column('type','removed_' . $msg->type);
    $msg->update;
    return $self->add_of_type('removal',$id,$user_id);
}

1;

