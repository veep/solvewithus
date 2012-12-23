$(document).ready(
    function() {
        $(".chat-text").each(
            function() {
                var pieces = $(this).attr("id").split("-");
                var puzzle_id =  pieces[pieces.length - 1];
                var type =  pieces[pieces.length - 2];
                setup_chat_filler(type, puzzle_id);
            }
        );
        $(".chat-input").keydown(
            function(event) {
                if (event.keyCode != 13 || event.shiftKey || event.ctrlKey ) {
                    return true;
                }
                var text = $(this).val();
                $(this).val('');
                var pieces = $(this).attr("id").split("-");
                var puzzle_id =  pieces[pieces.length - 1];
                var type =  pieces[pieces.length - 2];
                $.post('/chat', { text: text, type: type, id: puzzle_id });
                chat_filler(type,puzzle_id);
                return false;
            }
        );
        $(".status-tree").each(
            function() {
                var pieces = $(this).attr("id").split("-");
                var event_id =  pieces[2];
                var puzzle_id =  pieces[3];
                setup_status_tree(event_id, puzzle_id, $(this));
            }
        );
        $(window).resize(function() {
            resize_chat_box($("#chat-box"));
        });
        $('[class*="collapse"]').on('show hide', function (event) {
            if (event.type == 'hidden' || event.type == 'hide') {
                $(this).prev().find(".chat-open-close").addClass("icon-chevron-right").removeClass("icon-chevron-down");
            } else {
                $(this).prev().find(".chat-open-close").addClass("icon-chevron-down").removeClass("icon-chevron-right");
            }
        });
        $('[class*="collapse"]').on('shown hidden', function (event) {
            resize_chat_box($("#chat-box"));
        });

        resize_chat_box($("#chat-box"));

        $('.submit-modal').click(function () {
            var form_data = {};
            form_data["action"] = $(this).text();
            $(this).parent().siblings(".modal-body").children("form").children().each(function() {
                form_data[$(this).attr("name")] = $(this).val();
            });
            $.post
            (
                '/puzzle/modal',
                form_data
            );
            $(this).parent().parent().modal('hide');
        });
        
        $('.ModalForm').submit(function(event) {
            console.warn('modal form');
            event.preventDefault();
            var form_data = {};
            form_data["action"] = 'Submit';
            $(this).children().each(function() {
                form_data[$(this).attr("name")] = $(this).val();
            });
            $.post
            (
                '/puzzle/modal', 
                form_data
            );
            $(this).parent().parent().modal('hide');
        });
    }
);

function resize_chat_box(cb) {
    var target = $(window).height();
    var outer_current = cb.height();
    openchats = cb.children().filter('[class*="in"]').filter('[class*="collapse"]').children('.chat-text');
    var open_count = openchats.length;
    if (open_count == 0) {
//        console.warn("0 open chats, returning");
        return;
    }
    
    var inner_current = 0;
    openchats.each(
        function() {
            inner_current += $(this).height();
        }
    );

    cb.siblings().each(
        function() {
            target = target - $(this).outerHeight(true);
        }
    );
    
//    console.warn([inner_current, target,outer_current,open_count].join(':'));
    var final_size = Math.floor((inner_current + target - outer_current - 10)/open_count);
//    console.warn( "resizing to " + final_size);
    
    openchats.each(
        function() {
            $(this).height( final_size );
            $(this).scrollTop($(this).prop("scrollHeight") - $(this).height() );
        }
    );
            
}
          
var last_seen = new Object();
last_seen.event = new Array();
last_seen.puzzle = new Array();

function setup_status_tree(event_id, puzzle_id, parent) {
    setInterval(function() {status_tree(event_id, puzzle_id, parent);},10000);
}

function status_tree (event_id, puzzle_id, parent) {
    var tree_ajax_url = Array('','event','status',event_id).join('/');
    if (puzzle_id) {
        tree_ajax_url = Array('','event','status',event_id,puzzle_id).join('/');
    }
    $.getJSON( tree_ajax_url,
               function (messages) {
                   $.each(messages,
                          function (index, chunk) {
                              if (chunk.type === 'tree_html') {
                                  $("#open_puzzles").html(chunk.content);
                              }
                          });
               });
}

