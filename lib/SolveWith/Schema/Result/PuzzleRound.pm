package SolveWith::Schema::Result::PuzzleRound;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('puzzle_round');
__PACKAGE__->add_columns( 'puzzle_id', 'round_id', 'type');
__PACKAGE__->set_primary_key( 'puzzle_id', 'round_id');
__PACKAGE__->belongs_to('puzzle_id' => 'SolveWith::Schema::Result::Puzzle');
__PACKAGE__->belongs_to('round_id' => 'SolveWith::Schema::Result::Round');

1;
