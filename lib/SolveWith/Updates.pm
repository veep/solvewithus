package SolveWith::Updates;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;
use Encode qw/encode decode/;
use SolveWith::Event;
use Time::HiRes;

sub _check_access {
    my $self = shift;
    my $event_id = $self->stash('event_id');
    my ($event, $team);

    if ($self->stash('token') && ! $event_id) {
        return "OK";
    }

    unless ($event_id) { $self->render_exception('Bad updates request: no event'); return; }

    $event = $self->db->resultset('Event')->find($event_id);
    $team = $event->team if $event;
    my $chat = $event->chat if $event;
    unless ($event) { $self->render_exception('Bad updates request: no event'); return; }
    unless ($chat) { $self->render_exception('Bad updates request: no chat'); return; }
    unless ($team) { $self->render_exception('Bad updates request: no team'); return; }
    my $access = 0;
    eval {
        $access = $team->has_access($self->session->{userid},$self->session->{token});
    };
    unless ($access) { $self->render_exception('Bad updates request: no access'); return; }
    return "OK!";
}

sub getstream {
    my $self = shift;
    $self->res->headers->add(Pragma => 'no-cache');
    $self->res->headers->add('Cache-Control' => 'no-cache, no-store');
    return unless _check_access($self);
    my $event_id = $self->stash('event_id');
    my $puzzle_id = $self->stash('puzzle_id');
    my $token = $self->stash('token');
    if ($token) {
        my $puzzle = $self->db->resultset('Puzzle')->find_by_token($token);
        return unless ($puzzle && $puzzle->id == $puzzle_id);
    }
    my $last_update = $self->stash('last') || 0;
    $self->res->headers->content_type('text/event-stream');
    $self->res->headers->header('X-Accel-Buffering' => 'no');
    my $stream = Mojo::IOLoop->stream($self->tx->connection)->timeout(120);

    my $json;
    if (Mojo::JSON->can('new')) {
        $json = Mojo::JSON->new();
    }
    my $cache;
    eval { $cache = $self->app->cache; };
    $cache //= CHI->new( driver => 'Memory', global => 1 );
    my @waits_and_loops;
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    my $last_sticky_status = '';

    if ($puzzle_id) {
        # every 10 seconds send current logged in status
        my $puzzle = $self->db->resultset('Puzzle')->find($puzzle_id);
        my $last_set_of_names = 'N/A';
        my $logged_in_puzzle_loop = sub {
            if (! $cache->get(join(' ','in puzzle',$puzzle_id,$self->session->{userid}))) {
                $cache->set(join(' ','in puzzle',$puzzle_id,$self->session->{userid}),1,25);
                $puzzle->expire_users_live_cache($cache);
            } else {
                $cache->set(join(' ','in puzzle',$puzzle_id,$self->session->{userid}),1,25);
            }
#            $self->app->log->debug(join(" ","Updated time for", $self->session->{userid}, $puzzle->id));
            my @logged_in = $puzzle->users_live($cache);
            @logged_in = map { my $foo = $_; $foo =~ s/( .).*/$1/; $foo} @logged_in;
            my $new_text = join(", ", @logged_in);
            if ($new_text ne $last_set_of_names) {
                $last_set_of_names = $new_text;
                my $output =
                "data: " .
                (
                    $json ?
                    $json->encode({
                        type => 'loggedin',
                        text => $new_text,
                        target_type => 'puzzle',
                        target_id => $puzzle_id,
                    })
                    :
                    Mojo::JSON::encode_json(
                        {
                            type => 'loggedin',
                            text => $new_text,
                            target_type => 'puzzle',
                            target_id => $puzzle_id,
                        })
                )
                . "\n\n";
                $self->write($output);
                $self->app->log->debug($output);
            }
        };
        push @waits_and_loops, Mojo::IOLoop->recurring(
            10 => $logged_in_puzzle_loop
        );
        &$logged_in_puzzle_loop;
        $self->app->log->debug("IO Loops so far: " .  join(", ",@waits_and_loops));
    }
    $self->on(finish => sub {
                  for my $loop_id (@waits_and_loops) {
                      $loop_id //= '';
                      $self->app->log->debug("remove IO Loop $loop_id");
                      if ($loop_id) {
                          if (Mojo::IOLoop->can('remove')) {
                              Mojo::IOLoop->remove($loop_id);
                          } else {
                              Mojo::IOLoop->drop($loop_id);
                          }
                      }
                  }
              });
    my $backlog_sent = 0;
    my @types = qw/created chat spreadsheet url aha note priority puzzle puzzleinfo puzzlejson
                   puzzleurl removed_puzzleurl removed_puzzleinfo removed_solution
                   removal state solution sticky sticky_delete/;
    # Subscribe to chat messages for this chat
    # Send chat messages that exist, update my cutoff to highest value
    my ($event, $event_chat_id, $puzzle_chat_id);
    $event_chat_id = 0;
    my @chat_ids;
    if (! $token) {
        $event = $self->db->resultset('Event')->find($event_id);
        $event_chat_id = $event->chat->id;
        push @chat_ids, $event_chat_id;
    }
    if ($puzzle_id) {
        $puzzle_chat_id = $self->db->resultset('Puzzle')->find($puzzle_id)->chat->id;
        push @chat_ids, $puzzle_chat_id;
    }
    my $last_update_time = 0;
    my $last_puzzle_table_html = '';
    my $last_form_round_list_html = '';
    if (! $puzzle_id) {
        my $puzzle_html_table = sub {
                my $st = scalar Time::HiRes::time;
                my $table_html = SolveWith::Event->get_puzzle_table_html($self, $event);
                if ($table_html ne $last_puzzle_table_html) {
                    my $first_time_html = '';
                    if (! $last_puzzle_table_html) {
                        if ($self->can('render_to_string')) {
                            $first_time_html = $self->render_to_string(
                                "event/hide_show", partial => 1,
                                hide_closed => $self->session->{hide_closed} || '');
                        } else {
                            $first_time_html = $self->render(
                                "event/hide_show", partial => 1,
                                hide_closed => $self->session->{hide_closed} || '');
                        }
                    }
                    $last_puzzle_table_html = $table_html;
                    $last_update_time = time;
                    my $output_hash = {
                        type => 'div',
                        divname => "event-puzzle-table-$event_id",
                        divhtml => $table_html . $first_time_html,
                    };
                    $self->write( "data: "
                                  . ($json ? $json->encode($output_hash) : Mojo::JSON::encode_json($output_hash))
                                  . "\n\n"
                              );
                }
                $self->app->log->debug('table html loop: ' . (Time::HiRes::time - $st));
            };
        &$puzzle_html_table;
        push @waits_and_loops, Mojo::IOLoop->recurring(
            2 => $puzzle_html_table,
        );
    }
    if (! $token) {
        push @waits_and_loops, Mojo::IOLoop->recurring(
            1 => sub {
                my $form_round_list_html = SolveWith::Event->get_form_round_list_html($self, $event);
                if ($form_round_list_html ne $last_form_round_list_html) {
                    $last_form_round_list_html = $form_round_list_html;
                    $last_update_time = time;
                    my $output_hash = {
                        type => 'div',
                        divname => "form-round-list",
                        divhtml => $form_round_list_html,
                    };
                    $self->write( "data: " .
                                  ($json ? $json->encode($output_hash) : Mojo::JSON::encode_json($output_hash)) .
                                  "\n\n");
                }
            });
        my $sticky_status_sub = sub {
            if (my @sticky_statuses = $user->user_messages()) {
                my $output = "data: " .
                (
                    $json ?
                    $json->encode({
                        type => 'sticky_status',
                        status => { map { $_->message_id->id => $_->status } @sticky_statuses },
                    })
                    :
                    Mojo::JSON::encode_json({
                        type => 'sticky_status',
                        status => { map { $_->message_id->id => $_->status } @sticky_statuses },
                    })
                )
                ."\n\n";
                if ($output ne $last_sticky_status) {
                    $self->write($output);
                    $last_sticky_status = $output;
                }
            }
        };
        &$sticky_status_sub;
        push @waits_and_loops, Mojo::IOLoop->recurring(
            5 => $sticky_status_sub,
        );
    }
    my $message_loop_sub = sub {
        my @messages = $self->db->resultset('Message')->search(
            { type => \@types,
              id => { '>', $last_update},
              chat_id => [@chat_ids],
          },
                {order_by => 'id'}
            );
        my ($event_sent, $puzzle_sent) = (0,0);
        for my $message (@messages) {
            my ($target_type, $target_id);
            if ($message->chat_id == $event_chat_id) {
                ($target_type, $target_id) = ('event', $event_id);
                $event_sent = 1;
            } else {
                ($target_type, $target_id) = ('puzzle', $puzzle_id);
                $puzzle_sent = 1;
            }
            my $rendered = $cache->compute(join(' ',
                                                'rendered message with target',
                                                $message->id,
                                                $message->type,
                                            ),
                                           {expires_in => 7200, expires_variance => 0.2},
                                           sub {
                                               return _get_rendered_message($self,
                                                                            $message,
                                                                            $json,
                                                                            $target_type,
                                                                            $target_id,
                                                                        );
                                           }
                                       );
            $self->write( "data: $rendered\n\n");
            $last_update_time = time;
            $last_update = $message->id;
        }
        if ($event_sent) {
            $self->write(
                "data: " .
                (
                    $json ?
                    $json->encode(
                        {
                            type => 'done', target_type => 'event', target_id => $event_id,
                        })
                    :
                    Mojo::JSON::encode_json(
                        {
                            type => 'done', target_type => 'event', target_id => $event_id,
                        })
                )
                . "\n\n");
        }
        if ($puzzle_sent) {
            $self->write(
                "data: " .
                (
                    $json ?
                    $json->encode(
                        {
                            type => 'done', target_type => 'puzzle', target_id => $puzzle_id,
                        })
                    :
                    Mojo::JSON::encode_json(
                        {
                            type => 'done', target_type => 'puzzle', target_id => $puzzle_id,
                        })
                )
                . "\n\n");
        }
        if (time - $last_update_time > 15) {
            $last_update_time = time;
            $self->write( "ping: $last_update_time\n\n");
        }
    };
    push @waits_and_loops, Mojo::IOLoop->recurring(
        1 => $message_loop_sub,
    );
    #    &$message_loop_sub;
    if (! $token) {
        my $last_set_of_names = 'N/A';
        my $names_in_event_sub = sub {
            if (! $cache->get(join(' ','in event',$event_id,$self->session->{userid}))) {
                $cache->set(join(' ','in event',$event_id,$self->session->{userid}),1,25);
                $event->expire_users_live_cache($cache);
            } else {
                $cache->set(join(' ','in event',$event_id,$self->session->{userid}),1,25);
            }
            #            $self->app->log->debug(join(" ","Updated time for", $self->session->{userid}, $puzzle->id));
            if (! $puzzle_id) {
                my @logged_in = $event->users_live($cache);
                  @logged_in = map { my $foo = $_; $foo =~ s/( .).*/$1/; $foo} @logged_in;
                my $new_text = join(", ", @logged_in);
                if ($new_text ne $last_set_of_names) {
                    $last_set_of_names = $new_text;
                    my $output = "data: " .
                    (
                        $json ?
                        $json->encode({
                            type => 'loggedin',
                            text => $new_text,
                            target_type => 'event',
                            target_id => $event_id,
                        })
                        :
                        Mojo::JSON::encode_json({
                            type => 'loggedin',
                            text => $new_text,
                            target_type => 'event',
                            target_id => $event_id,
                        })
                    )
                    . "\n\n";
                    $self->write($output);
                    $self->app->log->debug($output);
                }
            }
        };
        &$names_in_event_sub;
        push @waits_and_loops, Mojo::IOLoop->recurring(
            10 => $names_in_event_sub
        );
    }
}

