// Exercise the actual exported Godot loader with DOM/engine doubles. No browser
// is opened; this verifies startup ownership and failure/progress handling only.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const htmlPath = process.argv[2] || path.join(__dirname, '../build/web/index.html');
const html = fs.readFileSync(htmlPath, 'utf8');
const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
assert.equal(new Set(ids).size, ids.length, 'The wrapped loader retains unique control IDs');
for (const id of ['canvas', 'status', 'status-splash', 'status-progress', 'status-notice', 'poem-loading-card', 'poem-loading-title', 'poem-loading-label']) {
  assert(ids.includes(id), `Export includes ${id}`);
}
assert(html.includes('for="status-progress"') && html.includes('id="status-notice" role="alert"'));
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(match => match[1]);
const loaders = scripts.filter(source => source.includes('const GODOT_CONFIG'));
assert.equal(loaders.length, 1);
const source = loaders[0];
const settle = () => new Promise(resolve => setImmediate(resolve));

function fixture(missing = []) {
  const nodes = new Map(ids.map(id => [id, {
    id, style: {}, dataset: {}, children: [], removed: false,
    get lastChild() { return this.children.at(-1); },
    appendChild(child) { this.children.push(child); },
    removeChild(child) { this.children.splice(this.children.indexOf(child), 1); },
    removeAttribute(name) { delete this[name]; },
    remove() { this.removed = true; }
  }]));
  const calls = {starts: 0, errors: []};
  class Engine {
    constructor(config) { calls.config = config; }
    static getMissingFeatures() { return missing; }
    startGame(options) {
      calls.starts += 1;
      calls.options = options;
      return new Promise((resolve, reject) => { calls.resolve = resolve; calls.reject = reject; });
    }
  }
  const document = {
    getElementById(id) { assert(nodes.has(id)); return nodes.get(id); },
    createTextNode(text) { return {kind: 'text', text}; },
    createElement(tag) { return {kind: tag}; }
  };
  vm.runInNewContext(source, {Engine, document, navigator: {}, Error, console: {error: error => calls.errors.push(error)}, setTimeout});
  return {nodes, calls};
}

async function run() {
  const {nodes, calls} = fixture();
  const overlay = nodes.get('status');
  const progress = nodes.get('status-progress');
  assert.equal(calls.starts, 1);
  assert.equal(calls.config.focusCanvas, true, 'Engine retains focus ownership at startup');
  assert.equal(overlay.dataset.poemMode, 'progress');
  assert.equal(overlay.style.visibility, 'visible');
  assert.equal(progress.style.display, 'block');
  calls.options.onProgress(25, 100);
  assert.equal(progress.value, 25);
  assert.equal(progress.max, 100);
  calls.options.onProgress(0, 0);
  assert(!('value' in progress) && !('max' in progress), 'Unknown totals retain native indeterminate progress');
  calls.options.onProgress(100, 100);
  assert.equal(overlay.removed, false, 'Download completion alone does not reveal an unstarted game');
  calls.resolve();
  await settle();
  assert.equal(overlay.removed, true, 'Only successful engine startup removes the entire loading overlay');
  assert.equal(nodes.get('canvas').removed, false);

  for (const failure of [new Error('Download failed'), '<img src=x onerror=bad>\nTry again', {unknown: true}]) {
    const failed = fixture();
    failed.calls.reject(failure);
    await settle();
    const status = failed.nodes.get('status');
    const notice = failed.nodes.get('status-notice');
    assert.equal(status.removed, false);
    assert.equal(status.dataset.poemMode, 'notice');
    assert.equal(notice.style.display, 'block');
    assert.equal(failed.nodes.get('status-progress').style.display, 'none');
    assert(notice.children.length > 0 && notice.children.every(child => ['text', 'br'].includes(child.kind)), 'Errors remain text, never injected HTML');
    assert.equal(failed.nodes.get('canvas').removed, false);
  }

  const unsupported = fixture(['WebGL2']);
  assert.equal(unsupported.calls.starts, 0, 'Missing browser features do not attempt game startup');
  assert.equal(unsupported.nodes.get('status').dataset.poemMode, 'notice');
  assert(unsupported.nodes.get('status-notice').children.some(child => child.text?.includes('WebGL2')));
  console.log('PASS: exported loading controls, accessible labels, known/unknown progress, startup-only dismissal, retained canvas/focus and safe failed/unsupported startup notices (DOM/engine doubles, not browser rendering)');
}

run().catch(error => { console.error(error); process.exitCode = 1; });
