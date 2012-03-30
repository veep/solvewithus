package SolveWith::Schema::Result::Team;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('team');

__PACKAGE__->add_columns(
    id => {
        accessor => 'album',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'display_name',
    'google_group',
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many( team_users => 'SolveWith::Schema::Result::UserTeam', 'team_id');
__PACKAGE__->many_to_many('users' => 'team_users', 'user_id');

__PACKAGE__->has_many( events => 'SolveWith::Schema::Result::Event', 'team_id');

sub get_puzzle_tree {
    my $self = shift;
    my @result;
    foreach my $event ($self->events) {
        push @result, {event => $event, rounds => $event->get_puzzle_tree};
    }
    return \@result;
}

1;
