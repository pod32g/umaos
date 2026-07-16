#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="$(ls -1t "$ROOT_DIR"/out/*.iso 2>/dev/null | head -n1 || true)"

if [[ -z "$ISO" ]]; then
  echo "No ISO found in out/. Build first with ./scripts/build-iso.sh" >&2
  exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "qemu-system-x86_64 missing. Install qemu-desktop (Arch) or qemu (other distros)." >&2
  exit 1
fi

accel_args=()
cpu_arg="max"
# `-accel help` lists accelerators QEMU was COMPILED with, not ones usable
# right now: on a Linux box without /dev/kvm (no kvm module, a container, or
# missing permissions) kvm is listed but launching with it fails. Probe for
# actual usability, not just support.
accel_help="$(qemu-system-x86_64 -accel help 2>/dev/null || true)"

if grep -q '^kvm$' <<<"$accel_help" && [[ -r /dev/kvm && -w /dev/kvm ]]; then
  accel_args=(-accel kvm)
  cpu_arg="host"
elif grep -q '^hvf$' <<<"$accel_help" && [[ "$(uname -s)" == "Darwin" ]]; then
  accel_args=(-accel hvf)
  cpu_arg="host"
elif grep -q '^whpx$' <<<"$accel_help"; then
  accel_args=(-accel whpx)
  cpu_arg="host"
elif grep -q '^tcg$' <<<"$accel_help"; then
  accel_args=(-accel tcg)
  if grep -q '^kvm$' <<<"$accel_help" && [[ ! -e /dev/kvm ]]; then
    echo "Note: QEMU supports KVM but /dev/kvm is not present; falling back to TCG." >&2
  elif grep -q '^kvm$' <<<"$accel_help" && [[ ! -w /dev/kvm ]]; then
    echo "Note: /dev/kvm exists but is not writable by $(id -un); add yourself to the 'kvm' group." >&2
  fi
  echo "Warning: QEMU is using TCG software emulation (no hardware acceleration detected)." >&2
  echo "Performance will be significantly slower, especially for KDE/graphics." >&2
  echo "For better speed, run on x86_64 Linux with KVM or Intel macOS with HVF-enabled x86_64 QEMU." >&2
else
  echo "No supported QEMU accelerator found; trying default execution." >&2
fi

# The build ships bootmodes=('bios.syslinux' 'uefi.grub'), but this smoke test
# only ever exercised the BIOS path — the UEFI GRUB menu and its custom theme,
# a headline feature, were never booted here. Use OVMF when available, or set
# UMAOS_QEMU_UEFI=0 to force BIOS.
firmware_args=()
if [[ "${UMAOS_QEMU_UEFI:-1}" == "1" ]]; then
  for ovmf in /usr/share/edk2/x64/OVMF_CODE.4m.fd \
              /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
              /usr/share/OVMF/OVMF_CODE.fd \
              /opt/homebrew/share/qemu/edk2-x86_64-code.fd \
              /usr/local/share/qemu/edk2-x86_64-code.fd; do
    if [[ -r "$ovmf" ]]; then
      firmware_args=(-drive "if=pflash,format=raw,readonly=on,file=$ovmf")
      echo "Booting via UEFI firmware: $ovmf (set UMAOS_QEMU_UEFI=0 for BIOS)" >&2
      break
    fi
  done
  if ((${#firmware_args[@]} == 0)); then
    echo "Note: no OVMF firmware found; booting BIOS/syslinux. Install edk2-ovmf to test the UEFI GRUB theme." >&2
  fi
fi

# "${arr[@]}" on an empty array is an unbound-variable error under `set -u` on
# bash < 4.4 — including the macOS bash 3.2 this script explicitly targets via
# its hvf branch. Build the argv up front instead.
qemu_args=(-m 4096 -smp 4 -boot d -cdrom "$ISO" -cpu "$cpu_arg" -vga virtio)
# if-blocks rather than `((...)) && cmd`: that form evaluates to 1 when the
# array is empty, which is the same set -e footgun that broke
# umao-prepare-calamares.
if ((${#accel_args[@]} > 0)); then
  qemu_args+=("${accel_args[@]}")
fi
if ((${#firmware_args[@]} > 0)); then
  qemu_args+=("${firmware_args[@]}")
fi

if qemu-system-x86_64 "${qemu_args[@]}"; then
  echo "Umazing!"
else
  rc=$?
  echo "QEMU exited with code $rc. Check terminal output above for diagnostics." >&2
  echo "ISO: $ISO" >&2
  exit $rc
fi
