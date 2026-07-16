#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_PATH="${1:-}"

if [[ -z "$ISO_PATH" ]]; then
  ISO_PATH="$(ls -1t "$ROOT_DIR"/out/*.iso 2>/dev/null | head -n1 || true)"
fi

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
  echo "[umaos-verify] ERROR: ISO file not found. Pass path or build one in out/." >&2
  exit 2
fi

if ! command -v bsdtar >/dev/null 2>&1; then
  echo "[umaos-verify] ERROR: bsdtar is required for ISO verification." >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

extract_from_iso() {
  local path="$1"
  bsdtar -xf "$ISO_PATH" -C "$tmp_dir" "$path" 2>/dev/null || true
}

pass() {
  echo "[umaos-verify] PASS: $*"
}

fail() {
  echo "[umaos-verify] FAIL: $*" >&2
  failures=$((failures + 1))
}

check_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label (missing pattern: $pattern)"
  fi
}

check_not_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$file"; then
    fail "$label (unexpected pattern: $pattern)"
  else
    pass "$label"
  fi
}

failures=0

extract_from_iso "boot/grub/grub.cfg"
extract_from_iso "boot/grub/loopback.cfg"
extract_from_iso "boot/syslinux/archiso_sys-linux.cfg"
extract_from_iso "boot/syslinux/archiso_head.cfg"
extract_from_iso "boot/syslinux/splash.png"
extract_from_iso "loader/entries/01-archiso-linux.conf"
extract_from_iso "loader/entries/02-archiso-speech-linux.conf"
# The GRUB theme payload itself: grub.cfg is checked for a themes/umaos
# reference below, but without extracting the theme a missing payload passed
# verification and GRUB silently fell back to the stock menu.
extract_from_iso "boot/grub/themes/umaos"

grub_cfg="$tmp_dir/boot/grub/grub.cfg"
loopback_cfg="$tmp_dir/boot/grub/loopback.cfg"
syslinux_cfg="$tmp_dir/boot/syslinux/archiso_sys-linux.cfg"
syslinux_bg="$tmp_dir/boot/syslinux/splash.png"
loader_entry_1="$tmp_dir/loader/entries/01-archiso-linux.conf"
loader_entry_2="$tmp_dir/loader/entries/02-archiso-speech-linux.conf"

[[ -f "$loopback_cfg" ]] && pass "Found boot/grub/loopback.cfg" || fail "Missing boot/grub/loopback.cfg"
[[ -f "$syslinux_cfg" ]] && pass "Found boot/syslinux/archiso_sys-linux.cfg" || fail "Missing boot/syslinux/archiso_sys-linux.cfg"

# Presence alone proves nothing: stock releng ships its own
# boot/syslinux/splash.png, so this check passed with the unbranded Arch splash
# even when configure_boot_branding's override was silently skipped. Compare
# against the source image the build is supposed to have installed.
if [[ -f "$syslinux_bg" ]]; then
  pass "Found boot/syslinux/splash.png"
  # configure_boot_branding picks whichever source is available (the generated
  # GRUB gradient if present, else the static uma1 art), so accept ANY of them:
  # the question this answers is "is the splash ours, or stock releng's?".
  syslinux_matched=""
  syslinux_available=0
  for cand in "$ROOT_DIR/archiso/airootfs/usr/share/grub/themes/umaos/background.png" \
              "$ROOT_DIR/assets/boot/uma1-syslinux.png" \
              "$ROOT_DIR/assets/boot/uma1.png"; do
    [[ -f "$cand" ]] || continue
    syslinux_available=1
    if cmp -s "$syslinux_bg" "$cand"; then
      syslinux_matched="$cand"
      break
    fi
  done
  if ((syslinux_available == 0)); then
    echo "[umaos-verify] WARN: no UmaOS syslinux splash source available to compare against" >&2
  elif [[ -n "$syslinux_matched" ]]; then
    pass "Syslinux splash matches a UmaOS source image ($(basename "$syslinux_matched"))"
  else
    fail "Syslinux splash matches no UmaOS source image — the branding override was skipped and the stock Arch splash shipped"
  fi
else
  fail "Missing boot/syslinux/splash.png"
fi

