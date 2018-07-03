package SolveWith::Spreadsheet;
use strict;
use Net::Google::DocumentsList;
use Mojo::Home;
use File::Slurp;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI::Escape;
use Mojo::JSON;

my $debug = 1;

my $rootdir = Mojo::Home->new->detect('SolveWith')->to_string;
my $conf = "$rootdir/solve_with.conf";
my $access_token_file = "$rootdir/access_token";

{
    my $_service;
    my $config = do $conf;
    sub _service {
        return $_service //= Net::Google::DocumentsList->new(
            username => $config->{service_username},
            password => $config->{service_password},
        );
    }
}

sub get_current_solvewithus_access_token {
    my ($access_token);
    eval {
        ($access_token) = read_file($access_token_file);
    };
    my $ua = LWP::UserAgent->new;
    if ($access_token) {
        chomp($access_token);
        if (is_access_token_ok($access_token)) {
            return $access_token;
        }
    }
    my $config = do $conf;
    my $refresh_token = $config->{solvewithus_refresh_token};
    die "NO REFRESH TOKEN" unless $refresh_token;
    my $res = $ua->request(   POST
                              'https://accounts.google.com/o/oauth2/token',
                              [   'refresh_token' => uri_unescape($refresh_token),
                                  'client_id' => $config->{client_id},
                                  'client_secret' => $config->{client_secret},
                                  'grant_type' => 'refresh_token',
                              ],
                          );
    if ($res->is_success) {
        my $json = Mojo::JSON->new;
        $access_token = $json->decode($res->content)->{access_token};
        warn "new access token: $access_token";
        write_file($access_token_file,$access_token);
        return $access_token;
    }
    die "No access token!";
}

sub is_access_token_ok {
    my ($token) = @_;
    my $req = HTTP::Request->new(GET => 'https://www.googleapis.com/drive/v2/about');
    $req->header(Authorization => "Bearer $token");
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($req);
    return $response->is_success;
}

sub find_a_thing {
    my ($mime, $name, $parentid) = @_;
    my $access_token = get_current_solvewithus_access_token();
    my $req = HTTP::Request->new('GET');
    my $uri = URI->new('https://www.googleapis.com/drive/v2/files');
    $uri->query('q=' . uri_escape_utf8('title=' . "'$name'" . ' and ' .
                                       ($mime ? 'mimeType=' . "'$mime'" . ' and ' : ' ') .
                                       'trashed=false' .
                                       ($parentid ? " and '$parentid' in parents" : ' ')
                              )
            );
    $req->uri($uri);
    $req->header(Authorization => "Bearer $access_token");
    warn $req->as_string if $debug;
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($req);
    return unless $response->is_success;
    my $json = Mojo::JSON->new;
    my $item = $json->decode($response->content)->{items}[0];
    return( { id => $item->{id}, weblink => $item->{alternateLink} });
}

sub find_a_folder_id {
    my ($parentid, $name) = @_;
    my $info = find_a_thing('application/vnd.google-apps.folder',$name,$parentid);
    return $info->{id};
}

sub find_a_sheet {
    my ($parentid, $name) = @_;
    my $info = find_a_thing('application/vnd.google-apps.spreadsheet',$name,$parentid);
    return $info;
}

sub add_a_thing {
    my ($mime, $name, $parentid) = @_;
    my $access_token = get_current_solvewithus_access_token();
    my $req = HTTP::Request->new('POST');
    $req->uri('https://www.googleapis.com/drive/v2/files?pinned=true');
    $req->header('Content-Type' => 'application/json');
    $req->header(Authorization => "Bearer $access_token");
    my $json = Mojo::JSON->new;
    $req->content($json->encode({ mimeType => $mime, title => $name, parents => [ {id => $parentid} ]}));
    warn $req->as_string;
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($req);
    warn $response->content;
    die unless $response->is_success;
    my $item = $json->decode($response->content);
    return( { id => $item->{id}, weblink => $item->{alternateLink} });
}


sub add_a_sheet {
    my ($parentid, $name) = @_;
    my $info = add_a_thing('application/vnd.google-apps.spreadsheet',$name,$parentid);
    return $info;
}

