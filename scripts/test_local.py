#!/usr/bin/env python3
"""Run Godot suites with a deadline; script assertions can leave SceneTree alive."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
ENGINE = os.environ.get("GODOT_BIN", "godot")
SUITES = sys.argv[1:] or ["rules", "movement", "action_range", "terrain", "ground_cover", "architecture", "atmosphere", "controls", "map_camera", "action_camera", "chapter_card", "phases", "visuals", "recruit_visuals", "enemy_visuals", "commanders", "models", "character_head", "face_blink", "cutins", "combat_camera", "combat_playback", "combat_motion", "slash_contact", "combat_text", "combat_trail", "locomotion", "infantry_stride", "mounted_reins", "cape_motion", "hair_motion", "gaze_motion", "combat_hud", "forecast", "combat_exchange", "combat_finish", "spell_charge", "spell_burst", "spellbook", "healing", "rig_batching", "batching", "equipment", "equipment_visuals", "enemy_loadouts", "combat_stats", "promotions", "costumes", "preview_camera", "supports", "progress", "transfer", "saves", "tactics", "campaign", "campaign_route", "presentation", "story", "audio", "ui_audio", "travel_audio", "preferences", "menus", "company", "title_backdrop", "dialogue_backdrop"]
logs = ROOT / "build/logs"
logs.mkdir(parents=True, exist_ok=True)
for name in SUITES:
    script = ROOT / f"tests/test_{name}.gd"
    if not script.is_file():
        raise SystemExit(f"Unknown suite: {name}")
    project_path = Path(tempfile.gettempdir()) if name == "export" else ROOT
    command = [ENGINE, "--headless", "--log-file", str(logs / f"{name}.log"),
               "--path", str(project_path), "--script", str(script)]
    if name == "export":
        command.extend(["--main-pack", str(ROOT / "build/web/index.pck")])
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=90)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        (logs / f"{name}-output.log").write_text(output)
        print(output)
        raise SystemExit(f"FAIL: {name} exceeded 90 seconds (possible script assertion)")
    (logs / f"{name}-output.log").write_text(result.stdout)
    print(result.stdout, end="", flush=True)
    engine_errors = [line for line in result.stdout.splitlines()
                     if line.startswith("ERROR:") and 'Condition "ret != noErr"' not in line]
    if result.returncode or engine_errors or "SCRIPT ERROR:" in result.stdout or "PASS" not in result.stdout:
        raise SystemExit(f"FAIL: {name} did not finish successfully")
print(f"PASS: {len(SUITES)} suites completed")
