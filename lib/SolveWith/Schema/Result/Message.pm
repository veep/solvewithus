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
);


__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('chat' => 'SolveWith::Schema::Result::Chat', 'chat_id');


1;
