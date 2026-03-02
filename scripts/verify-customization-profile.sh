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

require_file "/usr/share/wallpapers/UmaOS/contents/images/1920x1080.svg"
require_file "/usr/share/wallpapers/UmaOS/contents/videos/qloo.mp4"
require_file "/usr/share/wallpapers/UmaOS/metadata.json"
require_file "/usr/share/wallpapers/UmaBoot/metadata.json"
require_file "/usr/local/bin/umao-apply-theme"
require_file "/etc/skel/.config/ksplashrc"

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

require_executable "/usr/local/bin/umao-install"
require_executable "/usr/local/bin/umao-installer-autostart"
require_executable "/usr/local/bin/umao-first-login-umamusume"
require_executable "/usr/local/bin/umao-install-steam-root"

check_desktop_exec_target "/etc/skel/.config/autostart/umaos-first-login.desktop"
check_desktop_exec_target "/etc/skel/.config/autostart/umao-umamusume-first-login.desktop"
check_desktop_exec_target "/home/arch/.config/autostart/umaos-installer-autostart.desktop"
check_executable_file "/home/arch/Desktop/Install Uma Musume.sh"

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
