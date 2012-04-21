package SolveWith::Spreadsheet;
use Net::Google::DocumentsList;
use Moose;

has 'ssname' => ( isa => 'Str', is => 'ro');
has 'group' => ( isa => 'Str', is => 'ro', required => 1);
has 'mode' => (isa => 'Str' #subtype ( 'Str' => where {$_ eq 'reader' or $_ eq 'writer'})
                 , is => 'ro', default => 'reader');
has 'url' => (isa => 'Str', is => 'ro', builder => '_make_in_google');

sub _make_in_google {
    my $self = shift;
    my $service = Net::Google::DocumentsList->new(
        username => '***REMOVED***',
        password => '***REMOVED***',
    );

    my $spreadsheet = $service->add_item(
        {
            title => ( $self->ssname ?
                           $self->ssname :
                               'auth check for ' . $self->group,
                   ),
            kind => 'spreadsheet',
        }
    );
    use Data::Dump qw/pp/;
    $spreadsheet->add_acl(
        {
            role => $self->mode,
            scope => {
                type => 'group',
                value => $self->group,
            }
        }
    );
    return $spreadsheet->alternate;
}
1;
