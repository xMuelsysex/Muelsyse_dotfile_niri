#!/usr/bin/env bash
# Shorin/DMS 同款 Overview 壁纸模糊：
#   1. 取 Noctalia 当前壁纸
#   2. ImageMagick 预模糊写入 cache
#   3. 用 Gtk layer-shell 挂 namespace=dms:blurwallpaper
# niri layer-rule place-within-backdrop 只在 Super+O overview 里显示这层。
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/blur-wallpapers/overview"
CACHE_IMG="$CACHE_DIR/current.png"
SRC_MARKER="$CACHE_DIR/source.path"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/overview-blur-wallpaper.pid"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia"
LOG="$LOG_DIR/overview-blur.log"
CLIENT="${XDG_CONFIG_HOME:-$HOME/.config}/niri/scripts/overview-blur-wallpaper.py"

# Shorin legacy niri_auto_blur_bg.sh 默认 0x17
BLUR_ARG="${OVERVIEW_BLUR_ARG:-0x17}"
# 先缩小再模糊，大图更快且观感接近 DMS
DOWNSCALE="${OVERVIEW_BLUR_DOWNSCALE:-50%}"

mkdir -p "$CACHE_DIR" "$LOG_DIR"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG"; }

notify_fail() {
  command -v noctalia >/dev/null 2>&1 || return 0
  noctalia msg notification-show "Overview 模糊" -- "$1" >/dev/null 2>&1 || true
}

resolve_source() {
  local wp=""
  if [[ -n "${1:-}" && -e "$1" ]]; then
    wp="$1"
  elif command -v noctalia >/dev/null 2>&1; then
    wp=$(noctalia msg wallpaper-get 2>/dev/null || true)
  fi
  # strip quotes / trailing cr / surrounding whitespace
  wp=${wp//$'\r'/}
  wp=${wp//\"/}
  wp=$(printf '%s' "$wp" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  printf '%s' "$wp"
}

is_video() {
  case "${1,,}" in
    *.mp4|*.webm|*.mkv|*.mov|*.avi|*.gif) return 0 ;;
    *) return 1 ;;
  esac
}

extract_still() {
  local src="$1" dest="$2"
  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -loglevel error -i "$src" -ss 00:00:01 -frames:v 1 "$dest" 2>/dev/null
    return $?
  fi
  return 1
}

build_blur() {
  local src="$1"
  local work="$CACHE_DIR/.src-still.png"
  local tmp="$CACHE_DIR/.current.png.tmp"

  if is_video "$src"; then
    if ! extract_still "$src" "$work"; then
      log "ffmpeg still extract failed: $src"
      return 1
    fi
    src="$work"
  fi

  if [[ ! -f "$src" ]]; then
    log "source missing: $src"
    return 1
  fi

  if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
    log "ImageMagick not found"
    return 1
  fi

  local im=magick
  command -v magick >/dev/null 2>&1 || im=convert

  # cover-friendly intermediate; client does final cover-crop to output
  if ! "$im" "$src" -auto-orient -scale "$DOWNSCALE" -blur "$BLUR_ARG" "PNG:$tmp"; then
    log "magick blur failed src=$src"
    return 1
  fi
  mv -f "$tmp" "$CACHE_IMG"
  printf '%s\n' "$1" >"$SRC_MARKER"
  log "blur ok blur=$BLUR_ARG scale=$DOWNSCALE src=$1 -> $CACHE_IMG"
  return 0
}

stop_client() {
  if [[ -f "$PID_FILE" ]]; then
    local old
    old=$(cat "$PID_FILE" 2>/dev/null || true)
    if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
      kill "$old" 2>/dev/null || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        kill -0 "$old" 2>/dev/null || break
        sleep 0.05
      done
      kill -9 "$old" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  # 兜底：按脚本路径杀残留
  pkill -f "$CLIENT" >/dev/null 2>&1 || true
}

start_client() {
  if [[ ! -f "$CACHE_IMG" ]]; then
    log "no cache image, skip start"
    return 1
  fi
  if [[ ! -x "$CLIENT" && -f "$CLIENT" ]]; then
    chmod +x "$CLIENT" || true
  fi
  if [[ ! -f "$CLIENT" ]]; then
    log "client missing: $CLIENT"
    return 1
  fi

  # 继承当前 session 的 WAYLAND_DISPLAY
  nohup python3 "$CLIENT" "$CACHE_IMG" >>"$LOG" 2>&1 &
  local pid=$!
  echo "$pid" >"$PID_FILE"
  disown "$pid" 2>/dev/null || true
  sleep 0.15
  if ! kill -0 "$pid" 2>/dev/null; then
    log "client exited immediately; see log"
    rm -f "$PID_FILE"
    return 1
  fi
  log "client started pid=$pid"
  return 0
}

need_rebuild() {
  local src="$1"
  [[ ! -f "$CACHE_IMG" ]] && return 0
  [[ ! -f "$SRC_MARKER" ]] && return 0
  local prev
  prev=$(cat "$SRC_MARKER" 2>/dev/null || true)
  [[ "$prev" != "$src" ]] && return 0
  # source newer than cache
  [[ "$src" -nt "$CACHE_IMG" ]] && return 0
  return 1
}

main() {
  local mode="${1:-sync}"
  case "$mode" in
    stop)
      stop_client
      log "stopped"
      exit 0
      ;;
    restart-client)
      stop_client
      start_client || exit 1
      exit 0
      ;;
    sync|*)
      ;;
  esac

  local src
  src=$(resolve_source "${2:-}")
  if [[ -z "$src" ]]; then
    log "no wallpaper source"
    # 已有 cache 也尽量挂上
    if [[ -f "$CACHE_IMG" ]]; then
      stop_client
      start_client || true
    fi
    exit 0
  fi

  if need_rebuild "$src"; then
    if ! build_blur "$src"; then
      notify_fail "预模糊失败：$src"
      # 仍尝试旧 cache
      if [[ ! -f "$CACHE_IMG" ]]; then
        exit 1
      fi
    fi
  else
    log "cache fresh src=$src"
  fi

  stop_client
  if start_client; then
    exit 0
  fi
  notify_fail "模糊层启动失败（见 $LOG）"
  exit 1
}

main "$@"
