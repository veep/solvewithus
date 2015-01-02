$(document).ready(
    function() {
        setup_chat_text_boxes();
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
                console.log( { text: text, type: type, id: puzzle_id } );
                $.post('/chat', { text: text, type: type, id: puzzle_id });
                var textdiv = $(this).parents('.control-group').prev();
                textdiv.scrollTop(textdiv.prop("scrollHeight") - textdiv.height() );
                return false;
            }
        );
        $(window).resize(function() {
            resize_chat_box($("#chat-box"));
        });

        resize_chat_box($("#chat-box"));

        setInterval (check_eventsources, 10000);
        $('#infoModal').on('hidden', function() {
            $(this).removeData('modal');
            $(this).find('.modal-body').html('');
        });
        $('#eventInfoModal').on('hidden', function() {
            $(this).removeData('modal');
            $(this).find('.modal-body').html('');
        });
        String.prototype.ucfirst = function()
        {
             return this.charAt(0).toUpperCase() + this.substr(1);
        }
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

    openchats.each(
        function() {
//            console.warn($(this).scrollTop(), $(this).prop("scrollHeight"), $(this).height());
            if ($(this).scrollTop() < ($(this).prop("scrollHeight") - $(this).height())) {
                $(this).data('at_bottom','no');
//                console.warn('not at bottom');
            } else {
                $(this).data('at_bottom','yes');
//                console.warn('at bottom');
            }
        }
    );
    
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
            if ($(this).data('at_bottom') === 'yes') {
                $(this).scrollTop($(this).prop("scrollHeight") - $(this).height() );
            }
            $(this).removeData('at_bottom');
            $(this).scrollLeft(0);
        }
    );
            
}
          
var last_seen = new Object();
last_seen.event = new Array();
last_seen.puzzle = new Array();


var event_source = new Object();

function setup_chat_text_boxes () {
    var chats = new Array();
    $(".chat-text").each(
        function() {
            var pieces = $(this).attr("id").split("-");
            var puzzle_id =  pieces[pieces.length - 1];
            var type =  pieces[pieces.length - 2];
            chats.push( new Array($(this), type, puzzle_id));
        }
    );
    setup_combined_chat_filler(chats);
    $(".chat-sticky-messages").on('click','.trash-sticky-message',function (event) {
        if ($(this).parents('.chat-sticky-messages').find('.trash-sticky-message').length <=1) {
            $(this).parents('.chat-sticky-messages').hide();
        }
        $(this).parent().remove();
        resize_chat_box($("#chat-box"));
    });
        
}

function check_eventsources() {
    for (var es in event_source) {
        if (event_source.hasOwnProperty(es)) {
            if (event_source[es].readyState == EventSource.CLOSED) {
                console.warn("trying to fix " + es);
                setup_chat_text_boxes();
                return;
            }
        }
    }
}

var last_seen_id = 0;

