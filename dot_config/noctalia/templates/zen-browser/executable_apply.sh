#!/usr/bin/env bash
set -euo pipefail

# Legacy Noctalia Zen CSS hook. Pywalfox now owns browser theme updates so
# normal theme changes never rewrite profile CSS or restart Zen.
printf '%s\n' 'Zen CSS apply hook is disabled; Pywalfox handles Noctalia theme updates.' >&2
