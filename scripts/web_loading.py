"""Add the game's loading presentation around the bundled Godot loader controls.

Owned markers make repeated packing safe. Required template anchors fail closed
if a future engine template changes; startup and progress callbacks stay intact.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(source, pattern, replacement):
    result, count = re.subn(pattern, lambda match: replacement, source, flags=re.DOTALL)
    if count != 1:
        raise ValueError("Expected exactly one Godot loading template anchor")
    return result


def decorate_loader(source):
    css = (ROOT / "web/loading.css").read_text()
    panel = (ROOT / "web/loading-panel.html").read_text().strip()
    style = '<!-- poem-loading-style:start -->\n<style id="poem-loading-style">\n' + css + '</style>\n<!-- poem-loading-style:end -->'
    content = '<!-- poem-loading-panel:start -->\n' + panel + '\n<!-- poem-loading-panel:end -->'
    if '<!-- poem-loading-style:start -->' in source:
        source = replace_once(source, r'<!-- poem-loading-style:start -->.*?<!-- poem-loading-style:end -->', style)
    else:
        source = replace_once(source, r'</head>', style + '\n</head>')
    if '<!-- poem-loading-panel:start -->' in source:
        source = replace_once(source, r'<!-- poem-loading-panel:start -->.*?<!-- poem-loading-panel:end -->', content)
    else:
        source = replace_once(source, r'<progress id="status-progress"></progress>\s*<div id="status-notice"></div>', content)
    hook = 'statusOverlay.dataset.poemMode = mode;'
    if hook not in source:
        source = replace_once(source, r'statusMode = mode;', 'statusMode = mode;\n\t\t' + hook)
    return source
