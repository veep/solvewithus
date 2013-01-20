package SolveWith;
use Mojo::Base 'Mojolicious';
use Net::OAuth2::Client;
use JSON qw/decode_json/;
use SolveWith::Schema;
use Data::Dump qw/ddx/;
use CHI;

has schema => sub {
  return SolveWith::Schema->connect('dbi:SQLite:puzzles.db', undef, undef, {sqlite_unicode => 1});
};

my $code_version = 0;           # 0 means "always return scalar time"


# This method will run once at server start
sub startup {
  my $self = shift;
  $self->helper(db => sub { $self->app->schema });
  $self->plugin('Config');
  $self->secret("***REMOVED***");
  $self->sessions->default_expiration(3000000);

  if ($self->mode eq 'production') {
      my $cmd = '/usr/bin/svnversion ' . $self->static->root;
      my $svnrev = `$cmd`;
      if ($svnrev =~ m,(\d+)\D*$,) {
          $code_version=$1;
          warn "Code version: $code_version\n";
      }
  }
  $self->cache->clear();

  # Routes
  my $r = $self->routes;

  $r->route('/')->to(controller => 'login', action => 'homepage');
  $r->route('/welcome')->to(controller => 'login', action => 'welcome');
  $r->route('/thanks')->to(controller => 'login', action => 'thanks');
  $r->route('/login')->to(controller => 'login', action => 'homepage');
  $r->route('/reset')->name('reset')->to(controller => 'login', action => 'reset');

  $r->route('/event')->name('events')->to(controller => 'event', action => 'all');
  $r->route('/event/add')->name('addevent')->to(controller => 'event', action => 'add');
  $r->route('/event/refresh')->to(controller => 'event', action => 'refresh');
  $r->route('/event/refresh-puzzle-table')->to(controller => 'event', action => 'puzzle_table');
  $r->route('/event/modal')->to(controller => 'event', action => 'modal');

  $r->route('/event/:id', id => qr/\d+/)->name('event')->to(controller => 'event', action => 'single');
  $r->route('/event/status/:id', id => qr/\d+/)->
             name('event_status')->to(controller => 'event', action => 'status');
  $r->route('/event/status/:id/:puzzle_id', id => qr/\d+/, puzzle_id => qr/\d+/)->
             name('event_status')->to(controller => 'event', action => 'status');

  $r->route('/puzzle/:id', id => qr/\d+/)->name('puzzle')->to(controller => 'puzzle', action => 'single');
  $r->route('/puzzle/:id/ss', id => qr/\d+/)->name('puzzle_ss')->to(controller => 'puzzle', action => 'spreadsheet_url');
  $r->route('/puzzle/modal')->to(controller => 'puzzle', action => 'modal');
  $r->route('/puzzle/infomodal/:id', id=> qr/\d+/)->name('infomodal')->
             to(controller => 'puzzle', action => 'infomodal');

  $r->route('/updates/:type/:id/:last', id => qr/\d+/, type => ['event','puzzle'])
      ->name('updates')->to(controller => 'updates', action => 'getnew');

  $r->route('/stream/event/:event_id/:last', event_id => qr/\d+/)
      ->name('stream')->to(controller => 'updates', action => 'getstream');
  $r->route('/stream/event/:event_id/puzzle/:puzzle_id/:last', event_id => qr/\d+/, puzzle_id => qr/\d+/)
      ->name('combined stream')->to(controller => 'updates', action => 'getstream');

  $r->route('/chat')->to(controller => 'updates', action => 'chat');

  $r->get('/oauth2callback' => sub {
              my $self = shift;
              my $user_info_response;
              eval {
                  my $google =  oauth_client($self,1)->get_access_token($self->param('code'));
                  $self->session->{token} = $google->access_token;
                  $self->session->{last_google_auth} = scalar time;
                  $user_info_response = $google->get('/oauth2/v1/userinfo');
              };
              warn $@ if $@;
              if ($user_info_response &&  $user_info_response->is_success) {
                  my $user_info = decode_json( $user_info_response->decoded_content);
                  ddx $user_info;
                  die unless $user_info->{id};
                  if (my $user = $self->db->resultset('User')->find_or_create( {google_id => $user_info->{id}})) {
                      $user->display_name($user_info->{name});
                      $user->google_name($user_info->{email});
                      $user->update;
                      $self->session->{userid} = $user->id;
                  }
                  ddx $self->session;
              } else {
                  warn "Going to welcome";
                  return $self->redirect_to('/welcome');
              }

              my $nexturl = '/';
              if (defined $self->session->{nexturl}) {
                  $nexturl = $self->session->{nexturl};
                  delete $self->session->{nexturl};
              }
              return $self->redirect_to($nexturl);
          });

  $self->hook( after_static_dispatch => sub {
                   my $self = shift;
                   return if $self->req->url->path eq '/oauth2callback';
                   return if $self->res->code;
                   my $onwelcome = $self->req->url->path eq '/welcome';
                   return if $onwelcome;
                   my $notoken = (not $self->session->{token} or length($self->session->{token}) == 0);
                   my $onroot = $self->req->url->path eq '/';
                   return $self->redirect_to('/welcome') if $notoken and $onroot;
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
        my $host = $self->req->url->to_abs->host || 'solvewith.us';
        $cl = $cl->web_server( redirect_uri => 'http://' . $host . '/oauth2callback' );
    }
    return $cl;
}

my $app_cache = undef;
sub cache {
    if (! $app_cache) {
        my $app = shift;
#        $app_cache= CHI->new( driver => 'FastMmap', root_dir => '/tmp/' . $app->mode, cache_size => '200m');
#        $app_cache= CHI->new( driver => 'Memory', cache_size => '10m', global => 1 );
        $app_cache= CHI->new( driver => 'File', root_dir => '/tmp/' . $app->mode . '/tree');
    }
    return $app_cache;
}

sub code_version {
    return $code_version || scalar time;
}

1;
