package SolveWith::Schema::Result::Event;
use common::sense;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('event');
__PACKAGE__->add_columns(
    id => {
        accessor => 'event',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'team_id',
    'display_name',
    'state',
    'chat_id',
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('team' => 'SolveWith::Schema::Result::Team', 'team_id');
__PACKAGE__->has_many(rounds => 'SolveWith::Schema::Result::Round', 'event_id');
__PACKAGE__->has_one(chat => 'SolveWith::Schema::Result::Chat', { 'foreign.id' => 'self.chat_id'} );

sub get_puzzle_tree {
    my ($self,$c) = @_;
    my @result;
    my @data = $self->result_source->schema->resultset('Round')->search( { event_id => $self->id}, {
        prefetch => { 'puzzle_rounds' => { 'puzzle_id' => 'puzzle_info'}},
    });
    my %round_urls;
    for my $round_url_message (@{ $self->chat->get_all_of_type('round_url') }) {
        my ($id,$url) = split(' ',$round_url_message->text,2);
        $round_urls{$id} = $url;
    }
    foreach my $round (@data) {
        my $round_id = $round->id;
        push @result, {round => $round, round_id => $round_id,
                       round_url => $round_urls{$round_id},
                       puzzles => $round->get_puzzle_tree($c)
                   };
    }
    return \@result;
}

sub new {
    my $self = shift;
    my $chat = $_[0]->{-result_source}->schema->resultset('Chat')->create({});
    $_[0]->{chat_id} = $chat->id;
    return $self->next::method( @_ );
}

sub users_live {
    my ($self, $cache) = @_;
    my $event_id = $self->id;
    if (my $cached_user_list = $cache->get('users_live_event_'. $event_id)) {
        return @$cached_user_list;
    }
    my @loggedin;
    my $max_id = $cache->compute( 'max user id',
                                  {expires_in => '300', busy_lock => 10},
                                  sub { $self->result_source->schema->resultset('User')->get_column('id')->max();}
                              );
    my $results = $cache->get_multi_arrayref( [ map { "in event " . $event_id . " " . $_ } (0..$max_id) ] );
    for my $user_id (0..$max_id) {
        if ($$results[$user_id]) {
            my $user = $self->result_source->schema->resultset('User')->find($user_id);
            if ($user) {
                push @loggedin, ($user->display_name // $user->google_name // $user->id );
            }
        }
    }
    my @rv =  sort @loggedin ;
    my $expire_time=30;
    if (! @rv) {
        # People will invalidate it when they join
        $expire_time=3600;
    }
    $cache->set('users_live_event_'. $event_id, \@rv, {expires_in => $expire_time, expires_variance => .2} );
    return @rv;
}

sub expire_users_live_cache {
    my ($self, $cache) = @_;
    $cache->remove('users_live_event_'. $self->id);
}

1;

