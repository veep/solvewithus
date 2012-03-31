use common::sense;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";


system("cd $FindBin::Bin/..; rm -f test.db*; echo .schema | sqlite3 puzzles.db  |sqlite3 test.db");

use_ok 'SolveWith::Schema';
my $schema = SolveWith::Schema->connect('dbi:SQLite:' . $FindBin::Bin . '/../test.db');
ok($schema, "We got a schema");

my $test_user_name = 'testuser@prestemon.com';
my $user = $schema->resultset('User')->create({ google_name => $test_user_name, display_name => 'foo' });
ok($user);
$user->add_to_teams({display_name => 'team 7'})
    ->create_related('events', {display_name => 'event 17'})
    ->create_related('rounds', {display_name => 'round 12'})
    ->add_to_puzzles({display_name => 'puzzle 3'});

my $tree = $user->get_puzzle_tree;

is (scalar @$tree, 1, "One team returned");
is ($tree->[0]->{team}->display_name , 'team 7', 'tree has team 7 as only team');
is (scalar @{$tree->[0]->{events}}, 1, 'One event returned');
is ($tree->[0]->{events}->[0]->{event}->display_name , 'event 17', 'tree has event 17 as only event');
is (scalar @{$tree->[0]->{events}->[0]->{rounds}}, 1, 'One round returned');
is ($tree->[0]->{events}->[0]->{rounds}->[0]->{round}->display_name , 'round 12', 'tree has round 12 as only round');
is (scalar @{$tree->[0]->{events}->[0]->{rounds}->[0]->{puzzles}}, 1, 'One puzzle returned');
is ($tree->[0]->{events}->[0]->{rounds}->[0]->{puzzles}->[0]->{puzzle}->display_name , 'puzzle 3', 'tree has puzzle 3 as only round');


done_testing;
