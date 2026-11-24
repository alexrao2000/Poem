"""Pack the engine and lossless splash for ordinary static hosting.
The loader decompresses to a WASM Response before Godot instantiates it.
Run after every Godot Web export.
"""
from pathlib import Path
import gzip
import os
import subprocess
from web_loading import decorate_loader
project=Path(__file__).resolve().parents[1]
root=project/'build/web'
wasm=root/'index.wasm'
if wasm.exists():
    (root/'index.wasm.gz').write_bytes(gzip.compress(wasm.read_bytes(),compresslevel=9,mtime=0))
    wasm.unlink()
html=root/'index.html'
s=html.read_text()
shim='''<script>
// Keep the official Godot loader; adapt only its engine download.
const originalFetch = window.fetch.bind(window);
window.fetch = async function(input, init) {
 const raw = typeof input === 'string' ? input : input.url;
 const url = new URL(raw, location.href);
 if (url.origin === location.origin && url.pathname.endsWith('/index.wasm')) {
   const response = await originalFetch(url.href + '.gz', init);
   if (!response.ok) throw new Error('Engine download failed: ' + response.status);
   return new Response(response.body.pipeThrough(new DecompressionStream('gzip')),
     {headers: {'Content-Type':'application/wasm'}});
 }
 return originalFetch(input, init);
};
</script>'''
if 'const originalFetch' not in s:s=s.replace('<script src="index.js"></script>',shim+'\n<script src="index.js"></script>')
source=decorate_loader(s)
splash=root/'index.png'
cover=root/'index.splash.webp'
if splash.is_file() or not cover.is_file():
    logs=root.parent/'logs'
    logs.mkdir(exist_ok=True)
    subprocess.run([
        os.environ.get('GODOT_BIN', 'godot'), '--headless', '--path', str(project),
        '--log-file', str(logs/'web-splash.log'), '--script', str(project/'web/encode-splash.gd'),
        '--', 'res://assets/art/title-dawn-v1.png', str(cover),
    ], check=True)
if not cover.is_file():raise FileNotFoundError(cover)
html.write_text(source)
splash.unlink(missing_ok=True)
