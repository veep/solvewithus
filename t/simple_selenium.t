package SimpleLoggedIn;
use common::sense;
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/lib';
use parent qw(SeleniumTest);
use Test::More;
use Test::Mojo;

require TestSetup;

sub logged_out : Test(no_plan) {
    my $self = shift;
    $self->{mojo_test}->ua->max_redirects(0);
    my $res = $self->{mojo_test}->navigate_ok('/')
    ->current_url_is('/welcome', '/ goes to welcome page without login');
}

sub logged_in_gets_you_to_empty_events_page : Test(no_plan) {
    my $self = shift;
    my $user = TestSetup::setup_logged_in_user($self->{mojo_test});

    my $res = $self->{mojo_test}->navigate_ok('/')
    ->current_url_is('/thanks')
    ->live_text_like('p', qr/Thanks for signing up/ );
}

Test::Class->runtests;
