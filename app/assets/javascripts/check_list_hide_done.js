// Checkbox "hide checked items" on the check list edit page: ticked items, complete stacks
// and complete sections are hidden, so only what is still to do stays visible.
// The choice is kept in the local storage.
$(function() {
  var toggle = $('#hide_done');
  if (!toggle.length) { return; }

  var KEY = 'wink:hide_done';

  var refresh = function() {
    var hide = toggle.prop('checked');
    $('body').toggleClass('hide_done', hide);

    $('.checklist_item').each(function() {
      $(this).toggleClass('done', $(this).find('input[type="checkbox"]').prop('checked'));
    });
    $('.checklist_stack').each(function() {
      $(this).toggleClass('done', $(this).find('.checklist_item:not(.done)').length === 0);
    });
    $('.noborder').each(function() {
      var items = $(this).find('.checklist_item');
      $(this).toggleClass('done', items.length > 0 && items.not('.done').length === 0);
    });
  };

  var stored = false;
  try { stored = window.localStorage.getItem(KEY) === '1'; } catch (e) { /* ignore */ }
  toggle.prop('checked', stored);

  toggle.on('change', function() {
    try { window.localStorage.setItem(KEY, this.checked ? '1' : '0'); } catch (e) { /* ignore */ }
    refresh();
  });
  // the other scripts trigger "change" on the item checkboxes
  $(document).on('change', '.checklist_item input[type="checkbox"]', refresh);
  refresh();
});
