package SolveWith::Spreadsheet;
use Net::Google::DocumentsList;
use Moose;

has 'ssname' => ( isa => 'Str', is => 'ro');
has 'group' => ( isa => 'Str', is => 'ro', required => 1);
has 'folder' => ( isa => 'Str', is => 'ro');
has 'mode' => (isa => 'Str' #subtype ( 'Str' => where {$_ eq 'reader' or $_ eq 'writer'})
                 , is => 'ro', default => 'reader');
has 'url' => (isa => 'Str', is => 'ro', builder => '_make_in_google');

sub _make_in_google {
    my $self = shift;
    my $service = Net::Google::DocumentsList->new(
        username => '***REMOVED***',
        password => '***REMOVED***',
    );

    my $folder = $service;
    foreach my $subfolder_name ('SolveWith.Us', $self->group, $self->folder) {
        next unless (defined $subfolder_name and length $subfolder_name);
        my ($subfolder) = $folder->items( {
            'title' => $subfolder_name,
            'title-exact' => 'true',
            'category' => 'folder',
        }) ;
        if (! $subfolder) {
            $subfolder = $folder->add_folder( { title => $subfolder_name } );
        }
        if ($subfolder) {
            $folder = $subfolder;
            if ($subfolder_name ne 'SolveWith.Us') {
                update_acl($folder,'group',$self->group,'reader');
            }
        }
    }

    my $spreadsheet = $folder->add_item(
        {
            title => ( $self->ssname ?
                           $self->ssname :
                               'auth check for ' . $self->group,
                   ),
            kind => 'spreadsheet',
        }
    );
    update_acl($spreadsheet,'group',$self->group,'writer');
    return $spreadsheet->alternate;
}

sub update_acl {
    my ($item, $scope_type, $scope_value, $role) = @_;
    
    eval {
        my @acls = $item->acls;
        foreach my $acl (@acls) {
            if ($acl->scope->{type} eq  $scope_type
                && $acl->scope->{value} eq $scope_value) {
                if ($role eq 'reader' and $acl->role ne 'reader') {
                    warn 'not downgrading to reader';
                } else {
                    $acl->role($role);
                }
                return;
            }
        }
        $item->add_acl(
            {
                role => $role,
                scope => {
                    type => $scope_type,
                    value => $scope_value,
                }
            }
        );
    }
}

1;
