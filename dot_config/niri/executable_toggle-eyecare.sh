#!/usr/bin/env bash
# EyeCare：色温 (wlsunset) + niri 关 blur / 不透明
# 状态文件 + wlsunset 进程双校验；先让 Noctalia 释放 gamma 再接管。
set -euo pipefail

NIRI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia"
STATE_FILE="$STATE_DIR/eyecare.on"
LOG="$STATE_DIR/eyecare.log"
EFFECTS_LINK="$NIRI_DIR/effects.kdl"
NORMAL_EFFECTS="$NIRI_DIR/effects_normal.kdl"
EYECARE_EFFECTS="$NIRI_DIR/effects_eyecare.kdl"
EYECARE_TEMP="${EYECARE_TEMP:-4800}"
WLSUNSET_LOG="/tmp/wlsunset-eyecare.log"

mkdir -p "$STATE_DIR"
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG"; }

notify() {
  local title="$1" body="$2"
  command -v noctalia >/dev/null 2>&1 || return 0
  noctalia msg notification-show "$title" -- "$body" >/dev/null 2>&1 || true
}

release_gamma() {
  # Noctalia 若占着 wlr-gamma-control，wlsunset 会失败
  if command -v noctalia >/dev/null 2>&1; then
    noctalia msg nightlight-disable >/dev/null 2>&1 || true
    # force 若开着，再 toggle 一次关掉（无 status 命令，失败也无妨）
    noctalia msg nightlight-force-toggle >/dev/null 2>&1 || true
    noctalia msg nightlight-disable >/dev/null 2>&1 || true
  fi
  pkill -x wlsunset >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x wlsunset >/dev/null 2>&1 || break
    sleep 0.05
  done
  sleep 0.15
}

apply_effects() {
  if [ "$1" = "on" ]; then
    ln -sfn "$EYECARE_EFFECTS" "$EFFECTS_LINK"
  else
    ln -sfn "$NORMAL_EFFECTS" "$EFFECTS_LINK"
  fi
  if command -v niri >/dev/null 2>&1; then
    niri msg action load-config-file >/dev/null 2>&1 || true
  fi
}

is_on() {
  if [ -f "$STATE_FILE" ]; then
    return 0
  fi
  pgrep -x wlsunset >/dev/null 2>&1
}

start_wlsunset() {
  # high(-T) 必须 > low(-t)；全天夜间轨迹 → 落在 low=EYECARE_TEMP
  : >"$WLSUNSET_LOG"
  nohup wlsunset -T 6500 -t "$EYECARE_TEMP" -d 1 -S 00:00 -s 00:00 \
    >>"$WLSUNSET_LOG" 2>&1 &
  disown || true
  sleep 0.2
  if ! pgrep -x wlsunset >/dev/null 2>&1; then
    log "wlsunset failed to start: $(tr '\n' ' ' <"$WLSUNSET_LOG")"
    return 1
  fi
  if rg -q 'gamma control .* failed' "$WLSUNSET_LOG" 2>/dev/null; then
    log "wlsunset gamma failed: $(tr '\n' ' ' <"$WLSUNSET_LOG")"
    return 1
  fi
  return 0
}

# --sync：登录时对齐 effects，不切换
if [ "${1:-}" = "--sync" ]; then
  if is_on; then
    apply_effects on
    if ! pgrep -x wlsunset >/dev/null 2>&1; then
      release_gamma
      start_wlsunset || true
    fi
    touch "$STATE_FILE"
    log "sync: on"
  else
    apply_effects off
    rm -f "$STATE_FILE"
    log "sync: off"
  fi
  exit 0
fi

if is_on; then
  release_gamma
  apply_effects off
  rm -f "$STATE_FILE"
  notify "护眼模式" "已关闭"
  log "toggle -> off"
  exit 0
fi

release_gamma
apply_effects on
if start_wlsunset; then
  touch "$STATE_FILE"
  notify "护眼模式" "已开启（${EYECARE_TEMP}K + 关模糊）"
  log "toggle -> on temp=$EYECARE_TEMP"
else
  # 色温失败仍保留关模糊；提示 gamma 问题
  touch "$STATE_FILE"
  notify "护眼模式" "模糊已关；色温失败（gamma 被占用？见 $WLSUNSET_LOG）"
  log "toggle -> partial (effects on, wlsunset fail)"
  exit 1
fi
