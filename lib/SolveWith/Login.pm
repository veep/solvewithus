package SolveWith::Login;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub homepage {
  my $self = shift;

  return $self->redirect_to($self->url_for('/event'));
}

sub welcome {
    my $self = shift;
}

sub thanks {
    my $self = shift;
}

sub reset {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if ($user) {
        $user->clear_team_membership_cache;
    }
    delete $self->session->{token};
    return $self->redirect_to($self->url_for('event'));
}


1;
