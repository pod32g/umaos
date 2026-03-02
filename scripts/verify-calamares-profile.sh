#!/usr/bin/env bash
set -euo pipefail

AIROOTFS_DIR="${1:-}"
if [[ -z "$AIROOTFS_DIR" ]]; then
  echo "[umaos-calamares-verify] ERROR: pass the airootfs root path" >&2
  echo "[umaos-calamares-verify] Example: scripts/verify-calamares-profile.sh build/profile/airootfs" >&2
  exit 2
fi

CAL_ROOT="$AIROOTFS_DIR/etc/calamares"
DEFAULTS_ROOT="$CAL_ROOT/umaos-defaults"
SETTINGS="$CAL_ROOT/settings.conf"
UNPACK="$CAL_ROOT/modules/unpackfs.conf"
BOOTLOADER="$CAL_ROOT/modules/bootloader.conf"
SHELLPROCESS_PRE="$CAL_ROOT/modules/shellprocess-preinit.conf"
SHELLPROCESS_POST="$CAL_ROOT/modules/shellprocess-postboot.conf"
BRANDING_DESC="$CAL_ROOT/branding/umaos/branding.desc"
BRANDING_LOGO="$CAL_ROOT/branding/umaos/ura_logo.png"
SYNC_HOOK="$AIROOTFS_DIR/etc/pacman.d/hooks/95-umao-calamares-config.hook"
SYNC_SCRIPT="$AIROOTFS_DIR/usr/local/bin/umao-sync-calamares-config"
GRUB_BRANDING_SCRIPT="$AIROOTFS_DIR/usr/local/bin/umao-apply-grub-branding"
FINALIZE_CUSTOMIZATION_SCRIPT="$AIROOTFS_DIR/usr/local/bin/umao-finalize-installed-customization"

failures=0

pass() {
  echo "[umaos-calamares-verify] PASS: $*"
}

fail() {
  echo "[umaos-calamares-verify] FAIL: $*" >&2
  failures=$((failures + 1))
}

