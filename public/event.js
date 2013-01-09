var hide_closed_rows = false;
$(document).ready(
    function() {
        resize_ept();
        $(window).resize(function() {
            resize_ept();
        });
        $("#form-round-list").on('liveupdate', function () {
            resize_ept();
        });
        $("#show-closed-button").click(function(button) {
            hide_closed_rows = ! hide_closed_rows;
            apply_hide_closed_rows();
            jQuery.post('/event/modal', { formname : 'hide_closed', 
                                          hide_closed : hide_closed_rows,
                                          eventid : $(this).attr('event_id')
                                        }
                       );
        });
        $('form').submit(function() {
            var parent_form = $(this);
            parent_form.find('.alert').alert('close');
            var modal_post = jQuery.post('/event/modal', $(this).serializeArray(), null, 'text');
            modal_post.success(function() {
                parent_form.closest('div').slideUp('fast', function() {
                    resize_ept();
                    parent_form[0].reset();
                });
            });
            modal_post.error(function(result) {
                console.warn(result);
                parent_form.prepend('<div class="alert alert-error"><button type="button" class="close" data-dismiss="alert">&times;</button><span class="warning_text">' + result.responseText + '</span></div>');
                // 'closed' triggeres before the alert is gone, so we need to wait...
                parent_form.find('.alert').on('closed',function () {
                    setTimeout("resize_ept()",50);
                    setTimeout("resize_ept()", 1000);
                });
                resize_ept();
            });
            return false;
        });
        $(".add-a-round-button").click(function() {
            $("#new-puzzle-form-well").slideUp('fast').find('.alert').alert('close');
            $("#new-round-form-well").slideToggle('fast', function() {
                resize_ept();
                reset_inputs($("#new-puzzle-form-well"));
                reset_inputs($("#new-round-form-well"));
            }).find('.alert').alert('close');
        });
        $(".add-a-puzzle-button").click(function() {
            $("#new-round-form-well").slideUp('fast').find('.alert').alert('close');
            $("#new-puzzle-form-well").slideToggle('fast',function() {
                resize_ept();
                reset_inputs($("#new-puzzle-form-well"));
                reset_inputs($("#new-round-form-well"));
            }).find('.alert').alert('close');
        });
    }
);

function reset_inputs(ancestor) {
    ancestor.find('form').each (function() { this.reset(); });
}

function resize_ept() {
    var target = $(window).height();
    $('.event-puzzle-table').siblings(":visible").each(
        function() {
            target = target - $(this).outerHeight(true);
        }
    );

    $('.event-puzzle-table').height(target);
}

function apply_hide_closed_rows() {
    if (hide_closed_rows) {
        $('.closed-row').hide();
        $("#show-closed-button").html("Show Closed Puzzles");
        $('.dead-rounds').hide();
    } else {
        $('.closed-row').show();
        $("#show-closed-button").html("Hide Closed Puzzles");
        $('.dead-rounds').show();
    }
}
        
