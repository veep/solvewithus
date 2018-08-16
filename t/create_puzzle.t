package SimpleLoggedIn;
use common::sense;
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/lib';
use parent qw(SeleniumTest);
use Test::More;
use Test::Mojo;

require TestSetup;

sub create_puzzle : Test(no_plan) {
    my $self = shift;
    my $t = $self->{mojo_test};
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

    $t->element_is_hidden("#inputPuzzleName");
    $t->click_ok('button.add-a-puzzle-button');

    $t->driver->default_finder('xpath');
    $t->element_is_displayed('//*[@id="inputPuzzleName"]');
    $t->element_is_displayed('//button[text()="Add Puzzle"]');
    $t->driver->default_finder('css');

    my $time = scalar time;
    $t->send_keys_ok('#inputPuzzleName','Puzzle Name ' . $time);

    $t->driver->default_finder('xpath');
    $t->click_ok('//button[text()="Add Puzzle"]');
    $t->driver->default_finder('css');

    $t->wait_for('td.puzzle-name-cell');
    $t->live_element_count_is('td.puzzle-name-cell',1);
    $t->live_text_like('td.puzzle-name-cell', qr/Puzzle Name \d+/ );
    $t->element_is_hidden("#inputPuzzleName");
}

Test::Class->runtests;
