use common::sense;
use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use FindBin;
use lib "$FindBin::Bin/../lib";
use_ok 'SolveWith';

my $t = Test::Mojo->new('SolveWith');
$t->get_ok('/')->status_is(200);
TODO: {
    local $TODO= "Figure out text";
    $t->get_ok('/')->content_like(qr/Mojolicious/i);
};

done_testing;
