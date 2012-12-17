package SolveWith::Spreadsheet;
use strict;
use Net::Google::DocumentsList;
use Mojo::Home;

my $debug = 1;

{
    my $_service;
    sub _service {
        return $_service //= Net::Google::DocumentsList->new(
            username => '***REMOVED***',
            password => '***REMOVED***',
        );
    }
}

sub shares_folder {
    my $service = _service();
    my ($subfolder) = $service->items( {
        'title' => 'Shares',
        'title-exact' => 'true',
        'category' => 'folder',
    });
    if (! $subfolder) {
        $subfolder = $service->add_folder( { title => 'Shares' } );
        warn "Creating Shares folder\n" if $debug;
    }
    return $subfolder;
}

sub auth_folder {
    my $service = _service();
    my ($subfolder) = $service->items( {
        'title' => 'Auths',
        'title-exact' => 'true',
        'category' => 'folder',
    });
    if (! $subfolder) {
        $subfolder = $service->add_folder( { title => 'Auths' } );
        warn "Creating Auths folder\n" if $debug;
    }
    return $subfolder;
}


sub team_folder {
    my ($group_name) = @_;
    my $shares = shares_folder();
    my $folder_name = "SolveWith.Us: $group_name";
    $folder_name =~ s/@.*//;
    my ($subfolder) = $shares->items( {
        'title' => $folder_name,
        'title-exact' => 'true',
        'category' => 'folder',
    });
    if (! $subfolder) {
        $subfolder = $shares->add_folder( { title => $folder_name } );
        warn "Creating '$folder_name' under Shares\n" if $debug;
        update_acl($subfolder,'group',$group_name,'writer');
    }
    return $subfolder;
}

sub team_auth_spreadsheet {
    my ($group_name) = @_;
    my $auth = auth_folder();
    my $ss_name = "Auth: $group_name";
    my ($ss) = $auth->items( {
        'title' => $ss_name,
        'title-exact' => 'true',
        'category' => 'spreadsheet',
    });
    if (! $ss) {
        $ss = $auth->add_item( { title => $ss_name, kind => 'spreadsheet' } );
        warn "Creating '$ss_name' under Auth\n" if $debug;
    }
    update_acl($ss,'group',$group_name,'reader');
    return $ss->alternate;
}

sub event_folder {
    my $event = shift;
    my $team = $event->team;
    my $team_folder = team_folder($team->google_group);
    die unless $team_folder;
    my ($event_folder) = $team_folder->items( {
        'title' => $event->display_name,
        'title-exact' => 'true',
        'category' => 'folder',
    });
    if (! $event_folder) {
        $event_folder = $team_folder->add_item( { title => $event->display_name, kind => 'folder' } );
        warn "Creating '" . $event->display_name . "' in team\n" if $debug;
    }
    return $event_folder;
}

sub round_folder {
    my $round = shift;
    my $event = $round->event;
    my $event_folder = event_folder($event);
    die unless $event_folder;
    my ($round_folder) = $event_folder->items( {
        'title' => $round->display_name,
        'title-exact' => 'true',
        'category' => 'folder',
    });
    if (! $round_folder) {
        $round_folder = $event_folder->add_item( { title => $round->display_name, kind => 'folder' } );
        warn "Creating '" . $round->display_name . "' in event\n" if $debug;
    }
    return $round_folder;
}

sub trigger_puzzle_spreadsheet {
    my ($c, $puzzle) = @_;
    my $rootdir = Mojo::Home->new->detect('SolveWith')->to_string;
    if ($c) {
        $c->app->log->info("Starting SS for " . $puzzle->id . ' from ' . $rootdir);
    } else {
        warn ("Starting SS for " . $puzzle->id . ' from ' . $rootdir);
    }
    system("$rootdir/script/give-puzzle-ss " . $puzzle->id . "&");
}

sub puzzle_spreadsheet {
    my $puzzle = shift;
    my $round = $puzzle->rounds->first;
    my $parent_folder;
    if ($round->display_name eq '_catchall') {
        $parent_folder = event_folder($round->event);
    } else {
        $parent_folder = round_folder($round);
    }
    die unless $parent_folder;
    my ($puzzle_ss) = $parent_folder->items( {
        'title' => $puzzle->display_name,
        'title-exact' => 'true',
        'category' => 'spreadsheet',
    });
    if (! $puzzle_ss) {
        $puzzle_ss = $parent_folder->add_item( { title => $puzzle->display_name, kind => 'spreadsheet' } );
        warn "Creating '" . $puzzle->display_name . "' in round\n" if $debug;
    }
    die unless $puzzle_ss;
    return $puzzle_ss->alternate;
}

sub add_user_to_team {
    my ($group, $email) = @_;
    my $folder = team_folder($group);
    return 0 unless $folder;
    return update_acl($folder,'user',$email,'reader');
}

sub update_acl {
    my ($item, $scope_type, $scope_value, $role) = @_;
    eval {
        my @acls = $item->acls;
        foreach my $acl (@acls) {
            if ($acl->scope->{type} eq  $scope_type
                && $acl->scope->{value} eq $scope_value) {
                if ($role ne $acl->role) {
                    warn "Changing $scope_type/$scope_value to $role\n" if $debug;
                    $acl->role($role);
                } else {
                    $acl->role($role);
                    warn "No change: $scope_type/$scope_value already $role\n" if $debug;
                }
                return;
            }
        }
        warn "Adding $scope_type/$scope_value to $role\n" if $debug;
        $item->add_acl(
            {
                role => $role,
                scope => {
                    type => $scope_type,
                    value => $scope_value,
                },
                send_notification_emails => 'false',
            }
        );
    }
}

1;
