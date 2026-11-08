// Sections (shelves, boxes, ...) of the check list edit page:
//  * "later" moves a section to the end of the list,
//  * a long press on the headline (or a click on its triangle) folds / unfolds it.
// Order and folded sections are remembered in the local storage of the browser.
$(function() {
  var form = $('form[data-check-list-id]');
  var sections = function() { return $('.noborder').has('h3.section_heading'); };
  if (!form.length || !sections().length) { return; }

  var KEY = 'wink:check_list_view:' + form.data('check-list-id');
  var LONG_PRESS_MS = 600;
  var MAX_AGE = 14 * 24 * 60 * 60 * 1000; // two weeks

  var section_id = function(section) { return section.find('h3.section_heading').attr('id'); };

  var load = function() {
    try {
      var stored = JSON.parse(window.localStorage.getItem(KEY));
      if (stored && Date.now() - stored.savedAt < MAX_AGE) { return stored; }
    } catch (e) { /* ignore */ }
    return { order: [], folded: [] };
  };

  var save = function() {
    var state = {
      order: sections().map(function() { return section_id($(this)); }).get(),
      folded: sections().filter('.folded').map(function() { return section_id($(this)); }).get(),
      savedAt: Date.now()
    };
    try { window.localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* ignore */ }
  };

  var set_folded = function(section, folded) {
    section.toggleClass('folded', folded);
    section.find('.fold_toggle').text(folded ? '▶' : '▼').attr('aria-expanded', folded ? 'false' : 'true');
  };

  // restore the view of an earlier visit
  var stored = load();
  stored.order.forEach(function(id) {
    var section = sections().filter(function() { return section_id($(this)) === id; });
    if (section.length) { sections().last().after(section); }
  });
  sections().each(function() { set_folded($(this), stored.folded.indexOf(section_id($(this))) !== -1); });

  // "later": the section moves behind the last one
  $(document).on('click', '.section_later', function(event) {
    event.preventDefault();
    event.stopPropagation();
    var section = $(this).closest('.noborder');
    var last = sections().last();
    if (last[0] !== section[0]) { last.after(section); }
    save();
  });

  // click on the triangle
  $(document).on('click', '.fold_toggle', function(event) {
    event.preventDefault();
    event.stopPropagation();
    var section = $(this).closest('.noborder');
    set_folded(section, !section.hasClass('folded'));
    save();
  });

  // long press on the headline
  sections().find('h3.section_heading').each(function() {
    var heading = $(this);
    var timer = null;
    var start = null;
    var cancel = function() { clearTimeout(timer); timer = null; };

    heading.on('pointerdown', function(event) {
      if (event.button > 0 || $(event.target).closest('.section_later, .fold_toggle, .section_edit').length) { return; }
      start = { x: event.clientX, y: event.clientY };
      cancel();
      timer = setTimeout(function() {
        timer = null;
        var section = heading.closest('.noborder');
        set_folded(section, !section.hasClass('folded'));
        save();
        heading.data('long_pressed', true);
        if (navigator.vibrate) { navigator.vibrate(30); }
      }, LONG_PRESS_MS);
    });
    // scrolling or dragging is not a long press
    heading.on('pointermove', function(event) {
      if (timer && start && Math.hypot(event.clientX - start.x, event.clientY - start.y) > 10) { cancel(); }
    });
    heading.on('pointerup pointercancel pointerleave', cancel);
    // no context menu from a long press on touch devices
    heading.on('contextmenu', function(event) { if (heading.data('long_pressed')) { event.preventDefault(); } });
    // the click that ends a long press is not a double-click candidate
    heading.on('click', function() {
      if (heading.data('long_pressed')) { heading.data('long_pressed', false); }
    });
  });

  // a deep link into a folded section unfolds it
  var unfold_target = function() {
    var target = document.getElementById(decodeURIComponent(window.location.hash.substring(1)));
    var section = target ? $(target).closest('.noborder.folded') : $();
    if (section.length) {
      set_folded(section, false);
      save();
      target.scrollIntoView({ block: 'center' });
    }
  };
  unfold_target();
  $(window).on('hashchange', unfold_target);
});
