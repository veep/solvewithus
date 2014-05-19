package SolveWith::Schema::Result::SolvepadHotspot;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('solvepad_hotspot');
__PACKAGE__->add_columns(
    id => {
        accessor => 'solvepad_hotspot',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'source_id',
    'shape',
    'shape_data',
    'up',
    'down',
    'left',
    'right',
    'private',
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('solvepad_source' => 'SolveWith::Schema::Result::SolvepadSource', 'source_id');

sub new {
    my $self = shift;
    $_[0]->{private} //= 0;
    return $self->next::method( @_ );
}

1;

