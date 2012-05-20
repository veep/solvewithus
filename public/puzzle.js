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
        $('[class*="collapse"]').on('shown hidden', function (event) {
            if (event.type == 'hidden') {
                $(this).prev().children("i").addClass("icon-plus").removeClass("icon-minus");
            } else {
                $(this).prev().children("i").addClass("icon-minus").removeClass("icon-plus");
            }
            resize_chat_box($("#chat-box"));
        });
        resize_chat_box($("#chat-box"));
        $('.dropdown-toggle').dropdown();

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
                  
