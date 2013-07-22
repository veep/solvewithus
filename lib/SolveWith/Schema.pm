package SolveWith::Schema;
use base qw/DBIx::Class::Schema/;
__PACKAGE__->load_namespaces();

use DBIx::Class::QueryProfiler;

# sub connection {
#     my $self = shift;
#     my $response = $self->next::method(@_);
#     $response->storage->auto_savepoint(1);
#     $response->storage->debug(1);
#     $response->storage->debugobj(DBIx::Class::QueryProfiler->new);
#     $response->storage->debugfh(IO::File->new('/tmp/trace.out', 'w'));
#     return $response;
# }

1;

