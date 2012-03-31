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
1;

