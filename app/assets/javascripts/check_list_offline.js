// Keeps the state of the check list edit page in the local storage of the browser,
// so a lost connection (or a closed tab) does not lose checked items.
//
// Only the differences to the state the server rendered are stored
// (input.checked != input.defaultChecked). When the page is opened again,
// stored differences the server already knows about are dropped and the rest is
// restored. Saving the form therefore cleans up by itself.
$(function() {
  var form = $('form[data-check-list-id]');
  if (!form.length) { return; }

  var KEY = 'wink:check_list:' + form.data('check-list-id');
  var MAX_AGE = 14 * 24 * 60 * 60 * 1000; // two weeks
  var inputs = form.find('input[type="checkbox"][name="check_list[checked_check_list_items][]"]');
  var restoring = false;

  var storage_get = function() {
    try {
      var stored = JSON.parse(window.localStorage.getItem(KEY));
      if (stored && stored.changes && Date.now() - stored.savedAt < MAX_AGE) { return stored.changes; }
    } catch (e) { /* ignore */ }
    return {};
  };

  var storage_set = function(changes) {
    try {
      if (Object.keys(changes).length) {
        window.localStorage.setItem(KEY, JSON.stringify({ changes: changes, savedAt: Date.now() }));
      } else {
        window.localStorage.removeItem(KEY);
      }
    } catch (e) { /* ignore */ }
  };

  // checked state of every input that differs from what the server rendered
  var pending_changes = function() {
    var changes = {};
    inputs.each(function() {
      if (this.checked !== this.defaultChecked) { changes[this.value] = this.checked; }
    });
    return changes;
  };

  var banner = $('<div id="offline_banner" class="offline_banner" style="display:none"></div>').insertBefore(form);

  var show_banner = function(html) {
    banner.html(html).show();
  };

  var refresh_banner = function() {
    var count = Object.keys(pending_changes()).length;

    if (!navigator.onLine) {
      show_banner('Offline – ' + count + ' unsaved change(s) are kept on this device. Press Save when you are back online.');
    } else if (count > 0) {
      show_banner(count + ' unsaved change(s) kept on this device. ' +
                  '<a href="#" class="offline_save">Save now</a> <a href="#" class="offline_discard">Discard</a>');
    } else {
      banner.hide();
    }
  };

  var persist = function() {
    if (restoring) { return; }
    storage_set(pending_changes());
    refresh_banner();
  };

  // restore changes of an earlier visit
  var stored = storage_get();
  restoring = true;
  Object.keys(stored).forEach(function(id) {
    var input = inputs.filter(function() { return this.value === id; });
    if (!input.length || input[0].defaultChecked === stored[id]) { return; }
    input.prop('checked', stored[id]).trigger('change');
  });
  restoring = false;
  persist();

  inputs.on('change', persist);

  banner.on('click', '.offline_save', function(event) {
    event.preventDefault();
    form.find('input[type="submit"]').first().click();
  });

  banner.on('click', '.offline_discard', function(event) {
    event.preventDefault();
    restoring = true;
    inputs.each(function() {
      if (this.checked !== this.defaultChecked) { $(this).prop('checked', this.defaultChecked).trigger('change'); }
    });
    restoring = false;
    persist();
  });

  // offline: do not send the form into the void, the changes stay on this device
  form.on('submit', function(event) {
    if (!navigator.onLine) {
      event.preventDefault();
      persist();
    }
  });

  $(window).on('online offline', refresh_banner);
});
