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

# Set UmaOS as default Plymouth theme if Plymouth is installed.
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  if [[ -f /usr/share/plymouth/themes/umaos/umaos.plymouth ]]; then
    plymouth-set-default-theme umaos
    echo "[customize_airootfs] Plymouth default theme set to umaos."
  fi
fi

# Force Qt6 to load Breeze QML components from the filesystem instead of the
# compiled-in resources in libcomponents.so.  Without this, the patched
# UserDelegate.qml (circular lock screen avatar) is ignored.
breeze_qmldir="/usr/lib/qt6/qml/org/kde/breeze/components/qmldir"
if [[ -f "$breeze_qmldir" ]] && grep -q '^prefer ' "$breeze_qmldir"; then
  sed -i '/^prefer /d' "$breeze_qmldir"
  echo "[customize_airootfs] Patched breeze components qmldir (removed 'prefer' directive)."
fi
