package SolveWith::Schema::Result::Puzzle;
use common::sense;
use base qw/DBIx::Class::Core/;
use SolveWith::Spreadsheet;

__PACKAGE__->table('puzzle');
__PACKAGE__->add_columns(
    id => {
        accessor => 'album',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'display_name',
    'state',
    'chat_id',
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many('puzzle_rounds' => 'SolveWith::Schema::Result::PuzzleRound', 'puzzle_id');
__PACKAGE__->many_to_many('rounds' => 'puzzle_rounds', 'round_id');
__PACKAGE__->has_many('puzzle_users' => 'SolveWith::Schema::Result::UserPuzzle', 'puzzle_id');
__PACKAGE__->many_to_many('users' => 'puzzle_users', 'user_id');
__PACKAGE__->has_one(chat => 'SolveWith::Schema::Result::Chat', { 'foreign.id' => 'self.chat_id'} );
__PACKAGE__->has_many('puzzle_info' => 'SolveWith::Schema::Result::PuzzleInfo', 'puzzle_id');

sub new {
    my $self = shift;
    my $chat = $_[0]->{-result_source}->schema->resultset('Chat')->create({});
    $_[0]->{chat_id} = $chat->id;
    return $self->next::method( @_ );
}

sub spreadsheet {
    my $self = shift;
    my $url = shift;
    if (defined($url)) {
        return $self->chat->set_spreadsheet($url);
    }
    $url = $self->chat->get_spreadsheet;
    if (! defined($url)) {
        SolveWith::Spreadsheet::trigger_puzzle_spreadsheet(undef,$self);
    }
    return $url;
}

sub spreadsheet_peek {
    my $self = shift;
    my $url = $self->chat->get_spreadsheet;
    return $url;
}

sub users_live {
    my ($self, $cache) = @_;
    my $puzzle_id = $self->id;
    if (my $cached_user_list = $cache->get('users_live_puzzle_'. $puzzle_id)) {
        return @$cached_user_list;
    }
    my @loggedin;
    my $max_id = $cache->compute( 'max user id',
                                  {expires_in => '300', busy_lock => 10},
                                  sub { $self->result_source->schema->resultset('User')->get_column('id')->max();}
                              );
    my $results = $cache->get_multi_arrayref( [ map { "in puzzle " . $puzzle_id . " " . $_ } (0..$max_id) ] );
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
    $cache->set('users_live_puzzle_'. $puzzle_id, \@rv, {expires_in => $expire_time, expires_variance => .2} );
    return @rv;
}

sub expire_users_live_cache {
    my ($self, $cache) = @_;
    $cache->remove('users_live_puzzle_'. $self->id);
}

sub summary {
    my ($self) = @_;
    my $current = $self->chat->get_latest_of_type('summary');
    if (defined($current)) {
        return $current->text;
    }
    return;
}
sub priority {
    my ($self, $pri, $user_id) = @_;
    my $cur_pri = $self->chat->get_latest_of_type('priority');
    if (defined($cur_pri)) {
        $cur_pri = $cur_pri->text;
    } else {
        $cur_pri = 'normal';
    }
    if (defined($pri)) {
        if ($pri ne $cur_pri) {
            $self->chat->add_of_type('priority',$pri,$user_id);
            return 1;
        }
        return 0;
    }
    return $cur_pri;
}

sub update_info {
    my ($self, $type, $value, $ts) = @_;
    if ($type eq 'solution') {
        my $info = $self->puzzle_info->update_or_create(
            {
                type => "$type $ts",
                text => $value,
            }
        );
    } elsif ($type eq 'activity') {
        my $last = $self->puzzle_info->find_or_new(
            {
                type => 'last activity',
            }
        );
        if (! $last->text or  $last->text < $value) {
            $last->text($value);
            if (! $last->in_storage) {
                $last->insert;
            } else {
                $last->update;
            }
        }
        my $first = $self->puzzle_info->find_or_new(
            { 
                type => 'first activity',
            }
        );
        if (! $first->in_storage) {
            $first->text($value);
            $first->insert;
        }
    } else {
        my $info = $self->puzzle_info->update_or_create(
            {
                type => $type,
                text => $value,
            }
        );
    }
}

sub remove_info {
    my ($self, $type, $value, $ts) = @_;
    if ($type eq 'solution') {
        $self->search_related('puzzle_info',{
            type => {like => 'solution%' },
            text => $value,
        })->delete;
    } else {
        $self->search_related('puzzle_info',{
            type => $type,
        })->delete;
    }
}
1;

