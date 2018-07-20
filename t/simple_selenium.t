package SimpleLoggedIn;
use base qw(Test::Class);

use common::sense;
use Test::More;
use Test::Mojo;
use File::Basename qw/dirname/;

use lib dirname(__FILE__);
require 'lib/TestSetup.pm';

$ENV{MOJO_SELENIUM_DRIVER} ||= 'Selenium::PhantomJS';

my ($APP);

sub create_config: Test(startup) {
    TestSetup::setup_config();
    $APP = Test::Mojo->with_roles("+Selenium")->new('SolveWith')->setup_or_skip_all;
}

sub clean_cookies : Test(setup) {
    TestSetup::clear_cookies($APP);
    TestSetup::use_https($APP);
}

sub clear_out_phantomjs : Test(shutdown) {
    if ($ENV{MOJO_SELENIUM_DRIVER} =~ /PhantomJS/) {
        note 'shutting down phantomjs';
        $APP->driver->shutdown_binary;
    }
}

sub logged_out : Test(no_plan) {
    $APP->ua->max_redirects(0);
    my $res = $APP->navigate_ok('/')
    ->current_url_is('/welcome', '/ goes to welcome page without login');
}

sub logged_in_gets_you_to_empty_events_page : Test(no_plan) {
    my $user = TestSetup::setup_logged_in_user($APP);

    my $res = $APP->navigate_ok('/')
    ->current_url_is('/thanks')
    ->live_text_like('p', qr/Thanks for signing up/ );
}

Test::Class->runtests;
