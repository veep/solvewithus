package SolveWith::Schema::Result::Event;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('event');
__PACKAGE__->add_columns(
    id => {
        accessor => 'event',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'team_id',
    'display_name',
    'state',
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('team' => 'SolveWith::Schema::Result::Team', 'team_id');
__PACKAGE__->has_many(rounds => 'SolveWith::Schema::Result::Round', 'event_id');

sub get_puzzle_tree {
    my $self = shift;
    my @result;
    foreach my $round ($self->rounds) {
        push @result, {round => $round, puzzles => $round->get_puzzle_tree};
    }
    return \@result;
}

1;
