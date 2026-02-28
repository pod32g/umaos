#!/usr/bin/env bash
set -euo pipefail

required=(mkarchiso rsync pacman grub-mkstandalone)
missing=()

for cmd in "${required[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done

if [[ "${UMAOS_ALLOW_AUR:-0}" == "1" ]]; then
  aur_required=(git makepkg repo-add)
  for cmd in "${aur_required[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ "$EUID" -eq 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    missing+=("sudo")
  fi
fi

if ((${#missing[@]} > 0)); then
  echo "Missing required tools: ${missing[*]}" >&2
  echo "Install base tools with: sudo pacman -S --needed archiso rsync pacman grub" >&2
  if [[ "${UMAOS_ALLOW_AUR:-0}" == "1" ]]; then
    echo "AUR fallback also needs: sudo pacman -S --needed git base-devel pacman-contrib sudo" >&2
  fi
  exit 1
fi

echo "Prerequisites OK"
echo "Umazing!"
