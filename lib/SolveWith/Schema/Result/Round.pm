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
        $c->app->log->info("Start time " . Time::HiRes::time());
        $row->{puzzle} = $puzzle;
        $row->{open_time} = $cache->compute( 'puzzle ' . $puzzle->id . ' first ts',
                                             {expires_in => '5 minutes', busy_lock => 10},
                                             sub { $puzzle->chat->get_first_timestamp }
                                         );
        $c->app->log->info("after open time " . Time::HiRes::time());
        $row->{activity_time} = $cache->compute(
            'puzzle ' . $puzzle->id . ' last ts',
            {expires_in => '30', busy_lock => 10},
            sub {
                $puzzle->chat->get_last_timestamp(['chat','solution','puzzleinfo','created']); 
            }
        );
        $c->app->log->info("after activity time " . Time::HiRes::time());
        $row->{state_change_time} = $cache->compute( 'puzzle ' . $puzzle->id . ' last state',
                                                     {expires_in => '30', busy_lock => 10},
                                                     sub { $puzzle->chat->get_last_timestamp('state') }
                                                 );
        $c->app->log->info("after state_change time " . Time::HiRes::time());
        $row->{state} = $puzzle->state;
        $row->{display_name} = $puzzle->display_name;
        $row->{summary} = $puzzle->summary;
        $row->{id} => $puzzle->id;
        $row->{priority} = $puzzle->priority;
        $c->app->log->info("after priority time " . Time::HiRes::time());
        $row->{solutions} = $cache->compute( 
            'puzzle ' . $puzzle->id . 'solutions',
            {expires_in => '10', busy_lock => 10},
            sub { 
                return [ map { $_->text}  @{$puzzle->chat->get_all_of_type('solution')} ];
            }
        );
        $c->app->log->info("after solutions time " . Time::HiRes::time());
        $row->{users_live} = $cache->compute( 'puzzle ' . $puzzle->id . 'users_live',
                                              {expires_in => '10', busy_lock => 10},
                                              sub {  [$puzzle->users_live($cache)] ;}
                                          );
        $c->app->log->info("after users_live time " . Time::HiRes::time());
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
