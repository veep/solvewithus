package SolveWith::Schema::Result::Round;
use common::sense;
use base qw/DBIx::Class::Core/;
use Mojo::Util;
use CHI;
use Time::HiRes;

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
        my $row = {};
        $row->{puzzle} = $puzzle;
        my $now = time;
        $row->{open_time} = $now;
        $row->{activity_time} = $now;
        $row->{state_change_time} = $now;
        $row->{solutions} = [];
        $row->{users_live} = [];
        for my $puzzle_info ($puzzle->search_related('puzzle_info')) {
            if ($puzzle_info->type eq 'first activity') {
                $row->{open_time} = $puzzle_info->text;
            } elsif ($puzzle_info->type eq 'last activity') {
                $row->{activity_time} = $puzzle_info->text;
            } elsif ($puzzle_info->type eq 'state time') {
                $row->{state_change_time} = $puzzle_info->text;
            } elsif ($puzzle_info->type =~ /^solution /) {
                push @{$row->{solutions}}, $puzzle_info->text;
            } elsif ($puzzle_info->type eq 'summary') {
                $row->{summary} = $puzzle_info->text;
            } elsif ($puzzle_info->type eq 'priority') {
                $row->{priority} = $puzzle_info->text || 'normal';
            }
        }
        $row->{state} = $puzzle->state;
        $row->{display_name} = $puzzle->display_name;
        $row->{id} = $puzzle->id;
        $row->{users_live} = 
#          $cache->compute( 'puzzle ' . $puzzle->id . 'users_live',
#                                              {expires_in => '60', busy_lock => 10},
#                                              sub {  
             [$puzzle->users_live($cache)] ;
#          } );
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
