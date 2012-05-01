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
        $(window).resize(function() {
            resize_chat_box($("#chat-box"));
        });
        $("#chat-box").accordion({
            clearStyle: true,
            fillSpace: true,
            change: function(event, ui) { 
                $(".ui-accordion-content").css({padding:'0px 0px 0px 0px'});
                $(".ui-accordion-content").css({margin:'0px 0px 0px 0px'});
                resize_chat_box($("#chat-box"));
            }

        });
        $("#chat-box").accordion("activate",1);
    }
);

function resize_chat_box(cb) {
    var target = $(window).height();
    var outer_current = cb.height();
    inner = cb.children('.ui-accordion-content-active').children('.chat-text').first();
    inner_current = inner.height();
    console.warn(inner_current);

    cb.siblings().each(
        function() {
            target = target - $(this).outerHeight(true);
        }
    );
    if (target < 200) {
        target = 200;
    }
    console.warn([inner_current, target,outer_current].join(':'));
    inner.height(inner_current + target - outer_current - 10 );
    inner.scrollTop(inner.prop("scrollHeight") - inner.height() );
}
          
var last_seen = new Object();
last_seen.event = new Array();
last_seen.puzzle = new Array();


function setup_chat_filler(type, puzzle_id) {
    console.log ("setup" + type + ' ' + puzzle_id);
    chat_filler(type,puzzle_id);
    setInterval(function() {chat_filler(type,puzzle_id);},5000);
}

function chat_filler (type, puzzle_id) {
    var last_seen_id = 0;
    console.warn(type + ' ' + puzzle_id);
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
                });
}

                               
function render_msg (type, text, ts, author, div_id) {
    var result = '';
    var d = new Date(ts*1000); 
    var ds = d.getMonth()+1 + '/' + d.getDate() + ' ' +
        (d.getHours() < 10 ? '0' : '') + d.getHours() + ':' + 
        (d.getMinutes() < 10 ? 0 : '') + d.getMinutes() + ':' + 
        (d.getSeconds() < 10 ? 0 : '') + d.getSeconds() + ': ';
    if (type === 'created') {
        result = ds + 'Created';
    }
    if (type === 'spreadsheet') {
        result = ds + '<A HREF="' + text + '">Spreadsheet assigned</A>';
    }
    if (type === 'chat') {
        result = ds + '<B>' + author + '</B>: ' + $('<div/>').text(text).html();
    }
    if (result.length) {
        var mydiv = $("#" + div_id);
        mydiv.append('<br/>' + result );
        mydiv.scrollTop(mydiv.prop("scrollHeight") - mydiv.height() );
    }
}
                  
