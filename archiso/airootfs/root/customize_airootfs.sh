#!/usr/bin/env bash
set -euo pipefail

echo "[customize_airootfs] Running UmaOS airootfs customization..."

# Ensure pacman.conf is world-readable so yay/pacman work for regular users.
if [[ -f /etc/pacman.conf ]]; then
  chmod 644 /etc/pacman.conf
fi

if command -v umao-sync-calamares-config >/dev/null 2>&1; then
  umao-sync-calamares-config
  echo "[customize_airootfs] Calamares config synced."
else
  echo "[customize_airootfs] WARNING: umao-sync-calamares-config not found on PATH." >&2
  echo "[customize_airootfs] Calamares config was NOT synced. Check build overlay." >&2
fi

# Fix ownership of the live-user home directory.
# archiso copies airootfs files as root; Plasma and other apps require the
# home directory to be owned by the actual user so they can read/write configs.
if id arch >/dev/null 2>&1; then
  chown -R arch:arch /home/arch
  echo "[customize_airootfs] Fixed /home/arch ownership."
fi

# Apply patched UserDelegate.qml for circular avatar on lock screen.
# This file is owned by plasma-workspace so it can't live in airootfs
# (would cause pacman file-conflict). We patch it here after pacstrap.
patch_src="/usr/share/umaos/patches/UserDelegate.qml"
patch_dst="/usr/lib/qt6/qml/org/kde/breeze/components/UserDelegate.qml"
if [[ -f "$patch_src" && -f "$patch_dst" ]]; then
  cp "$patch_src" "$patch_dst"
  echo "[customize_airootfs] Applied patched UserDelegate.qml."
  # Remove 'prefer' directive so Qt6 loads from filesystem instead of compiled resources.
  qmldir="$(dirname "$patch_dst")/qmldir"
  if [[ -f "$qmldir" ]] && grep -q '^prefer ' "$qmldir"; then
    sed -i '/^prefer /d' "$qmldir"
    echo "[customize_airootfs] Patched qmldir (removed 'prefer' directive)."
  fi
fi

# Set UmaOS as default Plymouth theme if Plymouth is installed.
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  if [[ -f /usr/share/plymouth/themes/umaos/umaos.plymouth ]]; then
    plymouth-set-default-theme umaos
    echo "[customize_airootfs] Plymouth default theme set to umaos."
  fi
fi
