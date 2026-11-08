// Serial numbers are hidden on the cards of the check list edit page. The checkbox
// "show serial numbers" shows them again; the choice is kept in the local storage.
// (The item filter finds items by serial number whether they are shown or not.)
$(function() {
  var toggle = $('#show_serials');
  if (!toggle.length) { return; }

  var KEY = 'wink:show_serials';

  var apply = function(show) {
    $('body').toggleClass('show_serials', show);
    toggle.prop('checked', show);
  };

  var stored = false;
  try { stored = window.localStorage.getItem(KEY) === '1'; } catch (e) { /* ignore */ }
  apply(stored);

  toggle.on('change', function() {
    var show = this.checked;
    apply(show);
    try { window.localStorage.setItem(KEY, show ? '1' : '0'); } catch (e) { /* ignore */ }
  });
});
