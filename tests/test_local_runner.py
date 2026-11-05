"""Use disposable child processes to verify failure capture and deadlines."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("test_process", ROOT / "scripts/test_process.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class LocalRunner(unittest.TestCase):
    def run_child(self, source, timeout=3):
        return runner.run_engine([sys.executable, "-c", source], cwd=ROOT, timeout=timeout)

    def test_success_and_unicode(self):
        result = self.run_child("print('PASS: résultat')")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "PASS: résultat\n")

    def test_script_failure_stops_a_live_process(self):
        started = time.monotonic()
        result = self.run_child("import time; print('SCRIPT ERROR: Assertion failed', flush=True); print('at: fixture.gd:12', flush=True); time.sleep(10)")
        self.assertLess(time.monotonic() - started, 3)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SCRIPT ERROR: Assertion failed", result.stdout)
        self.assertIn("at: fixture.gd:12", result.stdout)

    def test_silent_hang_keeps_its_deadline_and_output(self):
        started = time.monotonic()
        with self.assertRaises(subprocess.TimeoutExpired) as error:
            self.run_child("import time; print('before wait', flush=True); time.sleep(10)", timeout=.2)
        self.assertLess(time.monotonic() - started, 3)
        self.assertIn("before wait", error.exception.stdout)

    def test_polling_does_not_duplicate_output(self):
        result = self.run_child("import time; print('starting', flush=True); time.sleep(.6); print('PASS: done')")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "starting\nPASS: done\n")


if __name__ == "__main__":
    unittest.main()
