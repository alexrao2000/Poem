/* One local recovery record per save slot. No network or engine-private APIs. */
window.poemSaveJournal = {
  key(path) { return 'poem.save-journal.v1:' + path; },
  read(path) {
    try { return window.localStorage.getItem(this.key(path)) || ''; }
    catch (_) { return ''; }
  },
  write(path, record) {
    try {
      const key = this.key(path);
      window.localStorage.setItem(key, record);
      return window.localStorage.getItem(key) === record;
    } catch (_) { return false; }
  }
};
