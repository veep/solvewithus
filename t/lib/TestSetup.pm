package TestSetup;

use common::sense;
use feature 'state';

use File::Temp;
use File::Basename qw/dirname/;

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

    my $config = '{ ' . $db_config . ' }';
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
1;
