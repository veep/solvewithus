package SolveWith::Solvepad;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw/md5_sum/;
use Mojo::UserAgent;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_FD ZMQ_PUB ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_DONTWAIT);
use Mojo::IOLoop;
use Time::HiRes;

sub intro {
    my $self = shift;
    my $userid = $self->session->{userid};
    warn "userid $userid";
    if ($userid) {
        my $user = $self->db->resultset('User')->find($userid);
        if ($user) {
            $self->redirect_to('solvepad');
        }
    }
}

sub logout {
    my $self = shift;
    delete $self->session->{userid};
    delete $self->session->{token};
    $self->redirect_to('solvepad_intro');
}

sub main {
    my $self = shift;
    warn 'id ' . $self->session->{userid};
    if (! $self->session->{userid} ) {
        $self->redirect_to('solvepad_intro');
        return;
    }
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user || ! $user->id ) {
        $self->redirect_to('solvepad_intro');
        return;
    }
    my (@open_puzzles, @closed_puzzles, @shared_puzzles);
    for my $puzzle (
        $self->db->resultset('SolvepadPuzzle')->search(
            { user_id => $user->id
          }
        )->all()
    ) {
        if ($puzzle->state && $puzzle->state eq 'closed') {
            push @closed_puzzles, $puzzle;
        } else {
            push @open_puzzles, $puzzle;
        }
    }
    for my $puzzle_share (
        $self->db->resultset('SolvepadShare')->search(
            { user_id => $user->id }
        )->all()
    ) {
        push @shared_puzzles, $puzzle_share->puzzle;
    }
    $self->stash('open_puzzles' => \@open_puzzles);
    $self->stash('shared_puzzles' => \@shared_puzzles);
    $self->stash('closed_puzzles' => \@closed_puzzles);
    $self->stash('user' => $user);
}

sub puzzle {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('/solvepad');
    }
    my $puzzle_id = $self->param('id');
    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find($puzzle_id);
    if (
        !$puzzle
        or
        (
            $puzzle->user_id != $user->id
            and
            ! $self->db->resultset('SolvepadShare')->search(
                { user => $user, puzzle => $puzzle }
            )
        )
    ) {
        $self->redirect_to('solvepad');
        return;
    }
    if (! $puzzle->solvepad_source->disk_file) {
        Mojo::IOLoop->timer(1 => sub { 
                                $self->redirect_to('solvepad_by_id', id => $puzzle->id);
                                return;
                            });
        $self->render_later;
        return;
    }
    $self->stash('puzzle' => $puzzle);
    $self->stash('user' => $user);
    $self->stash('share_key' => $puzzle->get_share_key);
    $self->stash('recommend_key' => $puzzle->get_recommend_key);
    $self->stash('root' => $self->app->static->root);
}

sub share {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    my $key = $self->param('key');
    if ($key !~ /(\d+)-/) {
        $self->redirect_to('/solvepad');
        return;
    }
    my $puzzle_id = $1;
    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find($puzzle_id);
    if (! $puzzle or $key ne $puzzle->share_key) {
        warn "key mismatch $key";
        $self->redirect_to('/solvepad/');
        return;
    }

    if ($puzzle->user_id != $user->id) {
        my $share = $self->db->resultset('SolvepadShare')->find_or_create(
            { user => $user, puzzle => $puzzle }
        );
    }
    $self->redirect_to($self->url_for('solvepad_by_id', id => $puzzle_id));
}

sub recommend {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    my $key = $self->param('key');
    if ($key !~ /(\d+)-/) {
        $self->redirect_to('solvepad');
        return;
    }
    my $puzzle_id = $1;
    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find($puzzle_id);
    if (! $puzzle or $key ne $puzzle->recommend_key) {
        warn "recommend key mismatch $key";
        $self->redirect_to('solvepad');
        return;
    }

    if ($puzzle->user_id != $user->id) {
        my $new_puzzle = $self->db->resultset('SolvepadPuzzle')->find_or_new(
            {
                user_id => $user->id,
                source_id => $puzzle->solvepad_source->id,
            }
        );
        if (! $new_puzzle->in_storage ) {
            $new_puzzle->title($puzzle->title);
            $new_puzzle->state('open');
            $new_puzzle->insert;
        }
        $self->redirect_to($self->url_for('solvepad_by_id', id => $new_puzzle->id));
    } else {
        $self->redirect_to($self->url_for('solvepad_by_id', id => $puzzle_id));
    }
}

