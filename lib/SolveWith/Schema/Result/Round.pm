package SolveWith::Schema::Result::Round;
use common::sense;
use base qw/DBIx::Class::Core/;
use Mojo::Util;

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
        push @result, {puzzle => $puzzle,
                       open_time => $puzzle->chat->get_first_timestamp,
                       activity_time => $puzzle->chat->get_last_timestamp,
                       state => $puzzle->state,
                   };
    }
    return \@result;
}

sub add_puzzle {
    my ($self,@args) = @_;
    my $rv = $self->add_to_puzzles(@args);
    if ($rv) {
        my $puzzle = $args[0];
        $self->event->chat->add_of_type('puzzle',join('','<B>New Puzzle: </B><a href="/puzzle/',$puzzle->id,'">',Mojo::Util::html_escape($puzzle->display_name),'</a> created and added to "',Mojo::Util::html_escape($self->display_name),'"'),0);
    }
    return $rv;
}
1;
