package TestSetup;

use common::sense;
use feature 'state';

use File::Temp;
use File::Basename qw/dirname/;

use Mojo::Cookie::Response;

sub use_https {
    my $test_obj = shift;
    eval {
        # 5.14 / Mojo from 2012
        $test_obj->ua->app_url('https');
    };
    if ($@) {
        # Ok, that failed, try 5.28 & Mojo from 2018
        $test_obj->ua->server->url('https');
    };
    foreach my $host ('localhost','127.0.0.1') {
        $test_obj->ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name => 'test_https',
                value => 1,
                domain => $host,
                path => '/',
            )
          );
    }
    if ($test_obj->can('driver')) {
        $test_obj->driver->add_cookie(
            'test_https',
            '1',
            '/',
            '127.0.0.1',
        );
    }
}

sub clear_cookies {
    my $test_obj = shift;
    $test_obj->ua->cookie_jar->empty();
    if ($test_obj->can('driver')) {
        $test_obj->driver->delete_all_cookies();
    }
}

sub setup_config {
    $ENV{MOJO_MODE} = 'testing';

    state $config_temp = File::Temp->new( DIR=>'/tmp');
    $ENV{MOJO_TESTING_CONFIG} = $config_temp->filename;
#    warn '# ' . $ENV{MOJO_TESTING_CONFIG};

    state $db_temp = File::Temp->new(
        TEMPLATE=>'tempdbXXXXXXX',
        SUFFIX => '.db',
        DIR => '/tmp',
    );
    my $db_filename = $db_temp->filename;

    system("sqlite3 $db_filename < " . dirname(__FILE__) . '/schema.sql');
    my $db_config = 'db_file => "' . $db_filename . '"';

    my $config = '{ ' . $db_config . ', secret_phrase => "test secret" }';
#    warn '# '. $config;
    print $config_temp $config;
    $config_temp->close;
}

sub setup_testuser {
    my $app = shift;
    my %options = (
        user => 'user' . int(rand(100000000)) . ' lastname',
        gmail => 'mail' . int(rand(100000000)),
        google_id => 'google' . int(rand(100000000)),
        @_,
    );
    return $app->db->resultset('User')->create(
        {
            google_id => $options{google_id},
            google_name => $options{gmail},
            display_name => $options{user},
        }
    );
}

sub setup_logged_in_user {
    my ($test_obj) = shift;
    my $user = setup_testuser($test_obj->app);
    foreach my $host ('localhost','127.0.0.1') {
        $test_obj->ua->cookie_jar->add(
            Mojo::Cookie::Response->new(
                name => 'test_userid',
                value => $user->id,
                domain => $host,
                path => '/',
            )
          );
    }
    if ($test_obj->can('driver')) {
        $test_obj->driver->add_cookie(
            'test_userid',
            $user->id,
            '/',
            '127.0.0.1',
        );
    }
    return $user;
}

sub setup_test_team {
    my $app = shift;
    my %options = (
        name => 'team ' . int(rand(100000000)),
        group => 'group' . int(rand(100000000)),
        @_,
    );
    return $app->db->resultset('Team')->create(
        {
            display_name => $options{name},
            google_group => $options{group},
            no_spreadsheet => 1,
        }
    );
}

sub setup_test_event {
    my $app = shift;
    my %options = (
        name => 'event ' . int(rand(100000000)),
        @_,
    );
    die "Need team to create test_event" unless $options{team};
    my $event = $options{team}->find_or_create_related ('events', {
        display_name => $options{name},
    });
    $event->state('open');
    return $event;
}

1;

