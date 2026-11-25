const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const elements = new Map();
let focusCount = 0;
const document = {
  getElementById: (id) => elements.get(id),
  body: { append: (element) => elements.set(element.id, element) },
  createElement(tag) {
    assert.equal(tag, 'input');
    return {
      listeners: new Map(),
      addEventListener(name, callback) { this.listeners.set(name, callback); },
      click() { this.clicked = true; },
      remove() { if (elements.get(this.id) === this) elements.delete(this.id); },
    };
  },
};
elements.set('canvas', { focus: () => focusCount++ });

const browser = { window: {}, document, btoa: (text) => Buffer.from(text, 'latin1').toString('base64') };
const script = fs.readFileSync(path.join(__dirname, '../scripts/web_campaign_files.js'), 'utf8');
vm.runInNewContext(script, browser);
const files = browser.window.poemCampaignFiles;
const pickerId = 'poem-campaign-file';
const results = [];

function choose(file) {
  files.open(256, (error, text) => results.push({ error, text }));
  const picker = elements.get(pickerId);
  assert.equal(picker.type, 'file');
  assert.equal(picker.accept, '.json,application/json');
  assert.ok(picker.hidden && picker.clicked);
  picker.files = file ? [file] : [];
  return picker;
}

async function run() {
  const valid = choose({ size: 12, text: async () => '{"title":"Trial"}' });
  await valid.listeners.get('change')();
  assert.deepEqual(results, [{ error: '', text: '{"title":"Trial"}' }]);
  assert.ok(!elements.has(pickerId));

  const large = choose({ size: 257, text() { assert.fail('Oversized file was read.'); } });
  await large.listeners.get('change')();
  assert.match(results.at(-1).error, /too large/);

  const unreadable = choose({ size: 1, text: async () => { throw new Error('unreadable'); } });
  await unreadable.listeners.get('change')();
  assert.match(results.at(-1).error, /Could not read/);

  choose().listeners.get('cancel')();
  assert.equal(results.length, 3);
  assert.equal(focusCount, 4);
  assert.ok(!elements.has(pickerId));

  let complete;
  const pending = choose({ size: 5, text: () => new Promise((resolve) => { complete = resolve; }) });
  const read = pending.listeners.get('change')();
  const current = choose({ size: 2, text: async () => '{}' });
  complete('old');
  await read;
  assert.equal(results.length, 3);
  await current.listeners.get('change')();
  assert.deepEqual(results.at(-1), { error: '', text: '{}' });

  const closed = choose({ size: 5, text: () => new Promise((resolve) => { complete = resolve; }) });
  const closedRead = closed.listeners.get('change')();
  files.cancel();
  complete('closed');
  await closedRead;
  assert.equal(results.length, 4);
  assert.ok(!elements.has(pickerId));

  files.open(256, (error, text) => results.push({ error, text }), '.png,.jpg', true);
  const image = elements.get(pickerId);
  assert.equal(image.accept, '.png,.jpg');
  image.files = [{ size: 3, arrayBuffer: async () => Uint8Array.of(0, 255, 127).buffer }];
  await image.listeners.get('change')();
  assert.deepEqual(results.at(-1), { error: '', text: 'AP9/' });

  function chooseCode(file) {
    files.open(32, (error, text) => results.push({ error, text }), '.txt,text/plain', false, true);
    const picker = elements.get(pickerId);
    assert.equal(picker.accept, '.txt,text/plain');
    picker.files = [file];
    return picker.listeners.get('change')();
  }
  await chooseCode({ size: 10, text: async () => 'POEM1:e30=' });
  assert.deepEqual(results.at(-1), { error: '', text: 'POEM1:e30=' });
  await chooseCode({ size: 33, text: () => assert.fail('Oversized save code was read.') });
  assert.deepEqual(results.at(-1), { error: 'This save code file is too large.', text: '' });
  await chooseCode({ size: 16, text: async () => { throw new Error('read'); } });
  assert.deepEqual(results.at(-1), { error: 'Could not read the save code file.', text: '' });
  const reading = chooseCode({ size: 10, text: () => new Promise((resolve) => { complete = resolve; }) });
  const resultCount = results.length;
  files.cancel();
  complete('old code');
  await reading;
  assert.equal(results.length, resultCount);
  console.log('PASS: browser campaign file chooser, atlas bytes, read limits, cancel focus, and stale read isolation for campaign and save files');
}

run().catch((error) => { console.error(error); process.exitCode = 1; });
