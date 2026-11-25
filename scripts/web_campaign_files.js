/* Read the file selected by the campaign author on this device. */
(() => {
  let request = 0;
  window.poemCampaignFiles = {
    cancel() {
      request++;
      document.getElementById('poem-campaign-file')?.remove();
    },
    open(maxBytes, receive, accept = '.json,application/json', binary = false, saveCode = false) {
      const tooLarge = saveCode ? 'This save code file is too large.'
        : binary ? 'The atlas image exceeds 6 MB.' : 'This campaign document is too large.';
      const unreadable = saveCode ? 'Could not read the save code file.'
        : binary ? 'Could not read the atlas image.' : 'Could not read the campaign file.';
      const selection = ++request;
      document.getElementById('poem-campaign-file')?.remove();
      const picker = document.createElement('input');
      picker.id = 'poem-campaign-file';
      picker.type = 'file';
      picker.accept = accept;
      picker.hidden = true;
      const closePicker = () => {
        picker.remove();
        document.getElementById('canvas')?.focus();
      };
      picker.addEventListener('cancel', closePicker, {once: true});
      picker.addEventListener('change', async () => {
        const file = picker.files?.[0];
        closePicker();
        if (!file || selection !== request) return;
        if (file.size > maxBytes) {
          receive(tooLarge, '');
          return;
        }
        let raw;
        try {
          if (binary) {
            const buffer = new Uint8Array(await file.arrayBuffer());
            let characters = '';
            for (let offset = 0; offset < buffer.length; offset += 32768) {
              characters += String.fromCharCode(...buffer.subarray(offset, offset + 32768));
            }
            raw = btoa(characters);
          } else {
            raw = await file.text();
          }
        } catch {
          if (selection === request) receive(unreadable, '');
          return;
        }
        if (selection === request) receive('', raw);
      }, {once: true});
      document.body.append(picker);
      picker.click();
    }
  };
})();
