#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-9222}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_ROOT_DIR="${HOME}/plugins/codex-monitor"
if [[ -x "${PLUGIN_ROOT_DIR}/scripts/start_codex_monitor.sh" ]]; then
  ROOT_DIR="${PLUGIN_ROOT_DIR}"
else
  ROOT_DIR="${CURRENT_ROOT_DIR}"
fi
LABEL="com.kevinke.codex-monitor"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${HOME}/Library/Logs"
OUT_LOG="${LOG_DIR}/codex-monitor.out.log"
ERR_LOG="${LOG_DIR}/codex-monitor.err.log"
LOG_ROTATE_BYTES="${CODEX_MONITOR_LOG_ROTATE_BYTES:-1048576}"

mkdir -p "${HOME}/Library/LaunchAgents" "${LOG_DIR}"

launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true

rotate_log_if_large() {
  local path="${1:?log path required}"
  local bytes=0
  if [[ -f "${path}" ]]; then
    bytes="$(stat -f '%z' "${path}" 2>/dev/null || echo 0)"
  fi
  if (( bytes > LOG_ROTATE_BYTES )); then
    mv -f "${path}" "${path}.1"
  fi
}

rotate_log_if_large "${OUT_LOG}"
rotate_log_if_large "${ERR_LOG}"

cat > "${PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${ROOT_DIR}/scripts/start_codex_monitor.sh</string>
    <string>${PORT}</string>
    <string>--no-reopen-after-quit</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ProcessType</key>
  <string>Background</string>
  <key>ThrottleInterval</key>
  <integer>15</integer>
  <key>StandardOutPath</key>
  <string>${OUT_LOG}</string>
  <key>StandardErrorPath</key>
  <string>${ERR_LOG}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>${HOME}</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "${PLIST}"
launchctl enable "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/$(id -u)/${LABEL}"

echo "Installed and started ${LABEL}."
echo "LaunchAgent: ${PLIST}"
echo "Logs:"
echo "  ${OUT_LOG}"
echo "  ${ERR_LOG}"
