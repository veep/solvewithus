package SimpleUserTeamEventPuzzle;
use base qw(Test::Class);

use common::sense;
use Test::More;
use Test::Mojo;
use Mojo::Cookie::Response;
use File::Basename qw/dirname/;

use lib dirname(__FILE__);
require 'lib/TestSetup.pm';

my ($APP, $JAR);

sub create_config: Test(startup) {
    TestSetup::setup_config();
    $APP = Test::Mojo->new('SolveWith');
    $JAR = $APP->ua->cookie_jar;
}

sub clean_cookies : Test(setup) {
    $JAR->empty();
}

sub user_with_team_goes_to_events_page : Test(no_plan) {
    my $user = TestSetup::setup_testuser($APP->app);
    my $team = TestSetup::setup_testteam($APP->app);
    foreach my $host ('localhost','127.0.0.1') {
        $JAR->add(
            Mojo::Cookie::Response->new(
                name => 'test_userid',
                value => $user->id,
                domain => $host,
                path => '/',
            )
          );
    }
    $team->add_to_users($user, {member => 1});

    eval {
        # 5.14 / Mojo from 2012
        $APP->ua->app_url('https');
    };
    if ($@) {
        # Ok, that failed, try 5.28 & Mojo from 2018
        $APP->ua->server->url('https');
    };

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
