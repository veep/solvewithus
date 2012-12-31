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

sub users_live {
    my $puzzle = shift;
    my @logged_in = $puzzle->search_related('puzzle_users',{timestamp => { '>', (time - 15)}});
    return sort map {$_->user_id->display_name // $_->user_id->google_name // $_->user_id } @logged_in;
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

1;

