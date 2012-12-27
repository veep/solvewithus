$(document).ready(
    function() {
        $(".chat-text").each(
            function() {
                var pieces = $(this).attr("id").split("-");
                var puzzle_id =  pieces[pieces.length - 1];
                var type =  pieces[pieces.length - 2];
                setup_chat_filler(type, puzzle_id, this);
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
//                chat_filler(type,puzzle_id);
                return false;
            }
        );
        $(window).resize(function() {
            resize_chat_box($("#chat-box"));
        });

        resize_chat_box($("#chat-box"));

        $('#infoModal').on('hidden', function() {
            $(this).removeData('modal');
            $(this).find('.modal-body').html('');
        });

    }
);

function resize_chat_box(cb) {
    var target = $(window).height();
    var outer_current = cb.height();
    openchats = cb.children().filter('[class*="in"]').filter('[class*="collapse"]').children('.chat-text');
    var open_count = openchats.length;
    if (open_count == 0) {
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


var event_source = new Object();
function setup_chat_filler(type, puzzle_id, text_div) {
    $(text_div).parent().on('puzzleurl',function(event, url) {
        if (url) {
            $('#puzzle-link-default-' + puzzle_id).hide();
            $('#puzzle-link-' + puzzle_id).html(url);
        } else {
            $('#puzzle-link-default-' + puzzle_id).show();
            $('#puzzle-link-' + puzzle_id).html('');
        }

    });
    $(text_div).parent().on('newoutput',function(event, type) {
//        console.warn('triggered: ' + type);
        $(this).prev().find('.icon-chevron-right').fadeOut(200,function() {
//            console.warn ('handler');
            $.each( $(this).siblings('.chat-unread-count'), function (index, span) {
//                console.warn ('inner handler');
                if (parseInt($(span).text())) {
                    $(span).text(parseInt($(span).text()) + 1);
                } else {
                    $(span).text('1');
                }
            });
        });
    });
//    chat_filler(type,puzzle_id);
//    setInterval(function() {chat_filler(type,puzzle_id);},5000);
    var last_seen_id = 0;
    if (type === 'puzzle' && last_seen.puzzle[puzzle_id] > 0) {
        last_seen_id = last_seen.puzzle[puzzle_id];
    }
    if (type === 'event' && last_seen.event[puzzle_id] > 0) {
        last_seen_id = last_seen.event[puzzle_id];
    }
    event_source[ type + puzzle_id] = new EventSource(Array('','stream',type,puzzle_id,last_seen_id).join('/'));

//    console.warn(event_source);
    
    // Incoming messages
    event_source[ type + puzzle_id].onmessage = function(event) {
        var msg = jQuery.parseJSON(event.data);
        if (! msg) {
            console.warn(event.data);
            return;
        }
        var last_seen_id = 0;
        if (type === 'puzzle' && last_seen.puzzle[puzzle_id] > 0) {
            last_seen_id = last_seen.puzzle[puzzle_id];
        }
        if (type === 'event' && last_seen.event[puzzle_id] > 0) {
            last_seen_id = last_seen.event[puzzle_id];
        }
        if (type === 'puzzle' && msg.type === 'loggedin') {
            var usersspan = $("#usersspan");
            var oldhtml = usersspan.html();
            var newhtml = '<b>Here:</b> ' + msg.text;
            if (!(oldhtml === newhtml)) {
                usersspan.html(newhtml);
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
                   ['chat','text',type,puzzle_id].join('-') );
        var mydiv = $("#" + ['chat','text',type,puzzle_id].join('-'));
        mydiv.scrollTop(mydiv.prop("scrollHeight") - mydiv.height() );
    };

}

// function chat_filler (type, puzzle_id) {
//     var last_seen_id = 0;
// //    console.warn(type + ' ' + puzzle_id);
//     if (type === 'puzzle' && last_seen.puzzle[puzzle_id] > 0) {
//         last_seen_id = last_seen.puzzle[puzzle_id];
//     }
//     if (type === 'event' && last_seen.event[puzzle_id] > 0) {
//         last_seen_id = last_seen.event[puzzle_id];
//     }
//     $.getJSON( Array('','updates',type,puzzle_id,last_seen_id).join('/'),
//                 function (messages) {
//                     $.each(messages,
//                            function (index,msg) {
//                                if (type === 'puzzle' && msg.type === 'loggedin') {
//                                    var usersspan = $("#usersspan");
//                                    var oldhtml = usersspan.html();
//                                    var newhtml = '<b>Here:</b> ' + msg.text;
//                                    if (!(oldhtml === newhtml)) {
//                                        usersspan.html(newhtml);
//                                        resize_chat_box($("#chat-box"));
//                                    }                                       
//                                    return;
//                                }
//                                if (type === 'puzzle') { 
//                                    if (last_seen.puzzle[puzzle_id] === undefined || 
//                                        last_seen.puzzle[puzzle_id] < msg.id) {
//                                        last_seen.puzzle[puzzle_id] = msg.id;
//                                    } else {
//                                        return;
//                                    }
//                                }
//                                if (type === 'event') {
//                                    if (last_seen.event[puzzle_id] === undefined ||
//                                        last_seen.event[puzzle_id] < msg.id) {
//                                        last_seen.event[puzzle_id] = msg.id;
//                                    } else {
//                                        return;
//                                    }
//                                }
//                                render_msg(msg.type, msg.text, msg.timestamp, ( msg.author ? msg.author : ''),
//                                           ['chat','text',type,puzzle_id].join('-')
//                                          );

//                            });
//                     // There's always one message for 'puzzle' type, the logged in users
//                     if( ( messages.length > 1) || (type != 'puzzle' && messages.length) ) {
//                         var mydiv = $("#" + ['chat','text',type,puzzle_id].join('-'));
//                         mydiv.scrollTop(mydiv.prop("scrollHeight") - mydiv.height() );
//                     }
//                 });
// }

var last_daystring = new Object;
                               
function render_msg (type, text, ts, author, div_id) {
    var result = '';
    var d = new Date(ts*1000);
    var daystring = '<span style="background: #CCC">' + d.toDateString() + '</span><br/>' ;
    var ds = '<span class="chat-date-time-string">' + 
        (d.getHours() < 10 ? '0' : '') + d.getHours() + ':' + 
        (d.getMinutes() < 10 ? '0' : '') + d.getMinutes() + ':' + 
        (d.getSeconds() < 10 ? '0' : '') + d.getSeconds() + ': ' +
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
//    if (type === 'spreadsheet') {
//        result = ds + '<A HREF="' + text + '">Spreadsheet assigned</A>';
//    }
    if (type === 'chat') {
        result = ds + '<B>' + author + '</B>: ' + text;
    }
    if (type === 'puzzle') {
        result = ds + text;
    }
    if (type === 'state' && text === 'closed') {
        result = ds + '<B>Puzzle Closed</B>';
    }
    if (type === 'state' && text === 'open') {
        result = ds + '<B>Puzzle Opened</B>';
    }
    if (type === 'state' && text === 'dead') {
        result = ds + '<B>Puzzle Marked Dead</B>';
    }
    if (type === 'solution') {
        result = ds + '<span class="label label-success">Solution</span> ' + $('<div/>').text(text).html();
    }
    if (type === 'puzzleurl') {
        result = ds + '<span class="label label-info">URL</span> ' + text;
        var mydiv = $("#" + div_id);
        mydiv.trigger(jQuery.Event("puzzleurl"),text);
    }
    if (type === 'puzzleinfo') {
        result = ds + '<span class="label lable-info">Info</span> ' + text;
    }
    if (type === 'puzzleurl_removal') {
        result = ds + '<span class="label label-important">URL Removed</span> ' + text[0];
        var mydiv = $("#" + div_id);
        mydiv.trigger(jQuery.Event("puzzleurl"), text[1]);
    }
    if (type === 'solution_removal') {
        result = ds + '<span class="label label-important">Solution Removed</span>: ' + $('<div/>').text(text).html();
    }
    if (result.length) {
        var mydiv = $("#" + div_id);
        mydiv.append('<br/>' + result );
        mydiv.trigger(jQuery.Event("newoutput"),type);
        if (type === 'rendered') {
            $('.answer-button').click(function () {
                var btn = $(this);
                btn.button('loading');
                btn.addClass('btn-link').removeClass('btn-success');
            });
        }
    }
}
