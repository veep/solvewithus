var hide_closed_rows = false;
$(document).ready(
    function() {
        $('.submit-modal').click(function () {
            $.post
            (
                '/event/modal', 
                $(this).parent().siblings(".modal-body").children("form").children().each(function() {
                    return $(this).val();
                })
            );
            $(this).parent().parent().modal('hide');
        });
        // 'shown' not 'show', so focus() can work.
        $('#newRoundModal').on('shown', function () {
            $(this).children().children('form').children('input[name="roundname"]').val('').focus();
        });
        $('.ModalForm').submit(function(event) {
            event.preventDefault();
            $.post
            (
                '/event/modal', 
                $(this).children().each(function() {
                    return $(this).val();
                })
                    );
            $(this).parent().parent().modal('hide');
        });
        resize_ept();
        $(window).resize(function() {
            resize_ept();
        });
        $("#show-closed-button").click(function(button) {
            hide_closed_rows = ! hide_closed_rows;
            apply_hide_closed_rows();
        });
    }
);

function resize_ept() {
    var target = $(window).height();
//    target=target-24;
    $('.event-puzzle-table').siblings().each(
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
        
