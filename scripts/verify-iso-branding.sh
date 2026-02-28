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
extract_from_iso "boot/syslinux/splash.png"
extract_from_iso "loader/entries/01-archiso-linux.conf"
extract_from_iso "loader/entries/02-archiso-speech-linux.conf"

grub_cfg="$tmp_dir/boot/grub/grub.cfg"
loopback_cfg="$tmp_dir/boot/grub/loopback.cfg"
syslinux_cfg="$tmp_dir/boot/syslinux/archiso_sys-linux.cfg"
syslinux_bg="$tmp_dir/boot/syslinux/splash.png"
loader_entry_1="$tmp_dir/loader/entries/01-archiso-linux.conf"
loader_entry_2="$tmp_dir/loader/entries/02-archiso-speech-linux.conf"

[[ -f "$loopback_cfg" ]] && pass "Found boot/grub/loopback.cfg" || fail "Missing boot/grub/loopback.cfg"
[[ -f "$syslinux_cfg" ]] && pass "Found boot/syslinux/archiso_sys-linux.cfg" || fail "Missing boot/syslinux/archiso_sys-linux.cfg"
[[ -f "$syslinux_bg" ]] && pass "Found boot/syslinux/splash.png" || fail "Missing boot/syslinux/splash.png"

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
  check_contains "$grub_cfg" 'background_image /boot/syslinux/splash.png' "GRUB background injection present"
  check_contains "$grub_cfg" 'UmaOS install medium' "GRUB menu title branded"
  check_not_contains "$grub_cfg" 'Arch Linux install medium' "GRUB Arch branding removed"
fi

if [[ -f "$loopback_cfg" ]]; then
  check_contains "$loopback_cfg" 'background_image /boot/syslinux/splash.png' "Loopback GRUB background injection present"
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
