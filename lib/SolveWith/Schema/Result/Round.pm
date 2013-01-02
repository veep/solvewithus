package SolveWith::Schema::Result::Round;
use common::sense;
use base qw/DBIx::Class::Core/;
use Mojo::Util;
use CHI;

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
    my ($self,$c) = @_;
    my @result;
    foreach my $pr ($self->puzzle_rounds) {
        my $puzzle = $pr->puzzle_id;
        my $cache;
        if (! $c or ! ($cache = $c->cache)) {
            $cache = CHI->new( driver => 'Memory', global => 1 );
        }
        my $row = {puzzle => $puzzle,
                   open_time => $cache->compute( 'puzzle ' . $puzzle->id . ' first ts',
                                                 '5 minutes',
                                                 sub { $puzzle->chat->get_first_timestamp }
                                             ),
                   activity_time => $cache->compute( 'puzzle ' . $puzzle->id . ' last ts',
                                                     '30',
                                                     sub { $puzzle->chat->get_last_timestamp }
                                                 ),
                   state_change_time => $cache->compute( 'puzzle ' . $puzzle->id . ' last state',
                                                         '30',
                                                         sub { $puzzle->chat->get_last_timestamp('state') }
                                                     ),
                   state => $puzzle->state,
                   display_name => $puzzle->display_name,
                   id => $puzzle->id,
                   priority => $puzzle->priority,
                   solutions => $cache->compute( 'puzzle ' . $puzzle->id . 'solutions',
                                                 15,
                                                 sub { return [ map { $_->text}  @{$puzzle->chat->get_all_of_type('solution')} ];}
                                             ),
                   users_live => $cache->compute( 'puzzle ' . $puzzle->id . 'users_live',
                                                  30,
                                                  sub { [ $puzzle->users_live ];}
                                              ),
               };
        push @result, $row;
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
