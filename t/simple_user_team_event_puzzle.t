package SimpleUserTeamEventPuzzle;
use base qw(Test::Class);

use common::sense;
use Test::More;
use Test::Mojo;
use File::Basename qw/dirname/;

use lib dirname(__FILE__);
require 'lib/TestSetup.pm';

my ($APP);

sub create_config: Test(startup) {
    TestSetup::setup_config();
    $APP = Test::Mojo->new('SolveWith');
    TestSetup::use_https($APP);
}

sub clean_cookies : Test(setup) {
    $APP->ua->cookie_jar->empty();
}

sub user_with_team_goes_to_events_page : Test(no_plan) {
    my $team = TestSetup::setup_testteam($APP->app);
    my $user = TestSetup::setup_logged_in_user($APP);
    $team->add_to_users($user, {member => 1});

    my $res = $APP->get_ok('/')
    ->status_is(302)
    ->header_like(Location => qr(/event$) , '/ goes to event page logged in and on a team');

    my $team_name = $team->display_name;
    $APP->ua->max_redirects(2);
    my $res = $APP->get_ok('/','/ loads event page logged in')
    ->status_is(200)
    ->content_like( qr/Events you have access to/, 'on the events page' )
    ->content_like( qr/\Q$team_name\E/, 'has team name' );
}


Test::Class->runtests;
