use Mojo::Base -strict;

use Test::More tests => 4;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/../lib";
use_ok 'SolveWith';

my $t = Test::Mojo->new('SolveWith');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);