sub _get_rendered_message {
    my ($self, $message, $json, $target_type, $target_id) = @_;

    my $output_hash;
    if ($message->type eq 'puzzle') {
        my $text;
        if ($self->can('render_to_string')) {
            $text = $self->render_to_string("chat/puzzle-message", partial => 1, message => $message);
        } else {
            $text = $self->render("chat/puzzle-message", partial => 1, message => $message);
        }
        $output_hash = { timestamp => $message->timestamp,
                         text => $text,
                         type => 'rendered',
                         id => $message->id,
                     };
    } elsif ($message->type eq 'removal') {
        my $removed_message = $self->db->resultset('Message')->find($message->text);
        if (! $removed_message or
            $removed_message->chat->id ne $message->chat->id) {
            next;
        }
        if ($removed_message->type eq 'removed_puzzleurl') {
            my $latest_url_text = undef;
            my $latest_url = $message->chat->get_latest_of_type('puzzleurl');
            if ($latest_url) {
                $latest_url_text = $latest_url->text;
            }
            $output_hash = { timestamp => $message->timestamp,
                             type => 'puzzleurl_removal',
                             text => [ $removed_message->text, $latest_url_text ],
                             id => $message->id,
                         };
        } elsif ($removed_message->type eq 'removed_solution') {
            $output_hash = { timestamp => $message->timestamp,
                             type => 'solution_removal',
                             text => $removed_message->text,
                             id => $message->id,
                         };
        }
    } else {
        $output_hash = { map { ($_ => $message->$_)} qw/type id text timestamp/ };
        if ($output_hash->{type} eq 'chat' or $output_hash->{type} eq 'sticky') {
            if ($self->can('render_to_string')) {
                $output_hash->{text} = $self->render_to_string(
                    "chat/chat-text",
                    partial => 1, string => $output_hash->{text},
                );
            } else {
                $output_hash->{text} = $self->render(
                    "chat/chat-text",
                    partial => 1, string => $output_hash->{text}
                );
            }
            chomp $output_hash->{text};
        }
        if (my $user = $message->user) {
            $output_hash->{author} = $user->display_name;
        }
    }
    $output_hash->{target_type} = $target_type;
    $output_hash->{target_id} = $target_id;
    return ($json ? $json->encode($output_hash) : Mojo::JSON::encode_json($output_hash));
}

