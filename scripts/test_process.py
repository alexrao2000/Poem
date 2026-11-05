"""Capture engine output while stopping script failures that leave Godot alive."""
import subprocess
import time


def run_engine(command, *, cwd, timeout=90):
    deadline = time.monotonic() + timeout
    with subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, encoding="utf-8",
                          errors="replace") as process:
        try:
            while True:
                try:
                    output, _ = process.communicate(timeout=min(.25, max(0, deadline - time.monotonic())))
                    return subprocess.CompletedProcess(command, process.returncode, output)
                except subprocess.TimeoutExpired as error:
                    partial = error.output or b""
                    if isinstance(partial, bytes):
                        partial = partial.decode("utf-8", errors="replace")
                    if "SCRIPT ERROR:" in partial:
                        process.terminate()
                        try:
                            output, _ = process.communicate(timeout=2)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            output, _ = process.communicate()
                        return subprocess.CompletedProcess(command, process.returncode, output)
                    if time.monotonic() >= deadline:
                        process.kill()
                        output, _ = process.communicate()
                        raise subprocess.TimeoutExpired(command, timeout, output=output)
        except BaseException:
            if process.poll() is None:
                process.kill()
            process.communicate()
            raise