function setup_combined_chat_filler (chats) {
    var stream_url = '/stream';
    $.each(chats, function (i, chatbox) {
        stream_url = Array(stream_url, chatbox[1], chatbox[2]).join('/');

        if (chatbox[1] === 'puzzle') {
            var puzzle_id = chatbox[2];
            $(chatbox[0]).parent().on('puzzleurl',function(event, url) {
                if (url) {
                    $('#puzzle-link-default-' + puzzle_id).hide();
                    $('#puzzle-link-' + puzzle_id).html(url);
                } else {
                    $('#puzzle-link-default-' + puzzle_id).show();
                    $('#puzzle-link-' + puzzle_id).html('');
                }
            });
        }

        $(chatbox[0]).parent().on('newoutput',function(event, type) {
            $(this).prev().find('.icon-chevron-right').fadeOut(200,function() {
                console.warn ('handler');
                $.each( $(this).siblings('.chat-unread-count'), function (index, span) {
                    console.warn ('inner handler');
                    if (parseInt($(span).text())) {
                        $(span).text(parseInt($(span).text()) + 1);
                    } else {
                        $(span).text('1');
                    }
                });
            });
        });
        $(chatbox[0]).on('prerender',function() {
            if (! $(this).data('at_bottom')) {
//                console.warn($(this).scrollTop(), $(this).prop("scrollHeight"), $(this).height());
                if ($(this).scrollTop() < ($(this).prop("scrollHeight") - $(this).height())) {
                    $(this).data('at_bottom','no');
//                    console.warn('not at bottom (chat)');
                } else {
                    $(this).data('at_bottom','yes');
//                    console.warn('at bottom (chat)');
                }
            }
        });
    });

    stream_url = Array(stream_url, last_seen_id).join('/');

    event_source[ 'combined' ] = new EventSource(stream_url);
    event_source[ 'combined' ].onmessage = function(event) {
        var msg = jQuery.parseJSON(event.data);
        if (! msg) {
            console.warn(event.data);
            return;
        }
        if (msg.type === 'done') {
            var mydiv = $("#" + ['chat','text',msg.target_type,msg.target_id].join('-'));
            mydiv.scrollLeft(0);
            if (mydiv.data('at_bottom') === 'yes') {
                mydiv.scrollTop(mydiv.prop("scrollHeight") - mydiv.height() );
            }
            mydiv.removeData('at_bottom');
            return;
        }
        if (msg.type === 'div') {
            var mydiv = $("#" + msg.divname);
            mydiv.html( msg.divhtml );
            mydiv.trigger('liveupdate');
            return;
        }
            
        if (msg.target_type === 'puzzle' && msg.type === 'loggedin') {
            var usersspan = $("#usersspan");
            var oldhtml = usersspan.html();
            var newhtml = '<b>Here:</b> ' + msg.text;
            if (!(oldhtml === newhtml)) {
                usersspan.html(newhtml);
                resize_chat_box($("#chat-box"));
            }                                       
            return;
        }
        if (last_seen_id === undefined || 
            (msg.id && last_seen_id < msg.id)) {
            last_seen_id = msg.id;
        } else {
            return;
        }
        render_msg(msg.type, msg.text, msg.timestamp, ( msg.author ? msg.author : ''),
                   ['chat','text',msg.target_type,msg.target_id].join('-') );
    };        
        
}


var last_daystring = new Object;
                               
function render_msg (type, text, ts, author, div_id) {
    var result = '';
    var d = new Date(ts*1000);
    var daystring = '<span style="background: #CCC">' + d.toDateString() + '</span>' ;
    var ds = '<span class="chat-date-time-string">' + 
        (d.getHours() < 10 ? '0' : '') + d.getHours() + ':' + 
        (d.getMinutes() < 10 ? '0' : '') + d.getMinutes() + ':' + 
        (d.getSeconds() < 10 ? '0' : '') + d.getSeconds() + ': ' +
        '</span>';
    if (type === 'sticky') {
        var chatdiv = $("#" + div_id);
        var stickydiv = chatdiv.prev('.chat-sticky-messages');
        var stickyresult = '<i class="icon-trash trash-sticky-message"></i> ';
        if (text.substr(0,4) === '/me ') {
            stickyresult += daystring + ' ' + ds + '<i>' + author  + text.substr(3) + '</i>';
        } else {
            stickyresult += daystring + ' ' + ds + '<B>' + author + '</B>: ' + text;
        }
        stickydiv.append('<div>' + stickyresult + '</div>');
        stickydiv.show();
        resize_chat_box($("#chat-box"));
        return;
    }
    if (daystring != last_daystring[div_id]) {
        ds = daystring + '<br/>' + ds;
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
        if (text.substr(0,4) === '/me ') {
            result = ds + '<i>' + author  + text.substr(3) + '</i>';
        } else {
            result = ds + '<B>' + author + '</B>: ' + text;
        }
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
    if (type === 'priority') {
        result = ds + '<span class="label label-info">Priority: ' + $('<div/>').text(text).html().ucfirst() + '</span> by ' + author;
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
        result = ds + '<span class="label label-info">Info</span> ' + text;
    }
    if (type === 'puzzleurl_removal') {
        result = ds + '<span class="label label-important">URL Removed</span> ' + text[0];
        var mydiv = $("#" + div_id);
        mydiv.trigger(jQuery.Event("puzzleurl"), text[1]);
    }
    if (type === 'solution_removal') {
        result = ds + '<span class="label label-important">Solution Removed</span>: ' + $('<div/>').text(text).html();
    }
    if (type === 'puzzlejson') {
        var obj = jQuery.parseJSON(text);
        if (obj.type === 'priority') {
            result = ds + '<span class="label label-info">Priority: ' 
                + $('<div/>').text(obj.text).html().ucfirst()
                + '</span> on "<a href="/puzzle/' + obj.puzzleid + '">' + obj.puzzle + '</a>"';
            if (obj.round !== '') {
                result = result + ' in "' + obj.round + '"'; 
            }
        }
    }
    if (result.length) {
        var mydiv = $("#" + div_id);
        mydiv.trigger(jQuery.Event("prerender"),type);
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
