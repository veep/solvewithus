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
    my $spreadsheet_url = SolveWith::Spreadsheet::team_auth_spreadsheet($_[0]->{google_group});
    $chat->set_spreadsheet($spreadsheet_url);
    my $share_folder = SolveWith::Spreadsheet::team_folder_id($_[0]->{google_group});
    $chat->set_folder($share_folder);
    return $self->next::method( @_ );
}

sub has_access {
    my ($self, $userid, $token) = @_;

    my $debug = 0;
    for my $team_user ($self->team_users) {
        my $user = $team_user->user_id;
        if ($userid == $user->id) {
            warn "Returning " . $team_user->member . " from has_access for $userid\n" if $debug;
            return $team_user->member;
        }
    }
    warn "User $userid not in group " . $self->google_group . " list\n" if $debug;

    my $spreadsheet = $self->chat->get_spreadsheet;
    return 0 unless $spreadsheet;
    my $key;
    if ( $spreadsheet =~ /key=([^&]+)/) {
        $key = $1;
    } else {
        $key = $spreadsheet;
    }

    warn "Got ss $spreadsheet\n" if $debug;
    my $success = 0;
    my $this_user = $self->result_source->schema->resultset('User')->find($userid);
    return 0 unless $this_user;

    warn "Got user object\n" if $debug;
    warn "\nRequesting drive info\n\n" if $debug;
    my $response = SolveWith::Auth->new(access_token => $token)->make_request(
        "https://www.googleapis.com/drive/v2/files/$key/permissions" );
    warn $response->code if $debug;
    if ($response->is_success) {
        $success = 1;
        warn "repsonse ok\n" if $debug;
    } elsif ($response->code == 404) {
        $success = 0;       # Normal failure;
    } else {
        die;
    }
    $self->add_to_users($this_user, {member => $success});
    return $success;
}

1;
