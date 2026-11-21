#!/usr/bin/env python3
"""Record nine bounded campaign experiments using five matching seeds.

Campaign failures are results, not test failures. Engine/assertion failures are
errors; an incomplete record is retained for diagnosis. No player saves are used.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

from test_process import run_engine

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "build/review/matched-experiments.json")
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    log = output.with_suffix(".log")
    engine_log = output.with_suffix(".engine.log")
    if len({output, log, engine_log}) != 3:
        parser.error("--output must use a distinct result extension, such as .json")
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=normal"], cwd=ROOT, text=True))
    command = [os.environ.get("GODOT_BIN", "godot"), "--headless", "--log-file", str(engine_log),
               "--path", str(ROOT), "--script", str(ROOT / "scripts/benchmark_experiments.gd"),
               "--", str(output), source, "dirty" if dirty else "clean"]
    try:
        result = run_engine(command, cwd=ROOT, timeout=600)
    except subprocess.TimeoutExpired as error:
        text = error.stdout or ""
        if isinstance(text, bytes):
            text = text.decode(errors="replace")
        log.write_text(text)
        raise SystemExit(f"FAIL: comparison exceeded 600 seconds; partial output at {output}")
    log.write_text(result.stdout)
    print(result.stdout, end="", flush=True)
    errors = [line for line in result.stdout.splitlines()
              if line.startswith("ERROR:") and 'Condition "ret != noErr"' not in line]
    if result.returncode or errors or "SCRIPT ERROR:" in result.stdout or "PASS: 45 bounded" not in result.stdout:
        raise SystemExit(f"FAIL: comparison did not finish; inspect {log}")
    report = json.loads(output.read_text())
    expected = {(profile["id"], seed) for profile in report["profiles"] for seed in report["seeds"]}
    actual = [(run["profile"], run["seed"]) for run in report["runs"]]
    if (not report["complete"] or len(expected) != 45 or len(actual) != 45
            or set(actual) != expected or report["source"] != source
            or report["source_dirty"] != dirty):
        raise SystemExit(f"FAIL: incomplete comparison record at {output}")
    print(f"Recorded {len(actual)} campaigns in {output}")


if __name__ == "__main__":
    main()
