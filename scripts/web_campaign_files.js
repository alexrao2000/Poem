/* Read the file selected by the campaign author on this device. */
(() => {
  let request = 0;
  window.poemCampaignFiles = {
    cancel() {
      request++;
      document.getElementById('poem-campaign-file')?.remove();
    },
    open(maxBytes, receive) {
      const selection = ++request;
      document.getElementById('poem-campaign-file')?.remove();
      const picker = document.createElement('input');
      picker.id = 'poem-campaign-file';
      picker.type = 'file';
      picker.accept = '.json,application/json';
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
          receive('This campaign document is too large.', '');
          return;
        }
        let raw;
        try {
          raw = await file.text();
        } catch {
          if (selection === request) receive('Could not read the campaign file.', '');
          return;
        }
        if (selection === request) receive('', raw);
      }, {once: true});
      document.body.append(picker);
      picker.click();
    }
  };
})();