# GRUB theme payload (grub.cfg only *references* it; without these the theme
# can be absent from the ISO and GRUB silently falls back).
if [[ -f "$grub_cfg" ]]; then
  iso_theme_dir="$tmp_dir/boot/grub/themes/umaos"
  [[ -f "$iso_theme_dir/theme.txt" ]] \
    && pass "GRUB theme payload present (boot/grub/themes/umaos/theme.txt)" \
    || fail "GRUB theme payload missing from ISO (boot/grub/themes/umaos/theme.txt) — grub.cfg references a theme that is not there"
  [[ -f "$iso_theme_dir/background.png" ]] \
    && pass "GRUB theme background present" \
    || fail "GRUB theme background.png missing from ISO"
  if compgen -G "$iso_theme_dir/*.pf2" >/dev/null 2>&1; then
    pass "GRUB theme fonts (.pf2) present"
  else
    fail "GRUB theme fonts (.pf2) missing from ISO — theme text will not render"
  fi
fi

uefi_mode=""
if [[ -f "$grub_cfg" ]]; then
  uefi_mode="grub"
  pass "Detected UEFI GRUB configuration (boot/grub/grub.cfg)"
elif [[ -f "$loader_entry_1" || -f "$loader_entry_2" ]]; then
  uefi_mode="systemd-boot"
  pass "Detected UEFI systemd-boot configuration (loader/entries)"
else
  fail "Missing UEFI boot configuration (neither boot/grub/grub.cfg nor loader/entries/*.conf found)"
fi

if [[ "$uefi_mode" == "systemd-boot" ]]; then
  [[ -f "$loader_entry_1" ]] && pass "Found loader/entries/01-archiso-linux.conf" || fail "Missing loader/entries/01-archiso-linux.conf"
  [[ -f "$loader_entry_2" ]] && pass "Found loader/entries/02-archiso-speech-linux.conf" || fail "Missing loader/entries/02-archiso-speech-linux.conf"
fi

if [[ -f "$grub_cfg" ]]; then
  check_contains "$grub_cfg" 'themes/umaos/theme.txt' "GRUB custom theme reference present"
  check_contains "$grub_cfg" '### UMAOS GRUB THEME START' "GRUB theme block injected"
  check_contains "$grub_cfg" 'terminal_output gfxterm' "GRUB uses graphical terminal output"
  check_contains "$grub_cfg" 'UmaOS install medium' "GRUB menu title branded"
  check_not_contains "$grub_cfg" 'Arch Linux install medium' "GRUB Arch branding removed"
fi

if [[ -f "$loopback_cfg" ]]; then
  check_contains "$loopback_cfg" 'themes/umaos/theme.txt' "Loopback GRUB custom theme reference present"
  check_contains "$loopback_cfg" '### UMAOS GRUB THEME START' "Loopback GRUB theme block injected"
  check_contains "$loopback_cfg" 'UmaOS install medium' "Loopback GRUB menu title branded"
  check_not_contains "$loopback_cfg" 'Arch Linux install medium' "Loopback GRUB Arch branding removed"
fi

if [[ -f "$syslinux_cfg" ]]; then
  check_contains "$syslinux_cfg" 'UmaOS install medium' "Syslinux menu title branded"
  check_not_contains "$syslinux_cfg" 'Arch Linux install medium' "Syslinux Arch branding removed"
fi

if [[ "$uefi_mode" == "systemd-boot" && -f "$loader_entry_1" ]]; then
  check_contains "$loader_entry_1" '^title[[:space:]]+UmaOS install medium' "UEFI loader primary entry branded"
  check_not_contains "$loader_entry_1" '^title[[:space:]]+Arch Linux install medium' "UEFI loader primary Arch branding removed"
fi

if [[ "$uefi_mode" == "systemd-boot" && -f "$loader_entry_2" ]]; then
  check_contains "$loader_entry_2" '^title[[:space:]]+UmaOS install medium' "UEFI loader speech entry branded"
  check_not_contains "$loader_entry_2" '^title[[:space:]]+Arch Linux install medium' "UEFI loader speech Arch branding removed"
fi

if ((failures > 0)); then
  echo "[umaos-verify] Branding verification failed with $failures issue(s)." >&2
  exit 1
fi

echo "[umaos-verify] Branding verification succeeded."
