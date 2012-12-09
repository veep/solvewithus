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
    $url = $self->chat->get_spreadsheet;
    return $url if $url;

    eval {
        $url = SolveWith::Spreadsheet::puzzle_spreadsheet($self);
    };
    warn $@ if $@;
    if ($url) {
        $self->chat->set_spreadsheet( $url );
    }
    return $url;
}

1;

