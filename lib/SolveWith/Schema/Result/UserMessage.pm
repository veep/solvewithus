package SolveWith::Schema::Result::UserMessage;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('user_message');
__PACKAGE__->add_columns( 'user_id', 'message_id', 'status');
__PACKAGE__->set_primary_key( 'user_id', 'message_id');
__PACKAGE__->belongs_to('user_id' => 'SolveWith::Schema::Result::User',
                    );
__PACKAGE__->belongs_to('message_id' => 'SolveWith::Schema::Result::Message',
                    );

1;
