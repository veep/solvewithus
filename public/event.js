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
        $(".event-puzzle-table").each(
            function(index,self) {
                setInterval(function(){refresh_puzzles(self, hide_closed_rows)},5000);
                refresh_puzzles(self, hide_closed_rows);
            }
        );
    }
);


function refresh_puzzles(self, hide_closed) {
    $(self).load("/event/refresh-puzzle-table", {"event-id": $(self).attr("event_id"), "hide-closed": hide_closed},
                 function() {
                     apply_hide_closed_rows();
                     $("#show-closed-button").click(function(button) {
                         hide_closed_rows = ! hide_closed_rows;
                         apply_hide_closed_rows();
                     });
                 });
};

function apply_hide_closed_rows() {
    if (hide_closed_rows) {
        $('.closed-row').hide();
        $("#show-closed-button").html("Show Closed Puzzles");
    } else {
        $('.closed-row').show();
        $("#show-closed-button").html("Hide Closed Puzzles");
    }
}
        
