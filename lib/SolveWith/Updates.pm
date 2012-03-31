package SolveWith::Updates;
use Mojo::Base 'Mojolicious::Controller';

sub getnew {
    my $self = shift;
    my $type = $self->stash('type');
    my $id = $self->stash('id');
    my $last_update = $self->stash('last') || 0;
    $self->render(text => "This is updates#getnew. $type $id $last_update");
}


1;
