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
    my $self = shift;
    my @result;
    foreach my $round ($self->rounds) {
        push @result, {round => $round, puzzles => $round->get_puzzle_tree};
    }
    return \@result;
}

sub spreadsheet {
    my $self = shift;
    my $url = shift;
    if (defined($url)) {
        return $self->chat->set_spreadsheet($url);
    } else {
        return $self->chat->get_spreadsheet;
    }
}

sub new {
    my $self = shift;
    my $chat = $_[0]->{-result_source}->schema->resultset('Chat')->create({});
    $_[0]->{chat_id} = $chat->id;
    return $self->next::method( @_ );
}
1;

