package SolveWith::Schema::Result::SolvepadPuzzle;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('solvepad_puzzle');
__PACKAGE__->add_columns(
    id => {
        accessor => 'solvepad_puzzle',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'source_id',
    'user_id',
    'create_ts',
    'activity_ts',
    'state',
    'title',
    'view_url',
    'share_key',
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('solvepad_source' => 'SolveWith::Schema::Result::SolvepadSource', 'source_id');
__PACKAGE__->belongs_to('user' => 'SolveWith::Schema::Result::User', 'user_id');

sub new {
    use Time::HiRes;
    my $self = shift;
    $_[0]->{create_ts} = $_[0]->{activity_ts} = scalar Time::HiRes::time;
    return $self->next::method( @_ );
}

1;

