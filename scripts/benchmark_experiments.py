#!/usr/bin/env python3
"""Record bounded campaign experiments (default: nine profiles, five seeds).

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
DEFAULT_PROFILE_IDS = ("ordinary", "hard_recoverable", "hard_permanent", "hard_death_door",
                       "hard_sacrifice", "hard_legacy", "hard_sections", "hard_pressure", "hard_committed")
PROFILE_IDS = DEFAULT_PROFILE_IDS + ("hard_permanent_all", "hard_recoverable_all")
DEFAULT_SEEDS = [472019, 17, 309, 2026, 8675309]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "build/review/matched-experiments.json")
    parser.add_argument("--profile", action="append", choices=PROFILE_IDS,
                        help="Run only this profile; repeat for a matched comparison.")
    parser.add_argument("--seed", action="append", type=int,
                        help="Use this combat seed; repeat to compare seeds.")
    equipment = json.loads((ROOT / "data/equipment.json").read_text())
    parser.add_argument("--equip", action="append", choices=[item["id"] for item in equipment],
                        help="Equip this item when normally available or purchased; one per weapon kind.")
    parser.add_argument("--carry-patients", action="store_true",
                        help="Let allies rescue patients who are about to bleed out before a healer can reach them.")
    parser.add_argument("--retreat-chapter", action="append", type=int, default=[],
                        help="Retreat once at this chapter's first deployment. Repeat for multiple chapters.")
    args = parser.parse_args()
    profiles = args.profile or list(DEFAULT_PROFILE_IDS)
    seeds = args.seed or DEFAULT_SEEDS
    requested_equipment = args.equip or []
    if len(set(profiles)) != len(profiles) or len(set(seeds)) != len(seeds):
        parser.error("profiles and seeds must not be repeated")
    if any(seed < 0 or seed > 2**63 - 1 for seed in seeds):
        parser.error("seeds must be between 0 and 2^63 - 1")
    retreats = args.retreat_chapter
    if len(set(retreats)) != len(retreats) or any(chapter < 1 or chapter > 12 for chapter in retreats):
        parser.error("retreat chapters must be distinct chapter numbers between 1 and 12")
    kinds = [next(item["kind"] for item in equipment if item["id"] == item_id)
             for item_id in requested_equipment]
    if len(set(kinds)) != len(kinds):
        parser.error("choose at most one --equip item per weapon kind")
    # Godot's JSON parser reads numbers as floats; decimal strings preserve all
    # 63 permitted seed bits instead of rounding large replay identifiers.
    configuration = {"profiles": profiles, "seeds": [str(seed) for seed in seeds],
                     "equipment": requested_equipment, "carry_patients": args.carry_patients,
                     "retreat_chapters": retreats}
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
               "--", str(output), source, "dirty" if dirty else "clean", json.dumps(configuration)]
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
    count = len(profiles) * len(seeds)
    if result.returncode or errors or "SCRIPT ERROR:" in result.stdout or f"PASS: {count} bounded" not in result.stdout:
        raise SystemExit(f"FAIL: comparison did not finish; inspect {log}")
    report = json.loads(output.read_text())
    expected = {(profile, seed) for profile in profiles for seed in seeds}
    actual = [(run["profile"], run["seed"]) for run in report["runs"]]
    if (not report["complete"] or len(actual) != count
            or set(actual) != expected or report["source"] != source
            or report["source_dirty"] != dirty
            or [profile["id"] for profile in report["profiles"]] != profiles
            or report["seeds"] != seeds or report["requested_equipment"] != requested_equipment
            or report["carry_patients"] != args.carry_patients or report["retreat_chapters"] != retreats):
        raise SystemExit(f"FAIL: incomplete comparison record at {output}")
    print(f"Recorded {len(actual)} campaigns in {output}")


if __name__ == "__main__":
    main()
