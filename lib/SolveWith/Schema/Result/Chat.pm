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
    return $self->search_related('messages', {type => $type}, {order_by => 'timestamp desc'})->first->text;
}

sub get_spreadsheet {
    my $self = shift;
    return $self->get_latest_of_type('spreadsheet');
}

sub set_spreadsheet {
    my ($self,$url) = @_;
    return $self->add_of_type('spreadsheet',$url);
}

sub add_of_type {
    my ($self, $type, $text) = @_;
    my $msg = $self->create_related('messages' => { 'type' => $type, 'text' => $text });
}

1;

