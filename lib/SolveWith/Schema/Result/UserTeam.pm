package SolveWith::Schema::Result::UserTeam;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('user_team');
__PACKAGE__->add_columns( 'user_id', 'team_id', 'member');
__PACKAGE__->set_primary_key( 'user_id', 'team_id');
__PACKAGE__->belongs_to('user_id' => 'SolveWith::Schema::Result::User');
__PACKAGE__->belongs_to('team_id' => 'SolveWith::Schema::Result::Team');

1;
