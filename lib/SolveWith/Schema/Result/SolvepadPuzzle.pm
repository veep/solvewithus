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
__PACKAGE__->has_many('solvepad_historys' => 'SolveWith::Schema::Result::SolvepadHistory', 'puzzle_id');

sub new {
    use Time::HiRes;
    my $self = shift;
    $_[0]->{create_ts} = $_[0]->{activity_ts} = scalar Time::HiRes::time;
    return $self->next::method( @_ );
}

sub display {
    my $self = shift;
    return $self->title
        || $self->solvepad_source->title
        ||  $self->solvepad_source->url
        || 'Uploaded file';
}

sub record_activity {
    my ($self, $history) = @_;
    $self->activity_ts(scalar Time::HiRes::time);
    $self->update;
}

sub get_share_key {
    my $self = shift;
    if ($self->share_key) {
        return $self->share_key;
    }
    return $self->update_share_key;
}

sub update_share_key {
    my $self = shift;
    my $key = $self->new_share_key;
    $self->set_column('share_key', $key);
    $self->update;
    return $key;
}

sub new_share_key {
    my $self = shift;
    my $key = `cat /proc/sys/kernel/random/uuid`;
    chomp $key;
    if (length($key) < 8) {
        $key = '';
        for (1..8) {
            my $letter = int(rand(26));
            $key .= chr(97+$letter);
        }
    } else {
        $key = substr($key, -8);
    }
    return $self->id . "-$key";
}

1;

