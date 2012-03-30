package SolveWith::Schema::Result::Puzzle;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('puzzle');
__PACKAGE__->add_columns(
    id => {
        accessor => 'album',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'display_name',
    'state',
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many('puzzle_rounds' => 'SolveWith::Schema::Result::PuzzleRound', 'puzzle_id');
__PACKAGE__->many_to_many('rounds' => 'puzzle_rounds', 'round_id');
1;