function setup_chat_filler(type, puzzle_id) {
//    console.log ("setup" + type + ' ' + puzzle_id);
    chat_filler(type,puzzle_id);
    setInterval(function() {chat_filler(type,puzzle_id);},5000);
}

function chat_filler (type, puzzle_id) {
    var last_seen_id = 0;
//    console.warn(type + ' ' + puzzle_id);
    if (type === 'puzzle' && last_seen.puzzle[puzzle_id] > 0) {
        last_seen_id = last_seen.puzzle[puzzle_id];
    }
    if (type === 'event' && last_seen.event[puzzle_id] > 0) {
        last_seen_id = last_seen.event[puzzle_id];
    }
    $.getJSON( Array('','updates',type,puzzle_id,last_seen_id).join('/'),
                function (messages) {
                    $.each(messages,
                           function (index,msg) {
                               if (type === 'puzzle' && msg.type === 'loggedin') {
                                   var usersspan = $("#usersspan");
                                   var oldhtml = usersspan.html();
                                   var newhtml = '<b>Here:</b> ' + msg.text;
                                   if (!(oldhtml === newhtml)) {
                                       usersspan.html(newhtml);
                                       console.warn(oldhtml);
                                       console.warn(newhtml);
                                       resize_chat_box($("#chat-box"));
                                   }                                       
                                   return;
                               }
                               if (type === 'puzzle') { 
                                   if (last_seen.puzzle[puzzle_id] === undefined || 
                                       last_seen.puzzle[puzzle_id] < msg.id) {
                                       last_seen.puzzle[puzzle_id] = msg.id;
                                   } else {
                                       return;
                                   }
                               }
                               if (type === 'event') {
                                   if (last_seen.event[puzzle_id] === undefined ||
                                       last_seen.event[puzzle_id] < msg.id) {
                                       last_seen.event[puzzle_id] = msg.id;
                                   } else {
                                       return;
                                   }
                               }
                               render_msg(msg.type, msg.text, msg.timestamp, ( msg.author ? msg.author : ''),
                                          ['chat','text',type,puzzle_id].join('-')
                                         );

                           });
                    // There's always one message for 'puzzle' type, the logged in users
                    if( ( messages.length > 1) || (type != 'puzzle' && messages.length) ) {
                        var mydiv = $("#" + ['chat','text',type,puzzle_id].join('-'));
                        mydiv.scrollTop(mydiv.prop("scrollHeight") - mydiv.height() );
                    }
                });
}

var last_daystring = new Object;
                               
function render_msg (type, text, ts, author, div_id) {
    var result = '';
    var d = new Date(ts*1000);
    var daystring = '<span style="background: #CCC">' + d.toDateString() + '</span><br/>' ;
    var ds = '<span class="chat-date-time-string">' + 
        (d.getHours() < 10 ? '0' : '') + d.getHours() + ':' + 
        (d.getMinutes() < 10 ? 0 : '') + d.getMinutes() + ':' + 
        (d.getSeconds() < 10 ? 0 : '') + d.getSeconds() + ': ' +
        '</span>';
    if (daystring != last_daystring[div_id]) {
        ds = daystring + ds;
        last_daystring[div_id] = daystring;
    }
    if (type === 'created') {
        result = ds + 'Created';
    }
    if (type === 'rendered') {
        result = ds + text;
    }
    if (type === 'spreadsheet') {
        result = ds + '<A HREF="' + text + '">Spreadsheet assigned</A>';
    }
    if (type === 'chat') {
        result = ds + '<B>' + author + '</B>: ' + text;
    }
    if (type === 'puzzle') {
        result = ds + text;
    }
    if (type === 'state' && text === 'closed') {
        result = ds + '<B>Puzzle Closed</B>';
    }
    if (type === 'solution') {
        result = ds + '<B>Solution</B>: ' + $('<div/>').text(text).html();
    }
    if (result.length) {
        var mydiv = $("#" + div_id);
        mydiv.append('<br/>' + result );
        if (type === 'rendered') {
            $('.answer-button').click(function () {
                var btn = $(this);
                btn.button('loading');
                btn.addClass('btn-link').removeClass('btn-success');
            });
        }
    }
}
                  
