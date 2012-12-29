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
                setInterval(function(){refresh_puzzles(self)},5000);
                refresh_puzzles(self);
            }
        );
    }
);


function refresh_puzzles(self) {
    $(self).load("/event/refresh-puzzle-table", {"event-id": $(self).attr("event_id") } )
};
