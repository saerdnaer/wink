// "+ add my name" on the check list edit page: puts the name of the user (remembered
// in the local storage by remember_username.js, asked for once if unknown) on the
// list of advisors of the check list.
$(function() {
  var line = $('.check_list_advisor[data-add-advisor-url]');
  if (!line.length) { return; }

  var KEY = 'wink:username';
  var button = line.find('.add_my_name');
  var names = line.find('.advisor_names');

  var stored_name = function() {
    try { return String(window.localStorage.getItem(KEY) || '').trim(); } catch (e) { return ''; }
  };

  var listed = function(name) {
    var existing = names.text().split(/\s*(?:,|&|\band\b)\s*/i);
    return existing.some(function(entry) { return entry.trim().toLowerCase() === name.toLowerCase(); });
  };

  var refresh = function() {
    var name = stored_name();
    if (name && listed(name)) {
      button.prop('disabled', true).text('✓ ' + name + ' is listed');
    } else {
      button.prop('disabled', false).text(name ? '+ add ' + name : '+ add my name');
    }
  };

  button.on('click', function() {
    var name = stored_name();
    if (!name) {
      name = String(window.prompt('Your name:') || '').trim();
      if (!name) { return; }
      try { window.localStorage.setItem(KEY, name); } catch (e) { /* ignore */ }
    }

    button.prop('disabled', true);
    $.ajax({
      url: line.data('add-advisor-url'),
      method: 'POST',
      data: { name: name },
      headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
    }).done(function(response) {
      names.text(response.advisor);
      refresh();
    }).fail(function() {
      button.prop('disabled', false).text('could not add the name, try again');
    });
  });

  refresh();
});
