// Exercise the shipped JavaScript with a storage double, without opening a browser.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const records = new Map();
let failure = '';
const localStorage = {
  getItem(key) {
    if (failure === 'read') throw new Error('SecurityError');
    return records.get(key) ?? null;
  },
  setItem(key, value) {
    if (failure === 'write') throw new Error('QuotaExceededError');
    if (failure !== 'discard') records.set(key, value);
  }
};
const context = vm.createContext({window: {localStorage}});
const source = fs.readFileSync(new URL('../scripts/browser_journal.js', `file://${__filename}`), 'utf8');
vm.runInContext(source, context);
const journal = context.window.poemSaveJournal;
const path = 'user://campaign.json';
const record = JSON.stringify({name: "A quote ' and newline\n", save_sequence: 2});
assert.equal(journal.read(path), '');
assert.equal(journal.write(path, record), true);
assert.equal(journal.read(path), record);
assert.equal(journal.write(`${path}.debug`, 'sandbox'), true);
assert.equal(journal.read(path), record);
failure = 'write';
assert.equal(journal.write(path, 'replacement'), false);
assert.equal(journal.read(path), record);
failure = 'discard';
assert.equal(journal.write(path, 'replacement'), false);
failure = 'read';
assert.equal(journal.read(path), '');
assert.equal(journal.write(path, 'replacement'), false);
failure = '';
vm.runInContext(source, context);
assert.equal(context.window.poemSaveJournal.read(path), 'replacement');
// Some browser configurations reject even access to the localStorage property.
Object.defineProperty(context.window, 'localStorage', {get() { throw new Error('SecurityError'); }});
assert.equal(journal.read(path), '');
assert.equal(journal.write(path, record), false);
console.log('PASS: browser journal round trip, slot isolation, quota/security errors and read-back verification');
