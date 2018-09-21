package PuzzleChat;
use common::sense;
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/lib';
use parent qw(SeleniumTest);
use Test::More;
use Test::Mojo;
use Selenium::Remote::WDKeys;

sub add_info_in_puzzle_modal : Test(no_plan) {
    my $self = shift;
    my $t = $self->{mojo_test};
    _make_event_and_go_there($t);
    my $puzzle_number = _add_puzzle_and_go_there($t);
    note $puzzle_number;

    $t->wait_for('#puzzle-info-link-'.$puzzle_number.' > a');
    $t->click_ok('#puzzle-info-link-'.$puzzle_number.' > a');

    $t->wait_for('input[name=newinfo]');
    $t->send_keys_ok('input[name=newinfo]','My new puzzle info');
    $t->send_keys_ok('input[name=newinfo]', KEYS->{'enter'});

    $t->wait_until(
        sub {
            my $text  = $t->driver->get_text('#chat-text-puzzle-' . $puzzle_number);
            note $text;
            return $text =~ m/Info +My new puzzle info/;
        },
        { timeout => 10},
    );
}

sub add_solution_in_puzzle_modal : Test(no_plan) {
    my $self = shift;
    my $t = $self->{mojo_test};
    _make_event_and_go_there($t);
    my $puzzle_number = _add_puzzle_and_go_there($t);
    note $puzzle_number;

    $t->wait_for('#puzzle-info-link-'.$puzzle_number.' > a');
    $t->click_ok('#puzzle-info-link-'.$puzzle_number.' > a');

    $t->wait_for('input[name=newsolution]');
    $t->send_keys_ok('input[name=newsolution]','solvedit');
    $t->send_keys_ok('input[name=newsolution]', KEYS->{'enter'});

    $t->wait_until(
        sub {
            my $text  = $t->driver->get_text('#chat-text-puzzle-' . $puzzle_number);
            note $text;
            return $text =~ m/Solution +solvedit/;
        },
        { timeout => 10},
    );
}

sub _make_event_and_go_there {
    my ($t) = @_;
    my $user = TestSetup::setup_logged_in_user($t);
    my $team = TestSetup::setup_test_team($t->app);
    $team->add_to_users($user, {member => 1});
    my $event = TestSetup::setup_test_event(
        $t->app,
        team => $team,
        name => 'event 1',
    );
    $t->navigate_ok('/event/' . $event->id);
    $t->current_url_is('/event/' . $event->id);
    $t->live_element_count_is('button.add-a-round-button',1);
    $t->live_text_like('button.add-a-round-button', qr/Add a Round/ );
    $t->live_element_count_is('button.add-a-puzzle-button',1);
    $t->live_text_like('button.add-a-puzzle-button', qr/Add a Puzzle/ );
}

sub _add_puzzle_and_go_there {
    my ($t) = @_;
    $t->click_ok('button.add-a-puzzle-button');
    $t->wait_for('#inputPuzzleName');
    my $time = scalar time;
    $t->send_keys_ok('#inputPuzzleName','Puzzle Name ' . $time);
    $t->driver->default_finder('xpath');
    $t->click_ok('//button[text()="Add Puzzle"]');
    $t->driver->default_finder('css');
    $t->wait_for('td.puzzle-name-cell');
    my $puzzle_number;
    eval {
        my $href = $t->driver->find_element('td.puzzle-name-cell > a')->get_attribute('href',1);
        if ($href =~ qr'/puzzle/(\d+)$') {
            $puzzle_number = $1;
            note "setting spreadsheet for $puzzle_number at first opportunity";
            $t->app->db->resultset('Puzzle')->find($puzzle_number)->spreadsheet('/thanks');
        }
    };
    $t->click_ok('td.puzzle-name-cell > a');
    if (! $puzzle_number) {
        $t->driver->get_current_url =~ qr'/puzzle/(\d+)$';
        $puzzle_number = $1;
        note "setting spreadsheet for $puzzle_number at second opportunity";
        $t->app->db->resultset('Puzzle')->find($puzzle_number)->spreadsheet('/thanks');
    }
    $t->wait_for('#textarea-puzzle-' . $puzzle_number, "textarea-puzzle-$puzzle_number is there");
    return $puzzle_number;
}

Test::Class->runtests;