sub add_a_folder {
    my ($parentid, $name) = @_;
    my $info = add_a_thing('application/vnd.google-apps.folder',$name,$parentid);
    return $info;
}

sub shares_folder_id {
    my $shares_id = find_a_folder_id('root','Shares');
    if ($shares_id) {
        warn "Found shares id: $shares_id" if $debug;
    } else {
        warn "Creating Shares folder\n" if $debug;
        #TODO
        die "shouldn't get here";
    }
    return $shares_id;
}

sub auth_folder_id {
    my $auth_id = find_a_folder_id('root','Auths');
    if ($auth_id) {
        warn "Found auth id: $auth_id" if $debug;
    } else {
        warn "Creating Auths folder\n" if $debug;
        #TODO
        die "shouldn't get here";
    }
    return $auth_id;
}

sub token_puzzles_folder_id {
    my $tokens_id = find_a_folder_id('root','Token Puzzles');
    my $debug = 1;
    if ($tokens_id) {
        warn "Found tokens id: $tokens_id" if $debug;
    } else {
        warn "Would have created Token Puzzles folder\n" if $debug;
#        my $info = add_a_folder('root','Token Puzzles');
#        $tokens_id = $info->{id};
    }
    return $tokens_id;
}


sub team_folder_id {
    my ($group_email) = @_;
    my $shares_id = shares_folder_id();
    return unless $shares_id;
    my $folder_name = "SolveWith.Us: $group_email";
    $folder_name =~ s/@.*//;
    my $team_folder_id = find_a_folder_id($shares_id, $folder_name);
    if ($team_folder_id) {
        warn "TEAM FOLDER ID: $team_folder_id" if $debug;
        return $team_folder_id;
    } else {
        warn "Creating '$folder_name'\n" if $debug;
        my $team_folder_info = add_a_folder($shares_id, $folder_name);
        die "Can't create team folder" unless $team_folder_info->{id};
        give_group_permission($team_folder_info->{id},$group_email,'writer');
        return $team_folder_info->{id};
    }
}

sub team_auth_spreadsheet {
    my ($group_email) = @_;
    my $auths_id = auth_folder_id();
    die unless $auths_id;
    my $ss_name = "Auth: $group_email";
    my $team_auth_sheet_info = find_a_sheet($auths_id, $ss_name);
    if ($team_auth_sheet_info->{weblink}) {
        warn "found sheet: $ss_name, $team_auth_sheet_info->{weblink}" if $debug;
    } else  {
        warn "Creating '" . $ss_name . "' in $auths_id\n" if $debug;
        $team_auth_sheet_info = add_a_sheet($auths_id, $ss_name);
        give_group_permission($team_auth_sheet_info->{id},$group_email,'reader');
    }
    die unless $team_auth_sheet_info->{id};
    return $team_auth_sheet_info->{id};
}

#    my $auth = auth_folder();
#    my ($ss) = $auth->items( {
#        'title' => $ss_name,
#        'title-exact' => 'true',
#        'category' => 'spreadsheet',
#    });
#    if (! $ss) {
#        $ss = $auth->add_item( { title => $ss_name, kind => 'spreadsheet' } );
#        warn "Creating '$ss_name' under Auth\n" if $debug;
#    }
#    update_acl($ss,'group',$group_name,'reader');
#    return $ss->alternate;
#}

sub event_folder_id {
    my $event = shift;
    my $team = $event->team;
    my $team_folder_id = team_folder_id($team->google_group);
    die unless $team_folder_id;
    my $event_folder_id = find_a_folder_id($team_folder_id, $event->display_name);
    if ($event_folder_id) {
        warn "EVENT FOLDER ID: $event_folder_id" if $debug;
        return $event_folder_id;
    } else {
        warn "Creating '$event->display_name'\n" if $debug;
        my $event_folder_info = add_a_folder($team_folder_id, $event->display_name);
        die "Can't create event folder" unless $event_folder_info->{id};
        return $event_folder_info->{id};
    }
}

