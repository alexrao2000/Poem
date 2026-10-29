"""Compress the engine for static hosts with a per-file upload limit.
The loader decompresses to a WASM Response before Godot instantiates it.
Run after every Godot Web export. No server rewrite or custom headers required.
"""
from pathlib import Path
import gzip
root=Path(__file__).resolve().parents[1]/'build/web'
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
html.write_text(s)
