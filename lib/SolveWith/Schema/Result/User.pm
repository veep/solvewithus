package SolveWith::Schema::Result::User;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('user');
__PACKAGE__->add_columns(
    id => {
        accessor => 'album',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'google_name',
    'google_id',
    'display_name',
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many('user_teams' => 'SolveWith::Schema::Result::UserTeam', 'user_id');
__PACKAGE__->many_to_many('teams' => 'user_teams', 'team_id');

sub get_puzzle_tree {
    my $self = shift;
    my @result;
    foreach my $team ($self->teams) {
        push @result, {team => $team, events => $team->get_puzzle_tree};
    }
    return \@result;
}

sub clear_team_membership_cache {
    my $self = shift;
    $self->user_teams->delete;
}

1;

