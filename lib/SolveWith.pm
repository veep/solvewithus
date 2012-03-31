package SolveWith;
use Mojo::Base 'Mojolicious';
use Net::OAuth2::Client;

# This method will run once at server start
sub startup {
  my $self = shift;
  $self->plugin('Config');
  $self->secret("***REMOVED***");

  # Routes
  my $r = $self->routes;

  $r->route('/')->to(controller => 'login', action => 'homepage');
  $r->route('/event')->name('events')->to(controller => 'event', action => 'all');
  $r->route('/event/:id', id => qr/\d+/)->name('event')->to(controller => 'event', action => 'single');
  $r->route('/puzzle/:id', id => qr/\d+/)->name('puzzle')->to(controller => 'puzzle', action => 'single');
  $r->route('/updates/:type/:id/:last', id => qr/\d+/, type => ['event','puzzle'])
      ->name('updates')->to(controller => 'updates', action => 'getnew');

  $r->get('/oauth2callback' => sub {
              my $self = shift;
              my $google =  oauth_client($self,1)->get_access_token($self->param('code'));
              $self->session->{token} = $google->access_token;
              $self->session->{last_google_auth} = scalar time;
              my $nexturl = '/';
              if (defined $self->session->{nexturl}) {
                  $nexturl = $self->session->{nexturl};
                  delete $self->session->{nexturl};
              }
              warn "Going to $nexturl";
              $self->redirect_to($nexturl);
          });

  $self->hook( after_static_dispatch => sub {
                   my $self = shift;
                   use Data::Dump qw/ddx/; ddx $self->session;
                   return if $self->req->url->path eq '/oauth2callback';
                   if (not $self->session->{token} or
                           length($self->session->{token}) == 0 or
                               time - $self->session->{last_google_auth} > 300
                           ) {
                       my $url = oauth_client($self,1)->authorize_url;
                       $self->session->{nexturl} = $self->req->url->path;
                       warn $url;
                       return $self->redirect_to($url);
                   }
               });
}

sub oauth_client {
    my ($self,$ws) = @_;
    my $cl = Net::OAuth2::Client->new(
        $self->stash->{config}->{client_id},
        $self->stash->{config}->{client_secret},
        site => 'https://accounts.google.com',
        authorize_path => '/o/oauth2/auth',
        access_token_path => '/o/oauth2/token',
        scope => $self->stash->{config}->{scope});
    if ($ws) {
        $cl = $cl->web_server( redirect_uri => 'http://solvewith.us/oauth2callback' );
    }
    return $cl;
}

1;
