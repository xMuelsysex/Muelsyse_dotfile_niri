#!/usr/bin/env bash
set -euo pipefail

# Legacy watcher retained as a safe, explicit no-op. Pywalfox updates the Zen
# theme through Firefox native messaging without profile CSS or browser restarts.
printf '%s\n' 'Zen CSS watcher is disabled; Pywalfox handles Noctalia theme updates.' >&2
