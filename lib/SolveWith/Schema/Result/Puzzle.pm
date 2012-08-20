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
    my $ss = $self->chat->get_spreadsheet;
    return $ss if $ss;
    my $name = join(
        ' - ',
        $self->display_name,
        $self->rounds->first->event->display_name,
        $self->rounds->first->event->team->display_name,
    );
    warn $name;
    $ss = SolveWith::Spreadsheet->new( ssname => $name,
                                       folder => $self->rounds->first->event->display_name,
                                       group => $self->rounds->first->event->team->google_group,
                                       mode => 'writer',
                                   );
    $url = $ss->url;
    $self->chat->set_spreadsheet( $url );
    return $url;
}

1;

