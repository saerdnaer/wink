// Keeps the state of the check list edit page in the local storage of the browser,
// so a lost connection (or a closed tab) does not lose checked items.
//
// Only the differences to the state the server rendered are stored
// (input.checked != input.defaultChecked). When the page is opened again,
// stored differences the server already knows about are dropped and the rest is
// restored. Saving the form therefore cleans up by itself.
$(function() {
  var MAX_AGE = 14 * 24 * 60 * 60 * 1000; // two weeks

  // Result page: tell the user about changes of this device that were never saved.
  // data-state holds the checked state the server knows ({check_list_item_id: checked}).
  var notice = $('#unsaved_notice');
  if (notice.length) {
    var notice_key = 'wink:check_list:' + notice.data('check-list-id');
    var server_state = notice.data('state') || {};
    var unsaved = 0;
    try {
      var saved = JSON.parse(window.localStorage.getItem(notice_key));
      if (saved && saved.changes && Date.now() - saved.savedAt < MAX_AGE) {
        Object.keys(saved.changes).forEach(function(id) {
          if (id in server_state && String(server_state[id]) !== String(saved.changes[id])) { unsaved += 1; }
        });
      }
    } catch (e) { /* ignore */ }

    if (unsaved > 0) {
      notice.html('<b>Unsaved changes:</b> ' + unsaved + ' change(s) made on this device were never saved. ' +
                  '<a href="' + notice.data('edit-url') + '" class="notice_continue">Continue checking and save</a> ' +
                  '<a href="#" class="notice_discard">Discard</a>').show();
      notice.on('click', '.notice_discard', function(event) {
        event.preventDefault();
        try { window.localStorage.removeItem(notice_key); } catch (e) { /* ignore */ }
        notice.hide();
      });
    }
  }

  var form = $('form[data-check-list-id]');
  if (!form.length) { return; }

  var KEY = 'wink:check_list:' + form.data('check-list-id');
  var inputs = form.find('input[type="checkbox"][name="check_list[checked_check_list_items][]"]');
  // counted pieces of countable items (check_list[counts][<id>]), stored as "count:<id>"
  var counts = form.find('input[name^="check_list[counts]"]');
  var count_id = function(input) { return /\[counts\]\[(\d+)\]/.exec(input.name)[1]; };
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
    counts.each(function() {
      if (this.value !== this.defaultValue) { changes['count:' + count_id(this)] = this.value; }
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
    if (id.indexOf('count:') === 0) {
      var count_input = counts.filter(function() { return count_id(this) === id.substring(6); });
      if (count_input.length && count_input[0].defaultValue !== String(stored[id])) {
        count_input.val(stored[id]).trigger('change');
      }
      return;
    }
    var input = inputs.filter(function() { return this.value === id; });
    if (!input.length || input[0].defaultChecked === stored[id]) { return; }
    input.prop('checked', stored[id]).trigger('change');
  });
  restoring = false;
  persist();

  inputs.on('change', persist);
  counts.on('input change', persist);

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
    counts.each(function() {
      if (this.value !== this.defaultValue) { $(this).val(this.defaultValue).trigger('change'); }
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

  // ---- leaving the page with unsaved changes -------------------------------
  var leaving = false;
  var go = function(url) {
    leaving = true;
    window.location.href = url;
  };

  // marks the current checkbox state as saved
  var mark_saved = function() {
    inputs.each(function() { this.defaultChecked = this.checked; });
    counts.each(function() { this.defaultValue = this.value; });
    persist();
  };

  var close_modal = function() { $('.leave_modal').remove(); };

  var ask_to_save = function(url) {
    var online = navigator.onLine;
    var count = Object.keys(pending_changes()).length;
    var html = '<div class="leave_modal"><div class="leave_modal_box" role="dialog" aria-modal="true">' +
      '<p><b>You have ' + count + ' unsaved change(s).</b></p>' +
      (online ? '<p>Do you want to save them before leaving this page?</p>'
              : '<p>You are offline, so they cannot be saved now. They stay on this device and can be saved later.</p>') +
      '<p class="leave_modal_error" style="display:none"></p>' +
      '<div class="leave_modal_actions">' +
      (online ? '<a href="#" class="leave_save">Save and leave</a>' : '') +
      '<a href="#" class="leave_discard">' + (online ? 'Leave without saving' : 'Leave') + '</a>' +
      '<a href="#" class="leave_stay">Stay on this page</a>' +
      '</div></div></div>';
    var modal = $(html).appendTo('body');
    modal.find('.leave_stay').focus();

    modal.on('click', '.leave_stay', function(event) { event.preventDefault(); close_modal(); });

    modal.on('click', '.leave_discard', function(event) {
      event.preventDefault();
      go(url); // the changes stay in the local storage and are offered again next time
    });

    modal.on('click', '.leave_save', function(event) {
      event.preventDefault();
      var request = $.ajax({ url: form.attr('action'), method: 'POST', data: form.serialize() });
      request.done(function() {
        mark_saved();
        go(url);
      });
      request.fail(function() {
        modal.find('.leave_modal_error').text('Saving failed. Your changes are still kept on this device.').show();
      });
    });
  };

  $(document).on('keydown', function(event) {
    if (event.key === 'Escape') { close_modal(); }
  });

  // links on the page
  $(document).on('click', 'a[href]', function(event) {
    var link = $(this);
    var href = link.attr('href');
    if (link.closest('.leave_modal').length) { return; }
    if (!href || href.charAt(0) === '#' || href.indexOf('javascript:') === 0) { return; }
    if (link.attr('target') === '_blank' || event.metaKey || event.ctrlKey || event.shiftKey) { return; }
    if (Object.keys(pending_changes()).length === 0) { return; }

    event.preventDefault();
    ask_to_save(this.href);
  });

  // saving through the form is not leaving
  form.on('submit', function() { if (navigator.onLine) { leaving = true; } });

  // closing the tab, reload, back button: the browser asks (generic text)
  $(window).on('beforeunload', function(event) {
    if (leaving || Object.keys(pending_changes()).length === 0) { return undefined; }
    event.preventDefault();
    event.returnValue = '';
    return '';
  });
});
