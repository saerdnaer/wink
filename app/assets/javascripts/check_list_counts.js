// Countable items (adapters, batteries, ...) of the check list edit page: a field to
// enter how many pieces were counted, with a note when it differs from the expected number.
$(function() {
  var fields = $('.count_field');
  if (!fields.length) { return; }

  var update = function(field) {
    var input = field.find('input');
    var note = field.find('.count_note');
    var value = String(input.val()).trim();
    var expected = parseInt(field.data('expected'), 10);

    field.removeClass('count_over count_under count_ok');
    if (value === '') { note.text(''); return; }

    var difference = parseInt(value, 10) - expected;
    if (difference > 0) {
      field.addClass('count_over');
      note.text(difference + ' more than expected (' + expected + ')');
    } else if (difference < 0) {
      field.addClass('count_under');
      note.text(-difference + ' fewer than expected (' + expected + ')');
    } else {
      field.addClass('count_ok');
      note.text('as expected');
    }
  };

  // typing in the field must not tick the card or start a long press on a stack
  fields.on('click pointerdown keydown', function(event) { event.stopPropagation(); });

  fields.each(function() { update($(this)); });
  fields.find('input').on('input change', function() { update($(this).closest('.count_field')); });
});
