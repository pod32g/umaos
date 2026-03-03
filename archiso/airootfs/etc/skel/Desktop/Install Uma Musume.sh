#!/usr/bin/env bash
set -euo pipefail

APP_ID="3224770"
GAME_NAME="Umamusume: Pretty Derby"

log() {
  printf '[UmaOS Umamusume] %s\n' "$*"
}

ensure_steam_runtime() {
  log "Ensuring Steam and Proton runtime dependencies..."
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    /usr/local/bin/umao-install-steam-root
    return 0
  fi

  if command -v pkexec >/dev/null 2>&1; then
    if pkexec /usr/local/bin/umao-install-steam-root; then
      return 0
    fi
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo /usr/local/bin/umao-install-steam-root
    return 0
  fi

  log "Cannot install Steam automatically (sudo not available)."
  exit 1
}

ensure_proton_ge() {
  log "Ensuring Proton GE is installed via ProtonUp-Qt..."
  if /usr/local/bin/umao-ensure-proton-ge; then
    return 0
  fi
  log "Proton GE setup is incomplete. Run this launcher again after installing GE-Proton."
  exit 1
}

open_steam_install() {
  local url="steam://install/${APP_ID}"

  if ! command -v steam >/dev/null 2>&1; then
    log "ERROR: Steam is not installed. Cannot launch game installer."
    return 1
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    if xdg-open "$url" 2>/dev/null; then
      return 0
    fi
    log "xdg-open failed for $url; trying direct steam launch."
  fi

  steam "$url" &
}

log "Preparing ${GAME_NAME} installer..."
ensure_steam_runtime
ensure_proton_ge
if open_steam_install; then
  log "Steam install page launched for ${GAME_NAME}."
  log "Sign in to Steam and complete the installation."
  echo "Umazing!"
else
  log "ERROR: Failed to launch Steam installer for ${GAME_NAME}."
  exit 1
fi
