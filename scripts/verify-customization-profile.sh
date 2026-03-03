#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-}"
PKG_FILE="${2:-}"
EXPECTED_WALLHAVEN_COUNT="${3:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "Usage: $0 <airootfs-root> [packages-file]" >&2
  exit 2
fi

pass_count=0
fail_count=0
warn_count=0

pass() {
  printf '[umaos-customize-verify] PASS: %s\n' "$*"
  pass_count=$((pass_count + 1))
}

fail() {
  printf '[umaos-customize-verify] FAIL: %s\n' "$*" >&2
  fail_count=$((fail_count + 1))
}

warn() {
  printf '[umaos-customize-verify] WARN: %s\n' "$*" >&2
  warn_count=$((warn_count + 1))
}

require_file() {
  local path="$1"
  if [[ -f "$ROOT$path" ]]; then
    pass "Found $path"
  else
    fail "Missing file $path"
  fi
}

require_executable() {
  local path="$1"
  if [[ -x "$ROOT$path" ]]; then
    pass "Executable present: $path"
  else
    fail "Missing executable bit or file: $path"
  fi
}

check_desktop_exec_target() {
  local desktop_path="$1"
  local exec_line
  local exec_cmd

  if [[ ! -f "$ROOT$desktop_path" ]]; then
    fail "Missing desktop file $desktop_path"
    return
  fi

  exec_line="$(awk -F= '/^Exec=/{print $2; exit}' "$ROOT$desktop_path" | tr -d '\r')"
  if [[ -z "$exec_line" ]]; then
    fail "No Exec line in $desktop_path"
    return
  fi

  exec_cmd="${exec_line%% *}"
  if [[ "$exec_cmd" == /* ]]; then
    if [[ -x "$ROOT$exec_cmd" ]]; then
      pass "$desktop_path Exec target exists: $exec_cmd"
    else
      fail "$desktop_path Exec target missing or not executable: $exec_cmd"
    fi
  else
    pass "$desktop_path Exec uses PATH command: $exec_cmd"
  fi
}

check_executable_file() {
  local path="$1"
  if [[ -f "$ROOT$path" && -x "$ROOT$path" ]]; then
    pass "Executable file present: $path"
  elif [[ -f "$ROOT$path" ]]; then
    warn "File exists but is not executable: $path"
  else
    fail "Missing file: $path"
  fi
}

require_file "/etc/sddm.conf.d/umaos-theme.conf"
sddm_theme="$(awk -F= '/^Current=/{print $2; exit}' "$ROOT/etc/sddm.conf.d/umaos-theme.conf" 2>/dev/null | tr -d '\r' || true)"
if [[ -z "$sddm_theme" ]]; then
  fail "Could not parse SDDM theme from /etc/sddm.conf.d/umaos-theme.conf"
else
  if [[ -f "$ROOT/usr/share/sddm/themes/$sddm_theme/Main.qml" ]]; then
    pass "SDDM theme '$sddm_theme' has Main.qml"
  else
    fail "SDDM theme '$sddm_theme' missing Main.qml"
  fi
fi

configured_cursor="$(awk -F= '/^CursorTheme=/{print $2; exit}' "$ROOT/etc/sddm.conf.d/umaos-theme.conf" 2>/dev/null | tr -d '\r' || true)"
if [[ -n "$configured_cursor" ]]; then
  if [[ -d "$ROOT/usr/share/icons/$configured_cursor" ]]; then
    pass "Configured cursor theme exists: $configured_cursor"
  else
    warn "Configured cursor theme not present in profile tree: $configured_cursor"
  fi
fi

require_file "/usr/share/icons/hicolor/scalable/apps/umaos-launcher.svg"
require_file "/usr/share/wallpapers/UmaOS/contents/images/1920x1080.jpg"
require_file "/usr/share/wallpapers/UmaOS/contents/videos/qloo.mp4"
require_file "/usr/share/wallpapers/UmaOS/metadata.json"
require_file "/usr/share/wallpapers/UmaBoot/metadata.json"
require_file "/usr/share/umaos/themes/konsole/goldship.webp"
require_file "/usr/share/konsole/UmaOS-GoldShip.colorscheme"
require_file "/usr/share/konsole/UmaOS.profile"
require_file "/etc/xdg/konsolerc"
require_file "/etc/skel/.config/konsolerc"
require_file "/home/arch/.config/konsolerc"
require_file "/usr/local/bin/umao-apply-theme"
require_file "/usr/local/bin/umao-finalize-installed-customization"
require_file "/usr/share/umaos/neofetch.txt"
require_file "/etc/skel/.config/ksplashrc"
require_file "/etc/skel/.config/mimeapps.list"
require_file "/home/arch/.config/mimeapps.list"
require_file "/etc/calamares/modules/users.conf"
require_file "/etc/calamares/umaos-defaults/modules/users.conf"

ksplash_theme="$(awk -F= '/^Theme=/{print $2; exit}' "$ROOT/etc/skel/.config/ksplashrc" 2>/dev/null | tr -d '\r' || true)"
if [[ -n "$ksplash_theme" ]]; then
  if [[ -d "$ROOT/usr/share/plasma/look-and-feel/$ksplash_theme" ]]; then
    pass "KSplash theme directory exists: $ksplash_theme"
  elif [[ -f "$REPO_ROOT/scripts/build-iso.sh" ]] && grep -q 'install_uma_ksplash_theme' "$REPO_ROOT/scripts/build-iso.sh"; then
    warn "KSplash theme '$ksplash_theme' not present in source root; it is generated during build-iso.sh"
  else
    fail "KSplash theme '$ksplash_theme' referenced but missing from /usr/share/plasma/look-and-feel"
  fi
else
  fail "Could not parse KSplash theme from /etc/skel/.config/ksplashrc"
fi

if grep -Eq '^sudoersConfigureWithGroup:[[:space:]]*true$' "$ROOT/etc/calamares/modules/users.conf"; then
  pass "Calamares users module config enables wheel sudoers policy"
else
  fail "Calamares users module has sudoersConfigureWithGroup disabled"
fi

if grep -Eq '^sudoersConfigureWithGroup:[[:space:]]*true$' "$ROOT/etc/calamares/umaos-defaults/modules/users.conf"; then
  pass "Calamares synced defaults keep wheel sudoers policy enabled"
else
  fail "Calamares synced defaults have sudoersConfigureWithGroup disabled"
fi

if grep -Eq '^DefaultProfile=UmaOS\.profile$' "$ROOT/etc/xdg/konsolerc" \
  && grep -Eq '^DefaultProfile=UmaOS\.profile$' "$ROOT/etc/skel/.config/konsolerc" \
  && grep -Eq '^DefaultProfile=UmaOS\.profile$' "$ROOT/home/arch/.config/konsolerc"; then
  pass "Konsole default profile is set to UmaOS.profile for system/skel/live user"
else
  fail "Konsole default profile is not consistently set to UmaOS.profile"
fi

if [[ -f "$ROOT/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js" ]] \
  && grep -q 'umaos-launcher' "$ROOT/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js"; then
  pass "Shell layout.js exists and sets Kickoff icon to umaos-launcher"
else
  fail "Shell layout.js missing or does not set umaos-launcher icon"
fi

require_executable "/usr/local/bin/umao-install"
require_executable "/usr/local/bin/umao-installer-autostart"
require_executable "/usr/local/bin/umao-first-login-umamusume"
require_executable "/usr/local/bin/umao-install-steam-root"
require_executable "/usr/local/bin/umao-ensure-proton-ge"
require_executable "/usr/local/bin/neofetch"

if grep -q '/usr/share/umaos/neofetch.txt' "$ROOT/usr/local/bin/neofetch" \
  && grep -q -- '--source' "$ROOT/usr/local/bin/neofetch"; then
  pass "neofetch wrapper defaults to UmaOS neofetch.txt ASCII source"
else
  fail "neofetch wrapper does not set UmaOS neofetch.txt as default source"
fi

if grep -q 'chmod 0644 "\$conf"' "$ROOT/usr/local/bin/umao-install-steam-root"; then
  pass "Steam root helper restores pacman.conf world-readable permissions"
else
  fail "Steam root helper does not restore pacman.conf permissions; yay may fail for non-root users"
fi

if grep -q 'PROTONUP_QT_APP_ID="net.davidotek.pupgui2"' "$ROOT/usr/local/bin/umao-install-steam-root" \
  && grep -q 'flatpak install --system -y' "$ROOT/usr/local/bin/umao-install-steam-root"; then
  pass "Steam root helper installs ProtonUp-Qt from Flathub"
else
  fail "Steam root helper is missing ProtonUp-Qt Flathub installation logic"
fi

if grep -q 'GE-Proton' "$ROOT/usr/local/bin/umao-ensure-proton-ge" \
  && grep -q 'flatpak run "\$PROTONUP_QT_APP_ID"' "$ROOT/usr/local/bin/umao-ensure-proton-ge"; then
  pass "Proton GE helper launches ProtonUp-Qt and validates GE-Proton presence"
else
  fail "Proton GE helper is missing ProtonUp-Qt launch or GE-Proton detection logic"
fi

if grep -q 'lib32-vulkan-icd-loader' "$ROOT/usr/local/bin/umao-install-steam-root" \
  && grep -q 'lib32-mesa' "$ROOT/usr/local/bin/umao-install-steam-root" \
  && grep -q 'lib32-libxrandr' "$ROOT/usr/local/bin/umao-install-steam-root" \
  && grep -q 'lib32-libxinerama' "$ROOT/usr/local/bin/umao-install-steam-root" \
  && grep -q 'lib32-libxcursor' "$ROOT/usr/local/bin/umao-install-steam-root" \
  && grep -q 'lib32-openal' "$ROOT/usr/local/bin/umao-install-steam-root" \
  && grep -q 'lib32-alsa-plugins' "$ROOT/usr/local/bin/umao-install-steam-root" \
  && grep -q 'lib32-gnutls' "$ROOT/usr/local/bin/umao-install-steam-root"; then
  pass "Steam root helper includes extended 32-bit Proton runtime dependencies"
else
  fail "Steam root helper is missing extended 32-bit Proton runtime dependency install logic"
fi

check_desktop_exec_target "/etc/skel/.config/autostart/umaos-first-login.desktop"
check_desktop_exec_target "/etc/skel/.config/autostart/umao-umamusume-first-login.desktop"
check_desktop_exec_target "/home/arch/.config/autostart/umaos-installer-autostart.desktop"
check_executable_file "/home/arch/Desktop/Install Uma Musume.sh"

if grep -q '/usr/local/bin/umao-ensure-proton-ge' "$ROOT/etc/skel/Desktop/Install Uma Musume.sh" \
  && grep -q '/usr/local/bin/umao-ensure-proton-ge' "$ROOT/home/arch/Desktop/Install Uma Musume.sh" \
  && grep -q 'ensure_proton_ge' "$ROOT/usr/local/bin/umao-first-login-umamusume"; then
  pass "Umamusume launchers and first-login flow require Proton GE setup"
else
  fail "Umamusume flows are missing Proton GE setup integration"
fi

if grep -Eq '^x-scheme-handler/http=helium\.desktop$' "$ROOT/etc/skel/.config/mimeapps.list" \
  && grep -Eq '^x-scheme-handler/https=helium\.desktop$' "$ROOT/etc/skel/.config/mimeapps.list"; then
  pass "Installed-user MIME defaults route web links to Helium"
else
  fail "Missing Helium MIME defaults in /etc/skel/.config/mimeapps.list"
fi

if grep -Eq '^x-scheme-handler/http=helium\.desktop$' "$ROOT/home/arch/.config/mimeapps.list" \
  && grep -Eq '^x-scheme-handler/https=helium\.desktop$' "$ROOT/home/arch/.config/mimeapps.list"; then
  pass "Live-user MIME defaults route web links to Helium"
else
  fail "Missing Helium MIME defaults in /home/arch/.config/mimeapps.list"
fi

if [[ -n "$PKG_FILE" && -f "$PKG_FILE" ]]; then
  if grep -Fxq 'plasma6-wallpapers-smart-video-wallpaper-reborn' "$PKG_FILE"; then
    pass "Video wallpaper plugin package listed in $(basename "$PKG_FILE")"
  else
    warn "Video wallpaper plugin package not listed in $(basename "$PKG_FILE")"
  fi

  if grep -Fxq 'qt5-base' "$PKG_FILE"; then
    pass "Qt5 base runtime listed (required by current sddm-greeter build)"
  else
    fail "Missing qt5-base in $(basename "$PKG_FILE"); current sddm-greeter requires Qt5 runtime"
  fi

  if grep -Fxq 'qt5-declarative' "$PKG_FILE"; then
    pass "Qt5 declarative runtime listed (required by current sddm-greeter build)"
  else
    fail "Missing qt5-declarative in $(basename "$PKG_FILE"); current sddm-greeter requires Qt5 runtime"
  fi

  if grep -Fxq 'packagekit-qt6' "$PKG_FILE"; then
    pass "PackageKit Qt6 runtime listed (avoids Discover notifier missing-lib warnings)"
  else
    warn "packagekit-qt6 not listed in $(basename "$PKG_FILE"); Discover notifier may log missing library warnings"
  fi

  if grep -Fxq 'yay' "$PKG_FILE"; then
    pass "AUR helper package listed in $(basename "$PKG_FILE"): yay"
  else
    fail "Missing yay in $(basename "$PKG_FILE"); UmaOS should ship with a preinstalled AUR helper"
  fi

  if grep -Fxq 'flatpak' "$PKG_FILE"; then
    pass "Flatpak runtime listed in $(basename "$PKG_FILE")"
  else
    fail "Missing flatpak in $(basename "$PKG_FILE"); ProtonUp-Qt Flathub integration requires Flatpak"
  fi

  if grep -Fxq 'helium-browser-bin' "$PKG_FILE"; then
    pass "Default browser package listed in $(basename "$PKG_FILE"): helium-browser-bin"
  else
    fail "Missing helium-browser-bin in $(basename "$PKG_FILE"); UmaOS default browser should be Helium"
  fi
fi

if [[ -f "$REPO_ROOT/scripts/build-iso.sh" ]]; then
  if grep -q 'Wallhaven-\$id' "$REPO_ROOT/scripts/build-iso.sh" && grep -q 'metadata.json' "$REPO_ROOT/scripts/build-iso.sh"; then
    pass "Build script generates metadata.json for imported Wallhaven wallpapers"
  else
    warn "Build script may not generate metadata.json for imported Wallhaven wallpapers"
  fi
fi

if [[ "$EXPECTED_WALLHAVEN_COUNT" =~ ^[0-9]+$ ]] && ((EXPECTED_WALLHAVEN_COUNT > 0)); then
  wallhaven_count="$(find "$ROOT/usr/share/wallpapers" -maxdepth 1 -type d -name 'Wallhaven-*' 2>/dev/null | wc -l | tr -d '[:space:]')"
  if [[ "$wallhaven_count" =~ ^[0-9]+$ ]] && ((wallhaven_count > 0)); then
    pass "Wallhaven wallpapers imported: $wallhaven_count"
    if ((wallhaven_count < EXPECTED_WALLHAVEN_COUNT)); then
      warn "Wallhaven import count lower than manifest rows ($wallhaven_count < $EXPECTED_WALLHAVEN_COUNT)"
    fi
  else
    fail "Expected Wallhaven wallpapers from manifest, but none were imported into /usr/share/wallpapers"
  fi
fi

if ((fail_count > 0)); then
  echo "[umaos-customize-verify] Customization verification failed: $fail_count failure(s), $warn_count warning(s), $pass_count pass(es)." >&2
  exit 1
fi

echo "[umaos-customize-verify] Customization verification passed: $pass_count pass(es), $warn_count warning(s)."
