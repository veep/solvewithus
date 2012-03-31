use common::sense;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

system("cd $FindBin::Bin/..;  echo .schema | sqlite3 puzzles.db > /tmp/tmpdb  ;rm -f  test.db*;echo '.read /tmp/tmpdb'| sqlite3 test.db");
use_ok 'SolveWith::Schema';
my $schema = SolveWith::Schema->connect('dbi:SQLite:' . $FindBin::Bin . '/../test.db');
ok($schema, "We got a schema");

my $test_user_name = 'testuser@prestemon.com';
{   # purge, then setup testuser.
    my $user = $schema->resultset('User')->search({ google_name => $test_user_name })->first;
    $user->delete if $user;
    $user = $schema->resultset('User')->create({
        google_name => $test_user_name,
        display_name => 'Automated Test User',
        google_id => '123',
    });
    ok ($user->id,"User has an id");
    is ($user->display_name, "Automated Test User", 'getter for user\'s display_name works');
}

my $test_team_name = 'Automated Test Team Name';
{
    my $team = $schema->resultset('Team')->search({ display_name => $test_team_name })->first;
    $team->delete if $team;
    $team = $schema->resultset('Team')->create({
        display_name => $test_team_name,
        google_group => 'testgroupforsolvewith',
    });
    ok ($team->id,"Team has an id");
    is ($team->display_name, "Automated Test Team Name", 'getter for user\'s display_name works');
}

{
    my $user = $schema->resultset('User')->search({ google_name => $test_user_name })->first;
    is (scalar $user->teams,0,'No teams');
    my $team = $schema->resultset('Team')->search({ display_name => $test_team_name })->first;
    is (ref($team),'SolveWith::Schema::Result::Team', 'team is right type');
    $user->add_to_teams($team);
    is (scalar $user->teams,1,'On one teams');
    is ($user->teams->first->id, $team->id, "Added team is on the user's team list");
    is (scalar $team->users,1,'Team has one user');
    $team->remove_from_users($user);
    is (scalar $user->teams,0,'No longer on the team');
    is (scalar $team->users,0,'No longer on the team');
    $team->add_to_users($user);
    is (scalar $user->teams,1,'back one team after team adds');
}

{
    my $team = $schema->resultset('Team')->search({ display_name => $test_team_name })->first;
    my $event = $team->create_related('events', {display_name => 'event 1', state=>'open'});
    ok ($event, "event created");
    is ($event->team->id, $team->id, "Event has right parent");
    is ($event->team_id, $team->id, "Event has right parent");
    is ($event->state, 'open', "Event is open");
}
{
     my $team = $schema->resultset('Team')->search({ display_name => $test_team_name })->first;
     my $event = $team->create_related('events', {display_name => 'event 1', state=>'open'});
     my $round = $event->create_related('rounds', {display_name => 'round 1', state=>'open'});
     ok ($round, "round created");
     is ($round->display_name, 'round 1', "round name right");
     is ($round->event->display_name, 'event 1', "event name right");
     is ($round->event->team->display_name, 'Automated Test Team Name', 'all the way back from round to team works');
     my $puzzle = $round->add_to_puzzles({ display_name => 'puzzle 1'},{type => 'meta'});
     ok ($puzzle, "puzzle created");
     is ($puzzle->display_name, 'puzzle 1', 'puzzle has right name');
     is ($puzzle->rounds->first->display_name,'round 1', 'can link from puzzle to round');
     my $event_chat = $event->chat;
     is (scalar $event_chat->messages,1,'one message in new event chat');
     my $puzzle_chat = $event->chat;
     is (scalar $puzzle_chat->messages,1,'one message in new puzzle chat');
}

{
    my $team = $schema->resultset('Team')->search({ display_name => $test_team_name })->first;
    my $event = $team->create_related('events', {display_name => 'event 1', state=>'open'});
    $event->spreadsheet('http://prestemon.com/');
    is ($event->spreadsheet, 'http://prestemon.com/', "spreadsheet works");
    $event->spreadsheet('http://puzzles.prestemon.com/');
    is ($event->spreadsheet, 'http://puzzles.prestemon.com/', "2nd spreadsheet works");
    
}
done_testing;
