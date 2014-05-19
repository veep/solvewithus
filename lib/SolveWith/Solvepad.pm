package SolveWith::Solvepad;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw/md5_sum/;
use Mojo::UserAgent;

sub main {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('/welcome');
    }
    my @open_puzzles;
    for my $puzzle (
        $self->db->resultset('SolvepadPuzzle')->search(
            { user_id => $user->id }
        )->all()
    ) {
        push @open_puzzles, $puzzle;
    }
    $self->stash('open_puzzles' => \@open_puzzles);
}

sub puzzle {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('/solvepad');
    }
    my $puzzle_id = $self->param('id');
    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find($puzzle_id);
    if (! $puzzle or $puzzle->user_id != $user->id) {
        $self->redirect_to('/solvepad');
    }
    $self->stash('puzzle' => $puzzle);
}

sub create {
    my ($self) = @_;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('/solvepad');
    }

    my $title = $self->param('PuzzleTitle');
    my $url = $self->param('PuzzleURL');

    if (! $url) {
        $self->redirect_to('/solvepad');
    }

    my $user_id = $user->id;

    my $ua = Mojo::UserAgent->new;
    my $body = $ua->get($url)->res->body;
    if (! $body) {
        $self->redirect_to('/solvepad');
    }

    my $checksum = md5_sum($body);
    my $source = $self->db->resultset('SolvepadSource')->search(
        { checksum => $checksum }
    )->first();

    if (! $source) {
        $source = $self->db->resultset('SolvepadSource')->create(
            {
                url => $url,
                checksum => $checksum,
            }
        );
    }

    my $rootdir = Mojo::Home->new->detect('SolveWith')->to_string;
    $self->app->log->info("Starting find-hotspots for " . $url . ' from ' . $rootdir);
    system("$rootdir/script/find-hotspots " . $source->id);

    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find_or_create(
        {
            user_id => $user->id,
            source_id => $source->id,
        }
    );

    if ($title) {
        $puzzle->title($title);
        $puzzle->update;
    }
    $self->redirect_to('/solvepad');
}

1;
