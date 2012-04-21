package SolveWith::Auth;

use Any::Moose;
with 'Net::Google::DataAPI::Role::Auth';
has access_token => ( is => 'rw', isa => 'Str', required => 1);

sub sign_request {
    my ($self, $req, $host) = @_;
#    warn "Signing " . $req->uri . ' ' . $self->access_token;
    $host ||= $req->uri->host;
    $req->header(Authorization => "Bearer " . $self->access_token);
    return $req;
}

sub make_request {
    my ($self, $url) = @_;
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new('GET',$url);
    $self->sign_request($req);
    my $response= $ua->request($req);
    use Data::Dump qw/pp/;
    return $response;
}

1;
