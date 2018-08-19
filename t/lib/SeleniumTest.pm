package SeleniumTest;
use base qw(Test::Class);
use Test::More;
use TestSetup;

$ENV{MOJO_SELENIUM_DRIVER} ||= 'Selenium::PhantomJS';

sub create_config: Test(startup) {
    my $self = shift;
    TestSetup::setup_config();
    eval {
        require Test::Mojo::Role::Selenium;
    };
    if ($@) {
        plan skip_all => 'No selenium role';
        return;
    }

    $self->{mojo_test} = Test::Mojo->with_roles("+Selenium")->new('SolveWith')->setup_or_skip_all;
    $self->{mojo_test}->set_window_size([1200,800]);
}

sub clean_cookies : Test(setup) {
    my $self = shift;
    TestSetup::clear_cookies($self->{mojo_test});
    TestSetup::use_https($self->{mojo_test});
}

sub clear_out_phantomjs : Test(shutdown) {
    my $self = shift;
    if ($ENV{MOJO_SELENIUM_DRIVER} =~ /PhantomJS/) {
        note 'shutting down phantomjs';
        $self->{mojo_test}->driver->shutdown_binary;
    }
}

1;
