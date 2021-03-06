package SolveWith;
use Mojo::Base 'Mojolicious';
use Net::OAuth2::Client;
use JSON qw/decode_json/;
use SolveWith::Schema;
use Data::Dump qw/ddx/;
use CHI;


my $code_version = 0;           # 0 means "always return scalar time"


my $config;

has schema => sub {
    my $db_file = 'db/puzzles.db';
    if ($config->{db_file}) {
        $db_file = $config->{db_file};
    }
    return SolveWith::Schema->connect('dbi:SQLite:' . $db_file,
                                      undef, undef, {sqlite_unicode => 1});
};
# This method will run once at server start
sub startup {
  my $self = shift;
  if ($self->mode eq 'testing') {
      if ($ENV{MOJO_TESTING_CONFIG} && -r $ENV{MOJO_TESTING_CONFIG}) {
          $config = $self->plugin('Config',{file => $ENV{MOJO_TESTING_CONFIG}});
      } else {
          die "need testing config file in MOJO_TESTING_CONFIG";
      }
  } else {
      $config = $self->plugin('Config');
  }
  $self->helper(db => sub { $self->app->schema });

  eval {
      $self->secret($self->config->{secret_phrase});
  };
  if ($@) {
      $self->secrets([$self->config->{secret_phrase}]);
  }
  $self->sessions->default_expiration(3000000);

  if ($self->mode eq 'production') {
      my $cmd = 'cd ' . Mojo::Home->new->detect('SolveWith')->to_string .
                ' && git rev-parse --short HEAD ';
      my $vcrev = `$cmd`;
      if ($vcrev =~ m,(\w+)\W*$,) {
          $code_version=$1;
          warn "Code version: $code_version\n";
      }
  } else {
      $self->cache->clear();
  }

  $self->app->hook (
      before_dispatch => sub {
          my $c = shift;
          if ($c->app->mode eq 'testing' && $c->cookie('test_https')) {
              $c->req->url->base->scheme('https');
          } elsif ($c->req->headers->header('X-Forwarded-Proto') || 'none' eq 'https') {
              $c->req->url->base->scheme('https');
          }
      }
  );

  # Routes
  my $r = $self->routes;

  $r->route('/')->to(controller => 'login', action => 'homepage');
  $r->route('/welcome')->to(controller => 'login', action => 'welcome');
  $r->route('/thanks')->to(controller => 'login', action => 'thanks');
  $r->route('/login')->to(controller => 'login', action => 'homepage');
  $r->route('/reset')->name('reset')->to(controller => 'login', action => 'reset');

  $r->route('/solvepad')->name('solvepad_intro')->to(controller => 'solvepad', action => 'intro');
  $r->route('/solvepad/home')->name('solvepad')->to(controller => 'solvepad', action => 'main');
  $r->route('/solvepad/logout')->name('solvepad_logout')->to(controller => 'solvepad', action => 'logout');
  $r->route('/solvepad/create_puzzle')->name('solvepad_create')->
      to(controller => 'solvepad', action => 'create');
  $r->route('/solvepad/:id', id => qr/\d+/)->name('solvepad_by_id')->
      to(controller => 'solvepad', action => 'puzzle');
  $r->route('/solvepad/close/:id', id => qr/\d+/)->name('solvepad_close')->
      to(controller => 'solvepad', action => 'close_open');
  $r->route('/solvepad/reopen/:id', id => qr/\d+/)->name('solvepad_reopen')->
      to(controller => 'solvepad', action => 'close_open');
  $r->route('/solvepad_updates/:id', id => qr/\d+/)->name('solvepad_updates')->
      to(controller => 'solvepad', action => 'updates');
  $r->route('/solvepad/share/:key', key => qr/\d+-\w+/)->name('solvepad_share')->
      to(controller => 'solvepad', action => 'share');
  $r->route('/solvepad/recommend/:key', key => qr/\d+-\w+/)->name('solvepad_recommend')->
      to(controller => 'solvepad', action => 'recommend');
  $r->route('/replay/:key', key => qr/\d+-\w+/)->name('solvepad_replay')->
      to(controller => 'solvepad', action => 'replay');
  $r->route('/replay_updates/:key', key => qr/\d+-\w+/)->name('solvepad_replay_updates')->
      to(controller => 'solvepad', action => 'replay_updates');

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

  $r->route('/puzzle/direct/:token')->name('puzzle_direct')->to(controller => 'puzzle', action => 'direct');
  $r->route('/puzzle/:id', id => qr/\d+/)->name('puzzle')->to(controller => 'puzzle', action => 'single');
  $r->route('/puzzle/:id/ss', id => qr/\d+/)->name('puzzle_ss')->to(controller => 'puzzle', action => 'spreadsheet_url');
  $r->route('/puzzle/ss_by_token/:token')->name('puzzle_ss_direct')->to(controller => 'puzzle', action => 'spreadsheet_url_direct');
  $r->route('/puzzle/modal')->to(controller => 'puzzle', action => 'modal');
  $r->route('/puzzle/infomodal/:id', id=> qr/\d+/)->name('infomodal')->
             to(controller => 'puzzle', action => 'infomodal');
  $r->route('/puzzle/infomodal/:id/:token', id=> qr/\d+/)->name('infomodal_token')->
             to(controller => 'puzzle', action => 'infomodal');
  $r->route('/event/infomodal/:id', id=> qr/\d+/)->name('eventinfomodal')->
             to(controller => 'event', action => 'infomodal');

  $r->route('/testsolve_url')->to(controller => 'puzzle', action => 'testsolve_create');

  $r->route('/updates/:type/:id/:last', id => qr/\d+/, type => ['event','puzzle'])
      ->name('updates')->to(controller => 'updates', action => 'getnew');

  $r->route('/stream/event/:event_id/:last', event_id => qr/\d+/)
      ->name('stream')->to(controller => 'updates', action => 'getstream');
  $r->route('/stream/event/:event_id/puzzle/:puzzle_id/:last', event_id => qr/\d+/, puzzle_id => qr/\d+/)
      ->name('combined stream')->to(controller => 'updates', action => 'getstream');
  $r->route('/stream/puzzle/:puzzle_id/token/:token/:last', puzzle_id => qr/\d+/)
      ->name('puzzle stream')->to(controller => 'updates', action => 'getstream');

  $r->route('/chat')->to(controller => 'updates', action => 'chat');
  $r->route('/chat/unstick')->to(controller => 'updates', action => 'unstick');

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

  $self->hook( before_dispatch => sub {
                   my $self = shift;
                   return if $self->req->url->path eq '/oauth2callback';
                   return if $self->res->code;
                   my $onwelcome = (
                       $self->req->url->path eq '/welcome'
                       || $self->req->url->path eq '/solvepad'
                       || $self->req->url->path eq '/testsolve_url'
                       || $self->req->url->path =~ q,^/replay,
                   );
                   return if $onwelcome;
                   if ($self->app->mode eq 'testing') {
                       if ($self->cookie('test_userid')) {
                           $self->session->{token} = $self->cookie('test_userid');
                           $self->session->{userid} = $self->cookie('test_userid');
                       }
                   }
                   my $notoken = (not $self->session->{token} or length($self->session->{token}) == 0);
                   my $onroot = $self->req->url->path eq '/';
                   return $self->redirect_to('/welcome') if $notoken and $onroot;
                   if ( $notoken ) {
                       my $scope;
                       if ($self->req->url->path =~ m,^/solvepad/,) {
                           $scope = 'solvepad_scope';
                       }
                       my $url = oauth_client($self, 1, $scope )->authorize;
                       $self->session->{nexturl} = $self->req->url->path;
                       return $self->redirect_to($url);
                   }
               });
}

sub oauth_client {
    my ($self,$ws,$scope_key) = @_;
    my $scope = $self->config->{scope};
    if ($scope_key) {
        if ($self->config->{$scope_key}) {
            $scope = $self->config->{$scope_key};
        }
    }
    my $cl = Net::OAuth2::Client->new(
        $self->config->{client_id},
        $self->config->{client_secret},
        site => 'https://www.googleapis.com',
        authorize_url => 'https://accounts.google.com/o/oauth2/auth',
        access_token_url => 'https://accounts.google.com/o/oauth2/token',
        scope => $scope,
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
#        $app_cache= CHI->new( driver => 'FastMmap', root_dir => '/tmp/' . $app->mode, cache_size => '50m');
#        $app_cache= CHI->new( driver => 'Memory', cache_size => '10m', global => 1 );
        $app_cache= CHI->new( driver => 'File', root_dir => '/tmp/' . $app->mode . '/tree');
    }
    return $app_cache;
}

sub code_version {
    return $code_version || scalar time;
}

1;