# sub getnew {
#     my $self = shift;
#     my $type = $self->stash('type');
#     my $id = $self->stash('id');
#     my $last_update = $self->stash('last') || 0;
#     my ($item, $team);

#     if ($type eq 'event') {
#         $item = $self->db->resultset('Event')->find($id);
#         $team = $item->team if $item;
#     } elsif ($type eq 'puzzle') {
#         $item = $self->db->resultset('Puzzle')->find($id);
#         $team = $item->rounds->first->event->team if $item;
#     }
#     my $chat = $item->chat if $item;
#     unless ($item) { $self->render_exception('Bad updates request: no item'); return; }
#     unless ($chat) { $self->render_exception('Bad updates request: no chat'); return; }
#     unless ($team) { $self->render_exception('Bad updates request: no team'); return; }
#     my $access = 0;
#     eval {
#         $access = $team->has_access($self->session->{userid},$self->session->{token});
#     };
#     unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

#     my @results;
#     if ($type eq 'puzzle') {
#         my $logged_in_row = $item->find_or_create_related('puzzle_users',{user_id => $self->session->{userid}});
#         $logged_in_row->set_column('timestamp',scalar time);
#         $logged_in_row->update;
#         my @logged_in = $item->search_related('puzzle_users',{timestamp => { '>', (time - 15)}});
#         my @names = sort map {$_->user_id->display_name || $_->user_id->google_name } @logged_in;
#         push @results, {type => 'loggedin', text=> decode('UTF-8', join(", ", @names))};

