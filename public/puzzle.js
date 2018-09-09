$(document).ready(
    function() {
        $('.submit-modal').on('click', function(e) {
            $(this).parents('.modal-form').first().find('input[name="last-button"]').attr('value', $(this).html());
        });
        $('#initial-puzzle-info-modal').modal('show');
    }
);

                  
