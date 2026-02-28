#!/usr/bin/env bash
set -euo pipefail

APP_ID="3224770"
GAME_NAME="Umamusume: Pretty Derby"

log() {
  printf '[UmaOS Umamusume] %s\n' "$*"
}

install_steam_if_missing() {
  if command -v steam >/dev/null 2>&1; then
    return 0
  fi

  log "Steam is not installed. Installing Steam first..."
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

open_steam_install() {
  local url="steam://install/${APP_ID}"

  if command -v xdg-open >/dev/null 2>&1; then
    if xdg-open "$url" >/dev/null 2>&1; then
      return 0
    fi
  fi

  steam "$url" >/dev/null 2>&1 &
}

log "Preparing ${GAME_NAME} installer..."
install_steam_if_missing
open_steam_install
log "Steam install page launched for ${GAME_NAME}."
log "Sign in to Steam and complete the installation."
echo "Umazing!"
