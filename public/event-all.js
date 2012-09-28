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
    $(".team-info").each(
        function(index,self) {
            setInterval(function(){refreshTeam(self)},5000);
        }
    );
});


function refreshTeam(self) {
    $(self).load("/event/refresh", {"team-id": $(self).attr("team_id") } );
}
