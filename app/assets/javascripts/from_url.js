// Pasting a link into an "Create ... from URL" field imports it right away.
$(function() {
  $('.from_url_form input[type="url"]').on('paste', function() {
    var input = $(this);
    setTimeout(function() {
      if (/^https?:\/\/\S+$/.test(String(input.val()).trim())) {
        input.closest('form').find('input[type="submit"]').click();
      }
    }, 0);
  });
});
