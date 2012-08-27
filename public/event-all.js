$(function() {
    $("form").submit(function() {
        var target = $(this).closest("div").children("div");
        $.post
        (
            '/event/add', 
            $(this).children("input").each(function() {
                return $(this).val();
            }), 
            function(newhtml) {
                target.html(newhtml);
            }
        );
        $(this).children("input:text").each(function() {
            $(this).val("");
        });
        return false;
    });
});

                                
