package SimpleLoggedIn;
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
}

sub clean_cookies : Test(setup) {
    $APP->ua->cookie_jar->empty();
}

sub logged_out : Test(no_plan) {
    $APP->ua->max_redirects(0);
    my $res = $APP->get_ok('/')
    ->status_is(302)
    ->header_like(Location => qr(/welcome$) , '/ goes to welcome page without login');
}

sub logged_in_gets_you_to_empty_events_page : Test(no_plan) {
    my $user = TestSetup::setup_logged_in_user($APP);

    $APP->ua->max_redirects(0);
    my $res = $APP->get_ok('/')
    ->status_is(302)
    ->header_like(Location => qr(/event$) , '/ goes to event page with login');

    $APP->ua->max_redirects(1);
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
    ->header_like(Location => qr(/thanks$) , '/ goes to thanks page logged in with no teams');

    $APP->ua->max_redirects(2);
    my $res = $APP->get_ok('/','/ loads event page logged in')
    ->status_is(200)
    ->content_like( qr/Thanks for signing up/ );
}

Test::Class->runtests;
