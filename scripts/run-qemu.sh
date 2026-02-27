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
case "$(uname -s)" in
  Linux)
    accel_args=(-enable-kvm)
    cpu_arg="host"
    ;;
  Darwin)
    accel_args=(-accel hvf)
    cpu_arg="host"
    ;;
esac

exec qemu-system-x86_64 \
  -m 4096 \
  -smp 4 \
  -boot d \
  -cdrom "$ISO" \
  "${accel_args[@]}" \
  -cpu "$cpu_arg" \
  -vga virtio