#     }

#     my @types = qw/created chat spreadsheet url aha note puzzle puzzleurl state solution/;
#     my $messages_rs = $chat->search_related('messages',
# #    my $messages_rs = $self->db->resultset('Message')->search(
#                                             { type => \@types, 
#                                               id => { '>', $last_update}
#                                           },
#                                             {order_by => 'id'});
#     while (my $message = $messages_rs->next) {
#         if ($message->type eq 'puzzle') {
#             push @results, { timestamp => $message->timestamp,
#                              text => $self->render("chat/puzzle-message", partial => 1, message => $message),
#                              type => 'rendered',
#                              id => $message->id,
#                          };
#         } else {
#             my $data = { map { ($_ => $message->$_)} qw/type id text timestamp/ };
#             if ($data->{type} eq 'chat') {
#                 $data->{text} = $self->render("chat/chat-text", partial => 1, string => $data->{text});
#             }
#             if (my $user = $message->user) {
#                 $data->{author} = $user->display_name;
#             }
#             $data->{text} = decode('UTF-8', $data->{text});
#             push @results, $data;
#         }
#     }
#     $self->render_json(\@results);
# }


# sub event {
#     my $self = shift;
#     my $type = $self->stash('type');
#     my $id = $self->stash('id');
#     my $last_update = $self->stash('last') || 0;
#     my ($item, $team, $chat, @results);

#     $item = $self->db->resultset('Event')->find($id);
#     unless ($item) { $self->render_exception('Bad updates request: no item'); return; }
#     $chat = $item->chat;
#     unless ($chat) { $self->render_exception('Bad updates request: no chat'); return; }
#     $team = $item->team;
#     unless ($team) { $self->render_exception('Bad updates request: no team'); return; }
#     my $access = 0;
#     eval {
#         $access = $team->has_access($self->session->{userid},$self->session->{token});
#     };
#     unless ($access) { $self->render_exception('Bad updates request: no access'); return; }

