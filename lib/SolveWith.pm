package SolveWith;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;
  $self->secret("***REMOVED***");

  # Routes
  my $r = $self->routes;

  $r->route('/')->to(controller => 'login', action => 'homepage');
  $r->route('/event')->name('events')->to(controller => 'event', action => 'all');
  $r->route('/event/:id', id => qr/\d+/)->name('event')->to(controller => 'event', action => 'single');
  $r->route('/puzzle/:id', id => qr/\d+/)->name('puzzle')->to(controller => 'puzzle', action => 'single');
  $r->route('/updates/:type/:id/:last', id => qr/\d+/, type => ['event','puzzle'])->name('updates')->to(controller => 'updates', action => 'getnew');
}

1;
