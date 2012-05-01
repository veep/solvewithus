package SolveWith;
use Mojo::Base 'Mojolicious';
use Net::OAuth2::Client;
use JSON qw/decode_json/;
use SolveWith::Schema;

has schema => sub {
  return SolveWith::Schema->connect('dbi:SQLite:puzzles.db');
};

# This method will run once at server start
sub startup {
  my $self = shift;
  $self->helper(db => sub { $self->app->schema });
  $self->plugin('Config');
  $self->secret("***REMOVED***");

  # Routes
  my $r = $self->routes;

  $r->route('/')->to(controller => 'login', action => 'homepage');
  $r->route('/welcome')->to(controller => 'login', action => 'welcome');
  $r->route('/login')->to(controller => 'login', action => 'homepage');
  $r->route('/event')->name('events')->to(controller => 'event', action => 'all');
  $r->route('/event/:id', id => qr/\d+/)->name('event')->to(controller => 'event', action => 'single');
  $r->route('/puzzle/:id', id => qr/\d+/)->name('puzzle')->to(controller => 'puzzle', action => 'single');
  $r->route('/updates/:type/:id/:last', id => qr/\d+/, type => ['event','puzzle'])
      ->name('updates')->to(controller => 'updates', action => 'getnew');
  $r->route('/chat')->to(controller => 'updates', action => 'chat');

  $r->get('/oauth2callback' => sub {
              my $self = shift;
              my $google =  oauth_client($self,1)->get_access_token($self->param('code'));
              $self->session->{token} = $google->access_token;
              $self->session->{last_google_auth} = scalar time;
              my $user_info_response = $google->get('/oauth2/v1/userinfo');
              if ($user_info_response->is_success) {
                  my $user_info = decode_json( $user_info_response->decoded_content);
                  if (my $user = $self->db->resultset('User')->find_or_create( {google_id => $user_info->{id}})) {
                      $user->display_name($user_info->{name});
                      $user->google_name($user_info->{email});
                      $user->update;
                      $self->session->{userid} = $user->id;
                  }
                  use Data::Dump qw/ddx/; ddx $self->session;
              }

              my $nexturl = '/';
              if (defined $self->session->{nexturl}) {
                  $nexturl = $self->session->{nexturl};
                  delete $self->session->{nexturl};
              }
              $self->redirect_to($nexturl);
          });

  $self->hook( after_static_dispatch => sub {
                   my $self = shift;
                   return if $self->req->url->path eq '/oauth2callback';
                   my $onwelcome = $self->req->url->path eq '/welcome';
                   my $notoken = (not $self->session->{token} or length($self->session->{token}) == 0);
                   my $onroot = $self->req->url->path eq '/';
                   return $self->redirect_to('/welcome') if $notoken and $onroot;
                   return if $onwelcome;
                   if ( $notoken ) {
                       my $url = oauth_client($self,1)->authorize_url;
                       $self->session->{nexturl} = $self->req->url->path;
                       return $self->redirect_to($url);
                   }
               });
}

sub oauth_client {
    my ($self,$ws) = @_;
    my $cl = Net::OAuth2::Client->new(
        $self->stash->{config}->{client_id},
        $self->stash->{config}->{client_secret},
        site => 'https://www.googleapis.com',
        authorize_url => 'https://accounts.google.com/o/oauth2/auth',
        access_token_url => 'https://accounts.google.com/o/oauth2/token',
        scope => $self->stash->{config}->{scope},
    );

    if ($ws) {
        $cl = $cl->web_server( redirect_uri => 'http://solvewith.us/oauth2callback' );
    }
    return $cl;
}

1;
