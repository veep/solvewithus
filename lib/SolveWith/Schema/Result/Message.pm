package SolveWith::Schema::Result::Message;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('message');
__PACKAGE__->add_columns(
    id => {
        accessor => 'message',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'chat_id',
    'type',
    'text',
    'timestamp',
    'user_id',
);


__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many('user_messages' => 'SolveWith::Schema::Result::UserMessage', 'message_id');
__PACKAGE__->belongs_to('chat' => 'SolveWith::Schema::Result::Chat', 'chat_id');
__PACKAGE__->belongs_to('user' => 'SolveWith::Schema::Result::User', 'user_id',
                        { join_type => 'left' }
                    );

sub new {
    use Time::HiRes;
    my $self = shift;
    $_[0]->{timestamp} = scalar Time::HiRes::time;
    return $self->next::method( @_ );
}
1;
