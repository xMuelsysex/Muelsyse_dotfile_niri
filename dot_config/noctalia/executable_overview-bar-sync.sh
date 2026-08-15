#!/usr/bin/env bash
# Hide Noctalia bar and dock when Niri overview opens; restore when overview closes.
set -uo pipefail

readonly BAR_NAME="${NYXNIRI_NOCTALIA_BAR_NAME:-bar}"
readonly RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
readonly LOCK_FILE="$RUNTIME_DIR/nyxniri-overview-bar-sync.lock"
readonly NIRI_SOCKET_PATH="${NIRI_SOCKET:-}"

stream_pid=""
event_fd=""

log_error() {
    printf '[overview-bar-sync] %s\n' "$*" >&2
}

wait_for_noctalia() {
    while [[ -S "$NIRI_SOCKET_PATH" ]]; do
        if noctalia msg status >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.25
    done
    return 1
}

set_bar_for_overview() {
    local overview_open="$1"
    local bar_cmd="bar-show"
    local dock_cmd="dock-show-transient"

    if [[ "$overview_open" == "true" ]]; then
        bar_cmd="bar-hide"
        dock_cmd="dock-hide-transient"
    fi

    local error_output
    if ! error_output=$(noctalia msg "$bar_cmd" "$BAR_NAME" 2>&1); then
        log_error "$bar_cmd failed: $error_output"
        return 1
    fi
    if ! error_output=$(noctalia msg "$dock_cmd" 2>&1); then
        log_error "$dock_cmd failed: $error_output"
        return 1
    fi
}

restore_bar() {
    noctalia msg bar-show "$BAR_NAME" >/dev/null 2>&1 || true
    noctalia msg dock-show-transient >/dev/null 2>&1 || true
}

cleanup() {
    if [[ -n "$event_fd" ]]; then
        exec {event_fd}<&- 2>/dev/null || true
    fi
    if [[ -n "$stream_pid" ]]; then
        kill "$stream_pid" 2>/dev/null || true
        wait "$stream_pid" 2>/dev/null || true
    fi
    restore_bar
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exit 0
fi

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -z "$NIRI_SOCKET_PATH" || ! -S "$NIRI_SOCKET_PATH" ]]; then
    log_error 'NIRI_SOCKET does not point to a live socket'
    exit 1
fi

if ! wait_for_noctalia; then
    exit 0
fi

while [[ -S "$NIRI_SOCKET_PATH" ]]; do
    exec {event_fd}< <(
        exec 9>&-
        exec niri msg --json event-stream
    )
    stream_pid=$!

    while IFS= read -r event <&"$event_fd"; do
        if [[ "$event" != *'"OverviewOpenedOrClosed"'* ]]; then
            continue
        fi

        if ! overview_open=$(jq -er '
            .OverviewOpenedOrClosed.is_open as $state
            | if ($state | type) == "boolean"
              then ($state | tostring)
              else error("invalid overview state")
              end
        ' <<<"$event" 2>/dev/null); then
            log_error "invalid overview event: $event"
            continue
        fi

        if ! set_bar_for_overview "$overview_open" && wait_for_noctalia; then
            set_bar_for_overview "$overview_open" || true
        fi
    done

    exec {event_fd}<&-
    event_fd=""
    wait "$stream_pid"
    stream_status=$?
    stream_pid=""

    if [[ ! -S "$NIRI_SOCKET_PATH" ]]; then
        break
    fi

    log_error "event stream stopped with status $stream_status; retrying"
    sleep 0.5
done
