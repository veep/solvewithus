package SolveWith::Schema::Result::UserEvent;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('user_event');
__PACKAGE__->add_columns( 'user_id', 'event_id', 'timestamp');
__PACKAGE__->set_primary_key( 'user_id', 'event_id');
__PACKAGE__->belongs_to('user_id' => 'SolveWith::Schema::Result::User');
__PACKAGE__->belongs_to('event_id' => 'SolveWith::Schema::Result::Event');

1;
