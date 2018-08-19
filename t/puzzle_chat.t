package PuzzleChat;
use common::sense;
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/lib';
use parent qw(SeleniumTest);
use Test::More;
use Test::Mojo;
use Selenium::Remote::WDKeys;

sub enter_puzzle_chat : Test(no_plan) {
    my $self = shift;
    my $t = $self->{mojo_test};
    _make_event_and_go_there($t);
    $t->click_ok('button.add-a-puzzle-button');
    $t->wait_for('#inputPuzzleName');
    my $time = scalar time;
    $t->send_keys_ok('#inputPuzzleName','Puzzle Name ' . $time);
    $t->driver->default_finder('xpath');
    $t->click_ok('//button[text()="Add Puzzle"]');
    $t->driver->default_finder('css');
    $t->wait_for('td.puzzle-name-cell');
    $t->click_ok('td.puzzle-name-cell > a');
    $t->driver->get_current_url =~ qr'/puzzle/(\d+)';
    my $puzzle = $1;
    $t->wait_for('#textarea-puzzle-' . $puzzle,"textarea-puzzle-$puzzle is there");
    $t->send_keys_ok('#textarea-puzzle-' . $puzzle,'eff.org is a website');
    $t->send_keys_ok('#textarea-puzzle-' . $puzzle,KEYS->{'enter'});
    $t->driver->default_finder('xpath');
    $t->wait_for(q{//a[contains(@href,'eff.org')]});
    $t->driver->default_finder('css');
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

Test::Class->runtests;