sub round_folder_id {
    my $round = shift;
    my $event = $round->event;
    my $event_folder_id = event_folder_id($event);
    die unless $event_folder_id;
    my $round_folder_id = find_a_folder_id($event_folder_id, $round->display_name);
    if ($round_folder_id) {
        warn "ROUND FOLDER ID: $event_folder_id" if $debug;
        return $round_folder_id;
    } else {
        warn "Creating '$round->display_name' in '$event->display_name'\n" if $debug;
        my $round_folder_info = add_a_folder($event_folder_id, $round->display_name);
        die "Can't create round folder" unless $round_folder_info->{id};
        return $round_folder_info->{id};
    }
}

sub trigger_puzzle_spreadsheet {
    my ($c, $puzzle, $token) = @_;
    my $rootdir = Mojo::Home->new->detect('SolveWith')->to_string;
    my $token_debug_string = $token ? ' with token: ' . $token : '';
    if ($c) {
        $c->app->log->info("Starting SS for " . $puzzle->id . ' from ' . $rootdir . $token_debug_string);
    } else {
        warn ("Starting SS for " . $puzzle->id . ' from ' . $rootdir. $token_debug_string);
    }
    system("$rootdir/script/give-puzzle-ss "  . $puzzle->id . " $token");
}

sub puzzle_spreadsheet {
    my $puzzle = shift;
    my $token = shift;
    my $parent_folder_id;
    my $ss_name;
    warn "in puzzle_spreadsheet";
    if ($token) {
        warn "have token $token";
        $parent_folder_id = token_puzzles_folder_id();
        warn "have folder id $parent_folder_id";
        $ss_name = $puzzle->display_name . " ($token)";
        warn "ss name $ss_name";
    } else {
        my $round = $puzzle->rounds->first;
        if ($round->display_name eq '_catchall') {
            $parent_folder_id = event_folder_id($round->event);
        } else {
            $parent_folder_id = round_folder_id($round);
        }
        $ss_name = $puzzle->display_name;
    }
    die unless $parent_folder_id;
    my $puzzle_sheet_info = find_a_sheet($parent_folder_id, $ss_name);
    if ($puzzle_sheet_info->{weblink}) {
        warn "found sheet: $ss_name , $puzzle_sheet_info->{weblink}" if $debug;
    } else  {
        warn "Creating '" . $ss_name . "' in $parent_folder_id\n" if $debug;
        $puzzle_sheet_info = add_a_sheet($parent_folder_id, $ss_name);
    }
    die unless $puzzle_sheet_info;
    return $puzzle_sheet_info->{weblink};
}

sub give_group_permission {
    my ($id, $email, $role) = @_;
    warn $email;
    my $access_token = get_current_solvewithus_access_token();
    my $req = HTTP::Request->new('POST');
    $req->uri('https://www.googleapis.com/drive/v2/files/' . $id . '/permissions?' . 'sendNotificationEmails=false');
    $req->header('Content-Type' => 'application/json');
    $req->header(Authorization => "Bearer $access_token");
    my $json = Mojo::JSON->new;
    $req->content($json->encode({
        role => $role,
        type => 'group',
        value => $email,
    }));
    warn $req->as_string if $debug;
    warn $req->content if $debug;
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($req);
    if (! $response->is_success()) {
        warn $response->content;
    }
    return;
}

sub make_user_token_puzzle_editor {
    my ($user, $name, $token) = @_;
    my $parent_folder_id = token_puzzles_folder_id();
    my $ss_name = $name . " ($token)";
    my $puzzle_sheet_info = find_a_sheet($parent_folder_id, $ss_name);
    return unless ($puzzle_sheet_info && $puzzle_sheet_info->{id});
    return give_user_permission($puzzle_sheet_info->{id}, $user->google_name,'writer');
}

sub give_user_permission {
    my ($id, $email, $role) = @_;
    warn $email;
    my $access_token = get_current_solvewithus_access_token();
    my $req = HTTP::Request->new('POST');
    $req->uri('https://www.googleapis.com/drive/v2/files/' . $id . '/permissions?' . 'sendNotificationEmails=false');
    $req->header('Content-Type' => 'application/json');
    $req->header(Authorization => "Bearer $access_token");
    my $json = Mojo::JSON->new;
    $req->content($json->encode({
        role => $role,
        type => 'user',
        value => $email,
    }));
    warn $req->uri if $debug;
    warn $req->content if $debug;
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($req);
    if (! $response->is_success()) {
        warn $response->content;
    }
    return;
}

1;
