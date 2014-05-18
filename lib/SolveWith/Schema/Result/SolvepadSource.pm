package SolveWith::Schema::Result::SolvepadSource;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('solvepad_source');
__PACKAGE__->add_columns(
    id => {
        accessor => 'solvepad_source',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'checksum',
    'url',
    'width',
    'height',
    'title',
    'disk_file',
    'create_ts',
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many('solvepad_puzzles' => 'SolveWith::Schema::Result::SolvepadPuzzle', 'source_id');

sub new {
    use Time::HiRes;
    my $self = shift;
    $_[0]->{create_ts} = scalar Time::HiRes::time;
    return $self->next::method( @_ );
}

1;

