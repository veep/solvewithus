package SolveWith::Schema::ResultSet::Puzzle;
use parent 'DBIx::Class::ResultSet';

sub find_by_token {
    my ($self,$token) = @_;
    return unless $token;
    my @rows = $self->search(
        {
            'messages.type' => 'direct_token',
            'messages.text' => $token,
        },
        {
            join => {'chat' => 'messages'},
        },
    )->all();
    return $rows[0];
}


1;
