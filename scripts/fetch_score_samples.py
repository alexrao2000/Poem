"""Fetch pinned CC0 source recordings into the ignored local tools cache.

The committed manifest uses Git blob hashes from the upstream revision. Samples
are build inputs only; game exports contain the rendered original arrangements.
"""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / 'assets/audio/orchestra-sources.json'
CACHE = ROOT / '.tools/vsco'


def git_hash(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def fetch(entry, revision):
    target = CACHE / entry['path']
    if target.is_file() and git_hash(target.read_bytes()) == entry['git_blob']:
        return target.stat().st_size
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + '.download')
    url = f'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{revision}/' + quote(entry['path'])
    subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location', '--retry', '2',
                    '--max-time', '60', '--output', str(temporary), url], check=True)
    data = temporary.read_bytes()
    if git_hash(data) != entry['git_blob']:
        temporary.unlink()
        raise ValueError('Source hash differs from pinned revision: ' + entry['path'])
    temporary.replace(target)
    return len(data)


def main():
    manifest = json.loads(MANIFEST.read_text())
    entries = manifest['samples'] + [manifest['license_file']]
    with ThreadPoolExecutor(max_workers=4) as pool:
        sizes = list(pool.map(lambda entry: fetch(entry, manifest['revision']), entries))
    (ROOT / 'assets/audio/VSCO-LICENSE.txt').write_bytes((CACHE / 'LICENSE').read_bytes())
    print(f"Verified {len(manifest['samples'])} recordings; {sum(sizes)/1_000_000:.1f} MB cached locally.")


if __name__ == '__main__':
    main()
