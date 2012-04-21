#!/usr/bin/env perl

use common::sense;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('SolveWith');

$t->get_ok('/')->status_is(200);   #->text_is('div#message' => 'Hello!');

  # $t->post_form_ok('/search.json' => {q => 'Perl'})
  #   ->status_is(200)
  #   ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  #   ->header_isnt('X-Bender' => 'Bite my shiny metal ass!');
  #   ->json_is('/results/4/title' => 'Perl rocks!');

  # $t->websocket_ok('/echo')
  #   ->send_message_ok('hello')
  #   ->message_is('echo: hello')
  #   ->finish_ok;

done_testing;
