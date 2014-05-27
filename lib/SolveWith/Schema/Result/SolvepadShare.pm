package SolveWith::Schema::Result::SolvepadShare;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('solvepad_puzzle_share');
__PACKAGE__->add_columns(
    id => {
        accessor => 'solvepad_puzzle_share',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'puzzle_id',
    'user_id',
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('user' => 'SolveWith::Schema::Result::User', 'user_id');
__PACKAGE__->belongs_to('puzzle' => 'SolveWith::Schema::Result::SolvepadPuzzle', 'puzzle_id');


1;


