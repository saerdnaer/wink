// Remembers the user name (advisor / comment author) on this device, so it only
// has to be typed once. Fields opt in with data-remember-username.
$(function() {
  var KEY = 'wink:username';
  var fields = $('input[data-remember-username]');
  if (!fields.length) { return; }

  try {
    var saved = window.localStorage.getItem(KEY);
    if (saved) {
      fields.each(function() {
        if (!$(this).val()) { $(this).val(saved); }
      });
    }
  } catch (e) { /* local storage not available (e.g. private mode) */ }

  fields.on('input change', function() {
    try {
      window.localStorage.setItem(KEY, String($(this).val()).trim());
    } catch (e) { /* ignore */ }
  });
});
