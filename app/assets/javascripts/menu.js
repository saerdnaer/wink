// Burger menu for small screens: the button is only visible there (CSS).
$(function() {
  var menu = $('#menu');
  var toggle = $('#menu_toggle');

  toggle.on('click', function() {
    var open = menu.toggleClass('open').hasClass('open');
    toggle.attr('aria-expanded', open ? 'true' : 'false');
  });
});
