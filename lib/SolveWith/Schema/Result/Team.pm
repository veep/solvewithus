package SolveWith::Schema::Result::Team;
use common::sense;
use base qw/DBIx::Class::Core/;
use SolveWith::Spreadsheet;
use SolveWith::Auth;
use Net::Google::Spreadsheets;

__PACKAGE__->table('team');

__PACKAGE__->add_columns(
    id => {
        accessor => 'album',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },
    'display_name',
    'google_group',
    'chat_id',
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many( team_users => 'SolveWith::Schema::Result::UserTeam', 'team_id');
__PACKAGE__->many_to_many('users' => 'team_users', 'user_id');
__PACKAGE__->has_many( events => 'SolveWith::Schema::Result::Event', 'team_id');
__PACKAGE__->has_one(chat => 'SolveWith::Schema::Result::Chat', { 'foreign.id' => 'self.chat_id'} );

sub get_puzzle_tree {
    my $self = shift;
    my @result;
    foreach my $event ($self->events) {
        push @result, {event => $event, rounds => $event->get_puzzle_tree};
    }
    return \@result;
}

sub new {
    my $self = shift;
    my $chat = $_[0]->{-result_source}->schema->resultset('Chat')->create({});
    $_[0]->{chat_id} = $chat->id;
    my $spreadsheet = SolveWith::Spreadsheet->new(group => $_[0]->{google_group});
    $chat->set_spreadsheet($spreadsheet->url);
    return $self->next::method( @_ );
}

sub has_access {
    my ($self, $userid, $token) = @_;

    for my $user ($self->users) {
        return 1 if $userid == $user->id;
    }
    my $spreadsheet = $self->chat->get_spreadsheet;
    return 0 unless $spreadsheet && $spreadsheet =~ /key=(.*)/;

    my $success = 0;
    eval {
        my $response = SolveWith::Auth->new(access_token => $token)->make_request
            ("https://docs.google.com/feeds/default/private/full/spreadsheet:$1?v=3");
        if ($response->is_success) {
            $success = 1;
        }
    };
    warn $@ if $@;
    if ($success == 1) {
        $self->add_to_users($self->result_source->schema->resultset('User')->find($userid));
        return 1;
    }
    return 0;
}

1;
