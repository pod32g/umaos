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
accel_help="$(qemu-system-x86_64 -accel help 2>/dev/null || true)"

if grep -q '^kvm$' <<<"$accel_help"; then
  accel_args=(-accel kvm)
  cpu_arg="host"
elif grep -q '^hvf$' <<<"$accel_help"; then
  accel_args=(-accel hvf)
  cpu_arg="host"
elif grep -q '^whpx$' <<<"$accel_help"; then
  accel_args=(-accel whpx)
  cpu_arg="host"
elif grep -q '^tcg$' <<<"$accel_help"; then
  accel_args=(-accel tcg)
else
  echo "No supported QEMU accelerator found; trying default execution." >&2
fi

if [[ "$cpu_arg" == "host" ]] && [[ " ${accel_args[*]} " == *" tcg "* ]]; then
  cpu_arg="max"
fi

exec qemu-system-x86_64 \
  -m 4096 \
  -smp 4 \
  -boot d \
  -cdrom "$ISO" \
  "${accel_args[@]}" \
  -cpu "$cpu_arg" \
  -vga virtio
