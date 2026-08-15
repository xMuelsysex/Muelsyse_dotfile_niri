#!/usr/bin/env bash
# Keep starship powerline on palette "colors" while still accepting Noctalia Monet [palettes.noctalia].
# Noctalia apply.sh always forces palette="noctalia" (Catppuccin names only) which breaks color_* powerline.
set -euo pipefail

CFG="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"
CFG="${CFG/#\~/$HOME}"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/starship-palette-fix.log"
mkdir -p "$(dirname "$LOG")"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(ts) $*" >>"$LOG"; }

if [[ ! -f "$CFG" ]]; then
  log "ABORT: missing $CFG"
  exit 0
fi

# Need color_* powerline keys; if format doesn't reference them, leave alone.
if ! grep -qE 'color_(orange|yellow|aqua|blue|bg1|bg3|fg0)' "$CFG"; then
  log "skip: no powerline color_* refs in $CFG"
  exit 0
fi

WP=$(noctalia msg wallpaper-get 2>/dev/null || true)
SCHEME=$(python3 - <<'PY' 2>/dev/null || echo m3-content
import tomllib
from pathlib import Path
for p in [Path.home()/'.local/state/noctalia/settings.toml', Path.home()/'.config/noctalia/config.toml']:
    try:
        s=tomllib.loads(p.read_text())
        print(s.get('theme',{}).get('wallpaper_scheme') or s.get('theme',{}).get('scheme') or 'm3-content')
        break
    except Exception:
        pass
else:
    print('m3-content')
PY
)
MODE=$(noctalia msg theme-mode-get 2>/dev/null || echo dark)
case "$MODE" in
  light) MODE_FLAG=--light ;;
  *) MODE_FLAG=--dark ;;
esac

M3_JSON="${XDG_RUNTIME_DIR:-/tmp}/noctalia-m3-starship.json"
if [[ -n "${WP:-}" && -f "$WP" ]] && command -v noctalia >/dev/null; then
  if ! noctalia theme "$WP" --scheme "$SCHEME" "$MODE_FLAG" -o "$M3_JSON" >/dev/null 2>&1; then
    log "warn: noctalia theme failed wp=$WP scheme=$SCHEME"
    M3_JSON=""
  fi
else
  M3_JSON=""
fi

python3 - "$CFG" "$M3_JSON" "$LOG" <<'PY'
import re, sys, json
from pathlib import Path
from datetime import datetime

cfg_path = Path(sys.argv[1])
m3_path = Path(sys.argv[2]) if sys.argv[2] else None
log_path = Path(sys.argv[3])

def log(msg):
    with log_path.open('a') as f:
        f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}\n")

text = cfg_path.read_text()
orig = text

# Force active palette to colors (powerline)
text2, n = re.subn(
    r'(?m)^palette\s*=\s*["\'][^"\']*["\']\s*$',
    'palette = "colors"',
    text,
    count=1,
)
if n == 0:
    # insert after schema if present else at top
    if re.search(r'(?m)^"\$schema"', text):
        text2 = re.sub(r'(?m)^("\$schema".*)$', r'\1\npalette = "colors"', text, count=1)
    else:
        text2 = 'palette = "colors"\n' + text
text = text2

# Build color map from M3 JSON (matugen starship-colors.toml mapping)
defaults = {
    'mustard': '#af8700',
    'color_orange': '#c2c8c7',
    'color_fg0': '#2c3132',
    'color_fg1': '#e5e2e1',
    'color_purple': '#b0acb3',
    'color_bg3': '#c6c7c6',
    'color_green': '#2c3132',
    'color_bg1': '#454747',
    'color_blue': '#3c4242',
    'color_red': '#c2c8c7',
    'color_aqua': '#b4b5b5',
    'color_yellow': '#dee4e3',
}
colors = dict(defaults)
if m3_path and m3_path.is_file():
    try:
        d = json.loads(m3_path.read_text())
        # noctalia theme --dark emits flat map
        def hx(key, fallback):
            v = d.get(key)
            if isinstance(v, str) and v.startswith('#'):
