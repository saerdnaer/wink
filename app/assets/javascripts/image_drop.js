// Image drop zone for <input type="file" data-image-drop>.
//
// Turns the file input into a zone where an image can be
//   - dragged in from the file manager or the browser,
//   - pasted from the clipboard (Ctrl/Cmd+V, e.g. a screenshot or "Copy Image"),
//   - or chosen with a click (the normal file dialog).
// The chosen file is put into the real file input, so the form submit and the
// server side work exactly as without JavaScript (the plain input stays as fallback).
(function() {
  var ACCEPTED = /^image\/(png|jpeg|gif|webp)$/;
  var zones = [];
  var active = null; // zone that gets pasted images: last used / focused one

  function formatSize(bytes) {
    return bytes > 1048576 ? (bytes / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(bytes / 1024)) + ' KB';
  }

  function build(input) {
    var maxBytes = parseInt(input.getAttribute('data-max-bytes'), 10) || 5 * 1024 * 1024;

    var zone = document.createElement('div');
    zone.className = 'image_drop';
    zone.tabIndex = 0;
    zone.setAttribute('role', 'button');
    zone.innerHTML =
      '<img class="image_drop_preview" alt="" hidden>' +
      '<div class="image_drop_text">' +
        '<strong>Drop an image here</strong>, paste it (Ctrl/⌘+V) or click to choose a file' +
        '<span class="image_drop_file"></span>' +
        '<span class="image_drop_error"></span>' +
      '</div>' +
      '<button type="button" class="image_drop_clear" hidden>discard</button>';
    input.parentNode.insertBefore(zone, input);
    input.hidden = true;

    var preview = zone.querySelector('.image_drop_preview');
    var fileLabel = zone.querySelector('.image_drop_file');
    var errorLabel = zone.querySelector('.image_drop_error');
    var clear = zone.querySelector('.image_drop_clear');
    var objectUrl = null;

    function reset() {
      if (objectUrl) { URL.revokeObjectURL(objectUrl); objectUrl = null; }
      preview.hidden = true;
      preview.removeAttribute('src');
      clear.hidden = true;
      fileLabel.textContent = '';
      zone.classList.remove('has_file');
    }

    function error(message) { errorLabel.textContent = message || ''; }

    function setFile(file) {
      error('');
      if (!file) { return; }
      if (!ACCEPTED.test(file.type)) { error('Only PNG, JPEG, GIF or WebP images are possible.'); return; }
      if (file.size > maxBytes) { error('The image is too big (' + formatSize(file.size) + ', max ' + formatSize(maxBytes) + ').'); return; }

      try {
        var transfer = new DataTransfer();
        transfer.items.add(file);
        input.files = transfer.files;
      } catch (e) {
        error('This browser cannot take the image here, please use the file dialog.');
        input.hidden = false;
        return;
      }

      reset();
      objectUrl = URL.createObjectURL(file);
      preview.src = objectUrl;
      preview.hidden = false;
      clear.hidden = false;
      fileLabel.textContent = (file.name && file.name !== 'image.png' ? file.name + ' · ' : 'pasted image · ') + formatSize(file.size);
      zone.classList.add('has_file');

      // a new image replaces the current one: "remove image" would contradict it
      var remove = input.form && input.form.querySelector('input[name="remove_image"]');
      if (remove) { remove.checked = false; }
    }

    // click / keyboard: normal file dialog
    zone.addEventListener('click', function(event) {
      active = zone_api;
      if (event.target === clear) { return; }
      input.click();
    });
    zone.addEventListener('keydown', function(event) {
      if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); input.click(); }
    });
    input.addEventListener('change', function() {
      if (input.files && input.files[0]) { setFile(input.files[0]); } else { reset(); }
    });
    zone.addEventListener('focus', function() { active = zone_api; });

    clear.addEventListener('click', function(event) {
      event.stopPropagation();
      input.value = '';
      reset();
      error('');
    });

    // drag & drop
    ['dragenter', 'dragover'].forEach(function(name) {
      zone.addEventListener(name, function(event) {
        event.preventDefault();
        zone.classList.add('dragging');
      });
    });
    ['dragleave', 'dragend'].forEach(function(name) {
      zone.addEventListener(name, function() { zone.classList.remove('dragging'); });
    });
    zone.addEventListener('drop', function(event) {
      event.preventDefault();
      zone.classList.remove('dragging');
      active = zone_api;
      var files = event.dataTransfer && event.dataTransfer.files;
      if (files && files.length) { setFile(files[0]); }
    });

    var zone_api = { zone: zone, setFile: setFile };
    zones.push(zone_api);
    return zone_api;
  }

  // Paste: only an image in the clipboard is taken, pasted text still goes to the fields.
  document.addEventListener('paste', function(event) {
    if (!zones.length || !event.clipboardData) { return; }
    var files = event.clipboardData.files;
    var image = null;
    for (var i = 0; files && i < files.length; i++) {
      if (/^image\//.test(files[i].type)) { image = files[i]; break; }
    }
    if (!image) { return; }
    event.preventDefault();
    (active || zones[0]).setFile(image);
  });

  // keep a page-wide drop outside the zone from replacing the page with the image
  ['dragover', 'drop'].forEach(function(name) {
    window.addEventListener(name, function(event) {
      if (zones.length && event.dataTransfer && Array.prototype.indexOf.call(event.dataTransfer.types || [], 'Files') >= 0 &&
          !(event.target.closest && event.target.closest('.image_drop'))) {
        event.preventDefault();
      }
    });
  });

  document.addEventListener('DOMContentLoaded', function() {
    Array.prototype.forEach.call(document.querySelectorAll('input[type="file"][data-image-drop]'), build);
    if (zones.length) { active = zones[0]; }
  });
})();
