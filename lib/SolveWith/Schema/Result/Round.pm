package SolveWith::Schema::Result::Round;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('round');
__PACKAGE__->add_columns(
    id => {
        accessor => 'round',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'event_id',
    'display_name',
    'state',
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('event', 'SolveWith::Schema::Result::Event', 'event_id');
__PACKAGE__->has_many('puzzle_rounds' => 'SolveWith::Schema::Result::PuzzleRound', 'round_id');
__PACKAGE__->many_to_many('puzzles' => 'puzzle_rounds', 'puzzle_id');

sub get_puzzle_tree {
    my $self = shift;
    my @result;
    foreach my $puzzle ($self->puzzles) {
        push @result, {puzzle => $puzzle};
    }
    return \@result;
}

1;
