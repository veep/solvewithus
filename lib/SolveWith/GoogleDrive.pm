package SolveWith::GoogleDrive;
use strict;

use LWP::UserAgent;
use HTTP::Request::Common;
use URI::Escape;
use Mojo::JSON;
use Data::Dump qw/pp/;
use URI;

sub new {
    my ($class,$config)  = @_;
    my $self = { config => $config };

    bless $self, $class;
    $self->_setup();
    return $self;
}

sub _setup {
    my ($self) = @_;
    delete $self->{token};
    my $config = $self->{config};
    my $refresh_token = $config->{solvewithus_refresh_token};
    return unless $refresh_token;
    my $ua =LWP::UserAgent->new();
    my $res = $ua->request(   POST
                              'https://accounts.google.com/o/oauth2/token',
                              [   'refresh_token' => uri_unescape($refresh_token),
                                  'client_id' => $config->{client_id},
                                  'client_secret' => $config->{client_secret},
                                  'grant_type' => 'refresh_token',
                              ],
                          );
    if ($res->is_success) {
        my $content = Mojo::JSON->new->decode($res->content);
        $self->{token} = $content->{access_token};
    }
}

sub find_root_folder {
    my ($self, $name) = @_;
    my $clause = q{'root' in parents and title='} . $name . q{' and mimeType = 'application/vnd.google-apps.folder'};
    warn $clause;
    my $ua =LWP::UserAgent->new();
    $ua->default_header( 'Authorization' => "Bearer $self->{token}");
    my $uri = URI->new('https://www.googleapis.com/drive/v2/files');
    $uri->query_form( q => $clause );
    my $res = $ua->get( $uri );
    warn pp [$res->is_success, $res->content];
}

1;
