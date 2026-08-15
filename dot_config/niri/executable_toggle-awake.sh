#!/usr/bin/env bash
# KeepAwake：noctalia caffeine（保持唤醒）持久化封装
# 状态文件记录上次选择；重启后由 config.kdl 的 spawn-at-startup --sync 恢复。
# 注意：noctalia 的 caffeine 是纯运行时状态（官方不持久化），此脚本是唯一
# 持久化入口；直接用 caffeine-enable/disable 或面板 widget 切换不会更新状态文件。
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia"
STATE_FILE="$STATE_DIR/caffeine.on"
LOG="$STATE_DIR/caffeine.log"

mkdir -p "$STATE_DIR"
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG"; }

notify() {
  local title="$1" body="$2"
  command -v noctalia >/dev/null 2>&1 || return 0
  noctalia msg notification-show "$title" -- "$body" >/dev/null 2>&1 || true
}

# 显式 enable/disable（而非 caffeine-toggle）：状态文件与真实状态始终一致
set_state() {
  if [ "$1" = "on" ]; then
    noctalia msg caffeine-enable >/dev/null
    touch "$STATE_FILE"
  else
    noctalia msg caffeine-disable >/dev/null
    rm -f "$STATE_FILE"
  fi
}

is_on() { [ -f "$STATE_FILE" ]; }

# logind 探测：logind 层面是否存在 caffeine 抑制锁（覆盖 widget/直接命令入口）
logind_caffeine_on() {
  busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager ListInhibitors \
    2>/dev/null | grep -q '"Caffeine"'
}

# --sync：开机无条件开启保持唤醒（等待 noctalia 就绪，最多 ~30s）
# 不再依赖状态文件记忆——按主人要求，开机默认保持唤醒开
if [ "${1:-}" = "--sync" ]; then
  for _ in $(seq 1 15); do
    noctalia msg caffeine-enable >/dev/null 2>&1 && logind_caffeine_on && break
    sleep 2
  done
  if logind_caffeine_on; then
    touch "$STATE_FILE"
    log "sync: on (boot default)"
  else
    log "sync: FAILED (noctalia not ready or enable failed)"
  fi
  exit 0
fi

if is_on; then
  set_state off
  notify "保持唤醒" "已关闭"
  log "toggle -> off"
else
  set_state on
  notify "保持唤醒" "已开启"
  log "toggle -> on"
fi