#     # Two cursors, event->chat->message > last order by id
#     #              event->(puzzles)->chat->message > last order by id
#     # feed out the results of both cursors, intermingled in order by message id (i.e. chronological order)

#     my $event_messages_rs = $chat->search_related('messages',
#                                                   {
# #                                                      type => \@types,
#                                                       id => { '>', $last_update}
#                                                   },
#                                                   {order_by => 'id'});
#     my $puzzle_messages_rs = $self->db->resultset('Message')->search(
#         { 
#             'me.id' => { '>', $last_update },
#             'round_id.id' => $id,
#         },
#         {
#             join => {
#                 'chat' => { 'puzzle' => { 'puzzle_rounds' => 'round_id' }}
#             },
#             order_by => 'me.id',
#         }
#     );
    
#     my $pmessage = $puzzle_messages_rs->next;
#     my $emessage = $event_messages_rs->next;
#     while ($pmessage || $emessage) {
#         my $data;
#         if (!$emessage or ($pmessage and $pmessage->id < $emessage->id)) {
#             $data = { map { ($_ => $pmessage->$_)} qw/type id text timestamp user/ };
#             $data->{parent} = ['puzzle', $pmessage->chat->puzzle->id];
#             $pmessage = $puzzle_messages_rs->next;
#         } else {
#             $data = { map { ($_ => $emessage->$_)} qw/type id text timestamp user/ };
#             $data->{parent} = ['event',$id];
#             $emessage = $event_messages_rs->next;
#         }
#         next unless $data;
#         if (my $user = $data->{user}) {
#             $data->{author} = $user->display_name;
#         }
#         delete $data->{user};
#         $data->{text} = decode('UTF-8', $data->{text});
#         push @results, $data;
#     }
#     $self->render_json(\@results);
# }

sub chat {
    my $self = shift;
    my $type = $self->param('type');
    my $id = $self->param('id');
    my $text = $self->param('text');
    my $sticky = $self->param('sticky');
    my $token = $self->param('token');
    my ($item, $team);

    if ($type eq 'event') {
        $item = $self->db->resultset('Event')->find($id);
        $team = $item->team if $item;
    } elsif ($type eq 'puzzle') {
        $item = $self->db->resultset('Puzzle')->find($id);
        $team = $item->rounds->first->event->team if ($item && ! $token);
    }
    my $chat = $item->chat if $item;
    unless ($item) { $self->render_exception('Bad chat request: no item'); return; }
    unless ($chat) { $self->render_exception('Bad chat request: no chat'); return; }
    if ($token) {
        my $puzzle = $self->db->resultset('Puzzle')->find_by_token($token);
        if (! $puzzle or $puzzle->id != $id or $type ne 'puzzle') {
            $self->render_exception('Bad chat request: token does not match');
            return;
        }
    } else {
        unless ($team) { $self->render_exception('Bad chat request: no team'); return; }
        my $access = 0;
        eval {
            $access = $team->has_access($self->session->{userid},$self->session->{token});
        };
        unless ($access) { $self->render_exception('Bad chat request: no access'); return; }
    }
    if ($text =~ /\S/) {
        if ($sticky) {
            $chat->add_of_type('sticky',$text,$self->session->{userid});
        } else {
            $chat->add_of_type('chat',$text,$self->session->{userid});
        }
    }
    $self->render(text => 'OK', status => 200);
}

sub unstick {
    my $self = shift;
    my $msgid = $self->param('msgid');
    my $state = $self->param('state') || 'hidden';
    my $user = $self->db->resultset('User')->find($self->session->{userid});
    if ($msgid && $user) {
        if ($state eq 'kill') {
            my $message = $self->db->resultset('Message')->find($msgid);
            $message->chat->add_of_type('sticky_delete',$msgid,$self->session->{userid});
        } else {
            my $user_message_status = $user->user_messages->find_or_create({message_id => $msgid});
            if ($state eq 'toggle') {
                if ($user_message_status->status && $user_message_status->status eq 'hidden') {
                    $user_message_status->status('shown');
                } else {
                $user_message_status->status('hidden');
            }
            } else {
                $user_message_status->status('hidden');
            }
            $user_message_status->update;
        }
        $self->render(text => 'OK', status => 200);
        return;
    }
    $self->render(text => 'Issue', status => 500);
}

1;