check_file() {
  local file="$1"
  local label="$2"
  if [[ -f "$file" ]]; then
    pass "$label"
  else
    fail "$label (missing: $file)"
  fi
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

check_file "$SETTINGS" "Calamares settings present"
check_file "$UNPACK" "Calamares unpackfs config present"
check_file "$BOOTLOADER" "Calamares bootloader config present"
check_file "$SHELLPROCESS_PRE" "Calamares pre-init shellprocess config present"
check_file "$SHELLPROCESS_POST" "Calamares post-boot shellprocess config present"
check_file "$SYNC_HOOK" "Calamares sync pacman hook present"
check_file "$SYNC_SCRIPT" "Calamares sync helper script present"
check_file "$GRUB_BRANDING_SCRIPT" "GRUB branding helper script present"
check_file "$FINALIZE_CUSTOMIZATION_SCRIPT" "Install customization finalizer script present"
check_file "$BRANDING_DESC" "Calamares branding descriptor present"
check_file "$BRANDING_LOGO" "Calamares branding logo present"

if [[ -f "$SYNC_SCRIPT" && ! -x "$SYNC_SCRIPT" ]]; then
  fail "Calamares sync helper script is not executable"
fi

if [[ -f "$SETTINGS" ]]; then
  check_contains "$SETTINGS" 'modules-search:[[:space:]]*\[[[:space:]]*local[[:space:]]*\]' "Settings use local modules search"
  check_contains "$SETTINGS" '^[[:space:]]*-[[:space:]]*unpackfs[[:space:]]*$' "Exec sequence includes unpackfs"
  check_contains "$SETTINGS" '^[[:space:]]*-[[:space:]]*initcpiocfg[[:space:]]*$' "Exec sequence includes initcpiocfg"
  check_contains "$SETTINGS" '^[[:space:]]*-[[:space:]]*initcpio[[:space:]]*$' "Exec sequence includes initcpio"
  check_contains "$SETTINGS" '^[[:space:]]*-[[:space:]]*shellprocess@preinit[[:space:]]*$' "Exec sequence includes pre-init shellprocess instance"
  check_contains "$SETTINGS" '^[[:space:]]*-[[:space:]]*shellprocess@postboot[[:space:]]*$' "Exec sequence includes post-boot shellprocess instance"
  check_not_contains "$SETTINGS" '^[[:space:]]*-[[:space:]]*initramfs[[:space:]]*$' "Exec sequence excludes initramfs"
  check_contains "$SETTINGS" '^instances:' "Settings define module instances"
fi

if [[ -f "$SETTINGS" ]]; then
  shell_line="$(grep -nE '^[[:space:]]*-[[:space:]]*shellprocess@preinit[[:space:]]*$' "$SETTINGS" | head -n1 | cut -d: -f1 || true)"
  initcpio_line="$(grep -nE '^[[:space:]]*-[[:space:]]*initcpio[[:space:]]*$' "$SETTINGS" | head -n1 | cut -d: -f1 || true)"
  if [[ -n "$shell_line" && -n "$initcpio_line" && "$shell_line" -lt "$initcpio_line" ]]; then
    pass "pre-init shellprocess runs before initcpio"
  else
    fail "pre-init shellprocess must run before initcpio to normalize mkinitcpio presets"
  fi
fi

if [[ -f "$UNPACK" ]]; then
  check_contains "$UNPACK" 'sourcefs:[[:space:]]*"(squashfs|erofs)"' "Unpack source filesystem set for live image"
  check_contains "$UNPACK" 'airootfs\.(sfs|erofs)' "Unpack source points at live airootfs image"
  check_not_contains "$UNPACK" '^[[:space:]]*source:[[:space:]]*".*/CHANGES"' "Unpack config does not use Calamares sample /CHANGES path"
fi

if [[ -f "$BOOTLOADER" ]]; then
  check_contains "$BOOTLOADER" 'efiBootLoader:[[:space:]]*"grub"' "UEFI bootloader default is GRUB"
  check_contains "$BOOTLOADER" 'grubInstall:[[:space:]]*"grub-install"' "Bootloader config defines grubInstall command"
  check_contains "$BOOTLOADER" 'grubMkconfig:[[:space:]]*"grub-mkconfig"' "Bootloader config defines grubMkconfig command"
  check_contains "$BOOTLOADER" 'grubCfg:[[:space:]]*"/boot/grub/grub\.cfg"' "Bootloader config defines grubCfg path"
  check_contains "$BOOTLOADER" 'grubProbe:[[:space:]]*"grub-probe"' "Bootloader config defines grubProbe command"
  check_contains "$BOOTLOADER" 'efiBootMgr:[[:space:]]*"efibootmgr"' "Bootloader config defines efiBootMgr command"
fi

if [[ -f "$SHELLPROCESS_PRE" ]]; then
  check_contains "$SHELLPROCESS_PRE" 'umao-fix-initcpio-preset' "pre-init shellprocess runs initcpio preset normalizer"
fi

if [[ -f "$SHELLPROCESS_POST" ]]; then
  check_contains "$SHELLPROCESS_POST" 'umao-finalize-installed-customization' "post-boot shellprocess runs install customization finalizer"
  check_contains "$SHELLPROCESS_POST" 'umao-fix-boot-root-cmdline' "post-boot shellprocess runs root cmdline fixer"
  check_contains "$SHELLPROCESS_POST" 'umao-apply-grub-branding' "post-boot shellprocess runs GRUB branding helper"
fi

if [[ -f "$BRANDING_DESC" ]]; then
  check_contains "$BRANDING_DESC" 'productIcon:[[:space:]]*"ura_logo\.png"' "Calamares product icon uses ura_logo.png"
  check_contains "$BRANDING_DESC" 'productLogo:[[:space:]]*"ura_logo\.png"' "Calamares product logo uses ura_logo.png"
fi

if [[ -d "$DEFAULTS_ROOT" ]]; then
  check_file "$DEFAULTS_ROOT/settings.conf" "Calamares defaults settings snapshot present"
  check_file "$DEFAULTS_ROOT/modules/unpackfs.conf" "Calamares defaults unpack snapshot present"
  check_file "$DEFAULTS_ROOT/modules/shellprocess-preinit.conf" "Calamares defaults pre-init shellprocess snapshot present"
  check_file "$DEFAULTS_ROOT/modules/shellprocess-postboot.conf" "Calamares defaults post-boot shellprocess snapshot present"
else
  fail "Calamares defaults directory missing ($DEFAULTS_ROOT)"
fi

if ((failures > 0)); then
  echo "[umaos-calamares-verify] Verification failed with $failures issue(s)." >&2
  exit 1
fi

echo "[umaos-calamares-verify] Verification succeeded."
