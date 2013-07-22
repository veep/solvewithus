package SolveWith::Schema::Result::PuzzleInfo;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('puzzle_info');
__PACKAGE__->add_columns(
    'puzzle_id',
    'type',
    'text',
);
__PACKAGE__->set_primary_key( 'puzzle_id', 'type');

__PACKAGE__->belongs_to('puzzle', 'SolveWith::Schema::Result::Puzzle', 'puzzle_id');

1;

