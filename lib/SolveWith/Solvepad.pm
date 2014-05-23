package SolveWith::Solvepad;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw/md5_sum/;
use Mojo::UserAgent;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_FD ZMQ_PUB ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_DONTWAIT);
use Mojo::IOLoop;
use Time::HiRes;

sub main {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('/welcome');
    }
    my @open_puzzles;
    for my $puzzle (
        $self->db->resultset('SolvepadPuzzle')->search(
            { user_id => $user->id }
        )->all()
    ) {
        push @open_puzzles, $puzzle;
    }
    $self->stash('open_puzzles' => \@open_puzzles);
}

sub puzzle {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('/solvepad');
    }
    my $puzzle_id = $self->param('id');
    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find($puzzle_id);
    if (! $puzzle or $puzzle->user_id != $user->id) {
        $self->redirect_to('/solvepad');
    }
    $self->stash('puzzle' => $puzzle);
}

sub create {
    my ($self) = @_;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('/solvepad');
    }

    my $title = $self->param('PuzzleTitle');
    my $url = $self->param('PuzzleURL');

    if (! $url) {
        $self->redirect_to('/solvepad');
    }

    my $user_id = $user->id;

    my $ua = Mojo::UserAgent->new;
    my $body = $ua->get($url)->res->body;
    if (! $body) {
        $self->redirect_to('/solvepad');
    }

    my $checksum = md5_sum($body);
    my $source = $self->db->resultset('SolvepadSource')->search(
        { checksum => $checksum }
    )->first();

    if (! $source) {
        $source = $self->db->resultset('SolvepadSource')->create(
            {
                url => $url,
                checksum => $checksum,
            }
        );
    }

    my $rootdir = Mojo::Home->new->detect('SolveWith')->to_string;
    $self->app->log->info("Starting find-hotspots for " . $url . ' from ' . $rootdir);
    system("$rootdir/script/find-hotspots " . $source->id);

    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find_or_create(
        {
            user_id => $user->id,
            source_id => $source->id,
        }
    );

    if ($title) {
        $puzzle->title($title);
        $puzzle->update;
    }
    $self->redirect_to('/solvepad');
}

sub updates {
    my $self = shift;
    my $puzzle_id = $self->param('id');
    return unless $puzzle_id;
    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find($puzzle_id);
    return unless $puzzle;

    my $user = $self->db->resultset('User')->find($self->session->{userid});


    my $last_change_seen = 0;
    my %state;
    my $last_ts = 0;
    my $json = Mojo::JSON->new();


    for my $hotspot ( $self->db->resultset('SolvepadHotspot')->search(
        {
            source_id => $puzzle->solvepad_source->id,
        },
    )->all) {
        my $id = $hotspot->id;
        $state{$id} =
        { shape => $hotspot->shape,
          state => 'clear',
          id => $id,
          up => $hotspot->up,
          down => $hotspot->down,
          left => $hotspot->left,
          right => $hotspot->right,
      };
        ($state{$id}{minx}, $state{$id}{miny},
         $state{$id}{maxx}, $state{$id}{maxy}) = split(',',$hotspot->shape_data);
    }

    $self->send_message(
        $json->encode({ values => [values %state]})
    );

    send_state_if_updated($self,\%state, $puzzle_id, \$last_ts, $last_change_seen);

    my $zmq_context = zmq_init();
    my $subscriber = zmq_socket($zmq_context, ZMQ_SUB);
    zmq_connect($subscriber, 'tcp://localhost:5556');
    my $subscribe_fd = zmq_getsockopt( $subscriber, ZMQ_FD );
    zmq_setsockopt($subscriber, ZMQ_SUBSCRIBE, "$puzzle_id");
    my $publisher = zmq_socket($zmq_context, ZMQ_PUB);
    zmq_connect($publisher, 'tcp://localhost:5557');

    $self->on(
        message => sub {
            my $message = $_[1];
            my $message_data = $json->decode($message);
            warn keys %$message_data; warn values %$message_data;
            if( exists $message_data->{id}
                && exists $message_data->{to}
                && exists $message_data->{from}
            ) {
                my $hist = $self->db->resultset('SolvepadHistory')->find_or_create(
                    {
                        solvepad_puzzle => $puzzle,
                        ts => (scalar Time::HiRes::time),
                        solvepad_user => $user,
                        hotspot_id => $message_data->{id},
                        older => $message_data->{from},
                        newer => $message_data->{to},
                        type => 'change',
                  }
                );
                if (exists $message_data->{change_number}) {
                    $last_change_seen = $message_data->{change_number};
                }
#                warn "sending $puzzle_id " . ($hist->ts);
                zmq_sendmsg($publisher,"$puzzle_id " . $hist->ts);
            }
        }
    );

   my $watch =  Mojo::IOLoop->recurring( 0.2 => sub 
       {
#           warn "checking";
           my $msg = zmq_recvmsg($subscriber, ZMQ_DONTWAIT);
           if ($msg) {
               warn zmq_msg_data($msg);
               zmq_msg_close($msg);
               send_state_if_updated($self,\%state, $puzzle_id, \$last_ts, $last_change_seen);
           }

       }
   );


   $self->on(
       finish => sub {
           warn "Destroying";
           zmq_close($publisher);
           zmq_close($subscriber);
#           zmq_ctx_destroy($zmq_context);
           Mojo::IOLoop->drop($watch);
       }
   );
}

sub send_state_if_updated {
    my ($self,$state,$puzzle_id,$tsref, $last_change_seen) = @_;
    my $updated = 0;
    for my $update ($self->db->resultset('SolvepadHistory')->search (
        { puzzle_id => $puzzle_id,
          ts => { '>', $$tsref},
      },
        {order_by => { -asc => 'ts'}}
    )) {
        if (exists $state->{$update->hotspot_id} &&
            $state->{$update->hotspot_id}{state} eq $update->older) {
            $updated = 1;
            $state->{$update->hotspot_id}{state} = $update->newer;
            $$tsref = $update->ts;
        }
    }
    if ($updated) {
        my $json = Mojo::JSON->new();
        $self->send_message(
            $json->encode({values => [values %$state],
                           change_number => $last_change_seen,
                       })
        );
    }
}

1;