sub close_open {
    my $self = shift;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('solvepad');
    }
    my $puzzle_id = $self->param('id');
    my $puzzle = $self->db->resultset('SolvepadPuzzle')->find($puzzle_id);
    if ( !$puzzle or $puzzle->user_id != $user->id ) {
        $self->redirect_to('solvepad');
        return;
    }
    if ($puzzle->state eq 'closed') {
        $puzzle->set_column( state => 'open');
        $puzzle->update;
        $self->redirect_to('solvepad_by_id', id => $puzzle->id);
    } else {
        $puzzle->set_column( state => 'closed');
        $puzzle->update;
        $self->redirect_to('solvepad');
    }
}

sub create {
    my ($self) = @_;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if (! $user) {
        $self->redirect_to('solvepad');
        return;
    }

    my $title = $self->param('PuzzleTitle');
    my $url = $self->param('PuzzleURL');
    my $fileuploaded = $self->req->upload('PuzzleUpload');

    if (! $url and ! $fileuploaded) {
        $self->redirect_to('solvepad');
        return;
    }

    my $user_id = $user->id;

    my $ua = Mojo::UserAgent->new;
    my $body;
    if ($url) {
        $body = $ua->get($url)->res->body;
    } else {
        $body = $fileuploaded->slurp;
        $url = 'upload';
    }

    if (! $body) {
        $self->redirect_to('solvepad');
        return;
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
    my @cmd = ("$rootdir/script/find-hotspots",$source->id);
    if ($url eq 'upload') {
        $fileuploaded->move_to("$rootdir/public/" . $source->id . '-in');
        push @cmd, "$rootdir/public/" . $source->id . '-in';
    }
    system(@cmd);

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
    $self->redirect_to($self->url_for('solvepad_by_id', id => $puzzle->id));
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

    send_state_if_updated($self,\%state, $puzzle, \$last_ts, $last_change_seen);

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
            if (exists $message_data->{change_number}) {
                $last_change_seen = $message_data->{change_number};
            }

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
#                warn "sending $puzzle_id " . ($hist->ts);
                zmq_sendmsg($publisher,"$puzzle_id " . $hist->ts);
            } elsif (exists $message_data->{cmd} && $message_data->{cmd} eq 'reset') {
                my $hist = $self->db->resultset('SolvepadHistory')->find_or_create(
                    {
                        solvepad_puzzle => $puzzle,
                        ts => (scalar Time::HiRes::time),
                        solvepad_user => $user,
                        type => 'reset',
                    }
                );
                zmq_sendmsg($publisher,"$puzzle_id " . $hist->ts);
            } elsif (exists $message_data->{cmd} &&
                     $message_data->{cmd} =~ /^line_(on|clear)$/) {
                my $type = $1;
                if ($message_data->{start_id} && $message_data->{stop_id}) {
                    if (exists $state{$message_data->{start_id}}) {
                        my ($dir, $reverse);
                        if ($state{$message_data->{start_id}}{up}
                            && $state{$message_data->{start_id}}{up} == $message_data->{stop_id}) {
                            $dir = 'up'; $reverse = 'down';
                        }
                        if ($state{$message_data->{start_id}}{down}
                            && $state{$message_data->{start_id}}{down} == $message_data->{stop_id}) {
                            $dir = 'down'; $reverse = 'up';
                        }
                        if ($state{$message_data->{start_id}}{left}
                            && $state{$message_data->{start_id}}{left} == $message_data->{stop_id}) {
                            $dir = 'left'; $reverse = 'right';
                        }
                        if ($state{$message_data->{start_id}}{right}
                            && $state{$message_data->{start_id}}{right} == $message_data->{stop_id}) {
                            $dir = 'right'; $reverse = 'left';
                        }
                        if ($dir) {
                            $self->db->resultset('SolvepadHistory')->create(
                                {
                                    solvepad_puzzle => $puzzle,
                                    ts => (scalar Time::HiRes::time),
                                    solvepad_user => $user,
                                    hotspot_id => $message_data->{start_id},
                                    newer => $type,
                                    type => 'line_' . $dir,
                                }
                            );
                            my $hist = $self->db->resultset('SolvepadHistory')->create(
                                {
                                    solvepad_puzzle => $puzzle,
                                    ts => (scalar Time::HiRes::time),
                                    solvepad_user => $user,
                                    hotspot_id => $message_data->{stop_id},
                                    newer => $type,
                                    type => 'line_' . $reverse,
                                }
                            );
                            zmq_sendmsg($publisher,"$puzzle_id " . $hist->ts);
                        }
                    }
                }
            } else {
                if (!  keys %state) {
                    $self->app->log->debug('no state, checking');
                    send_state_if_updated($self,\%state, $puzzle, \$last_ts, $last_change_seen);
                }
            }

            warn 'end message ' . scalar Time::HiRes::time;
        }
    );

   my $watch =  Mojo::IOLoop->recurring( 0.2 => sub 
       {
#           warn "checking";
           my $msg = zmq_recvmsg($subscriber, ZMQ_DONTWAIT);
           if ($msg) {
#               warn zmq_msg_data($msg);
               zmq_msg_close($msg);
               send_state_if_updated($self,\%state, $puzzle, \$last_ts, $last_change_seen);
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
    my ($self,$state,$puzzle,$tsref, $last_change_seen) = @_;
    my $json = Mojo::JSON->new();

    my $updated = 0;

    # Check for hotspot changes
    for my $hotspot ( $self->db->resultset('SolvepadHotspot')->search(
        {
            source_id => $puzzle->solvepad_source->id,
        },
    )->all) {
        if (! exists $state->{$hotspot->id}) {
            my $id = $hotspot->id;
            $state->{$id} = {
                shape => $hotspot->shape,
                state => 'clear',
                id => $id,
                up => $hotspot->up,
                down => $hotspot->down,
                left => $hotspot->left,
                right => $hotspot->right,
            };
            ($state->{$id}{minx}, $state->{$id}{miny},
             $state->{$id}{maxx}, $state->{$id}{maxy}) = split(',',$hotspot->shape_data);
            $self->app->log->debug('added hotspot');
            $updated = 1;
        }
    }

    for my $update ($self->db->resultset('SolvepadHistory')->search (
        { puzzle_id => $puzzle->id,
          ts => { '>', $$tsref},
      },
        {order_by => { -asc => 'ts'}}
    )) {
        if ($update->type =~ /^line_(\w+)$/ 
            && $update->hotspot_id
            && exists $state->{$update->hotspot_id}
        ) {
            if ($update->newer eq 'on') {
                $state->{$update->hotspot_id}{'state_' . $1} = 'on';
                if ($state->{$update->hotspot_id}{'state'} eq 'dot') {
                    $state->{$update->hotspot_id}{'state'} = 'clear';
                }
            } else {
                $state->{$update->hotspot_id}{'state_' . $1} = ''
            }
            $updated = 1;
        } elsif ($update->type eq 'reset') {
            $updated = 1;
            for my $hotspot ( $self->db->resultset('SolvepadHotspot')->search(
                {
                    source_id => $puzzle->solvepad_source->id,
                },
            )->all) {
                my $id = $hotspot->id;
                $state->{$id}{state} = 'clear';
                for my $dir ('up','down','left','right') {
                    $state->{$id}{'state_' . $dir} = '';
                }
            }
        } elsif ($update->hotspot_id &&
            exists $state->{$update->hotspot_id} &&
            $state->{$update->hotspot_id}{state} eq $update->older) {
            $updated = 1;
            $state->{$update->hotspot_id}{state} = $update->newer;
            $$tsref = $update->ts;
        }
    }
    if ($updated) {
        $self->send_message(
            $json->encode({values => [values %$state],
                           change_number => $last_change_seen,
                       })
        );
    }
}

1;
