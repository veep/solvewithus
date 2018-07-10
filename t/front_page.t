use common::sense;
use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/../lib";

my $t = Test::Mojo->new('SolveWith');

$t->get_ok('/')
    ->status_is(302)
    ->header_like(Location => qr,/welcome$,);
$t->get_ok('/welcome')
    ->status_is(200)
    ->content_like(qr/Welcome to Solvewith.us/);

done_testing;
