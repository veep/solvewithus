package SolveWith::Schema::Result::UserPuzzle;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('user_puzzle');
__PACKAGE__->add_columns( 'user_id', 'puzzle_id', 'timestamp');
__PACKAGE__->set_primary_key( 'user_id', 'puzzle_id');
__PACKAGE__->belongs_to('user_id' => 'SolveWith::Schema::Result::User');
__PACKAGE__->belongs_to('puzzle_id' => 'SolveWith::Schema::Result::Puzzle');

1;
