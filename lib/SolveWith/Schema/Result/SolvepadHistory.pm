package SolveWith::Schema::Result::SolvepadHistory;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('solvepad_history');
__PACKAGE__->add_columns(
    id => {
        accessor => 'solvepad_hotspot',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'puzzle_id',
    'user_id',
    'ts',
    'hotspot_id',
    'older',
    'newer',
    'note',
    'type',
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('solvepad_puzzle' => 'SolveWith::Schema::Result::SolvepadPuzzle', 'puzzle_id');
__PACKAGE__->belongs_to('solvepad_user' => 'SolveWith::Schema::Result::User', 'user_id');
__PACKAGE__->belongs_to('solvepad_hotspot' => 'SolveWith::Schema::Result::SolvepadHotspot', 'hotspot_id');

sub new {
    my $self = shift;
    return $self->next::method( @_ );
}

1;

