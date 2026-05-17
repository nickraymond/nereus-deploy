# run: python watch_agent_logs.py --host "nereus-sys-0000" 

from __future__ import annotations

import argparse
import itertools
import shlex
import subprocess
import sys
import threading
import time
from datetime import datetime

TAILSCALE_EXE = r"C:\Program Files\Tailscale\tailscale.exe"


def stamp() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def print_status(message: str) -> None:
    print(f"[{stamp()}] {message}", flush=True)


def build_tailscale_ssh_command(host: str, user: str, log_path: str, lines: int) -> list[str]:
    remote_cmd = f'echo "===== CONNECTED TO $(hostname) =====" && tail -n {int(lines)} -F {shlex.quote(log_path)}'
    return [TAILSCALE_EXE, "ssh", f"{user}@{host}", remote_cmd]


def spinner(stop_event: threading.Event, prefix: str = "waiting for next connection") -> None:
    frames = itertools.cycle("|/-\\")
    while not stop_event.is_set():
        frame = next(frames)
        sys.stdout.write(f"\r[{stamp()}] {prefix} {frame}")
        sys.stdout.flush()
        if stop_event.wait(0.2):
            break
    sys.stdout.write("\r" + " " * 100 + "\r")
    sys.stdout.flush()


def watch_logs(host: str, user: str, log_path: str, retry_delay_sec: int, lines: int) -> int:
    print_status(f"starting watcher for {user}@{host}, log_path={log_path}")
    while True:
        cmd = build_tailscale_ssh_command(host, user, log_path, lines)
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        except KeyboardInterrupt:
            print()
            print_status("stopped by user")
            return 0
        except FileNotFoundError:
            print_status("tailscale command not found on this PC.")
            return 1
        except Exception as exc:
            print_status(f"failed to launch tailscale ssh: {exc}")
            return 1
        stop_spinner = threading.Event()
        spinner_thread = threading.Thread(target=spinner, args=(stop_spinner,), daemon=True)
        spinner_thread.start()
        connected = False
        try:
            assert proc.stdout is not None
            for line in proc.stdout:
                clean = line.rstrip("\n")
                if clean:
                    if not connected:
                        stop_spinner.set()
                        spinner_thread.join(timeout=1)
                        print()
                        print_status(f"connected to {user}@{host}")
                        connected = True
                    print(clean, flush=True)
            exit_code = proc.wait()
        except KeyboardInterrupt:
            proc.terminate()
            stop_spinner.set()
            spinner_thread.join(timeout=1)
            print()
            print_status("stopped by user")
            return 0
        finally:
            stop_spinner.set()
            spinner_thread.join(timeout=1)
        if connected:
            print()
            print_status(f"connection ended (exit code {exit_code})")
        time.sleep(retry_delay_sec)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Continuously reconnect to a Pi over Tailscale SSH and stream agent logs.")
    parser.add_argument("--host", default="nereus-sys-0000")
    parser.add_argument("--user", default="pi")
    parser.add_argument("--log-path", default="/var/log/nereus/agent.log")
    parser.add_argument("--retry-delay-sec", type=int, default=5)
    parser.add_argument("--lines", type=int, default=50)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    return watch_logs(args.host, args.user, args.log_path, args.retry_delay_sec, args.lines)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
