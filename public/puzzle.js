$(document).ready(
    function() {
        $('.modal-form').on('submit', function(e) {
            jQuery.post('/puzzle/modal', $(this).serialize());
            $(this).parents('.modal').first().modal('hide');
            return false;
        });
        $('.submit-modal').on('click', function(e) {
            $(this).parents('.modal-form').first().find('input[name="last-button"]').attr('value', $(this).html());
        });
        $('#initial-puzzle-info-modal').modal('show');
    }
);

                  
