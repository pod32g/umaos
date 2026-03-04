#!/usr/bin/env bash
set -euo pipefail

required=(mkarchiso rsync pacman grub-mkstandalone)
missing=()

for cmd in "${required[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done

if [[ "${UMAOS_ALLOW_AUR:-0}" == "1" ]]; then
  aur_required=(git makepkg repo-add)
  for cmd in "${aur_required[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ "$EUID" -eq 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    missing+=("sudo")
  fi
fi

if ((${#missing[@]} > 0)); then
  echo "Missing required tools: ${missing[*]}" >&2
  echo "Install base tools with: sudo pacman -S --needed archiso rsync pacman grub" >&2
  if [[ "${UMAOS_ALLOW_AUR:-0}" == "1" ]]; then
    echo "AUR fallback also needs: sudo pacman -S --needed git base-devel pacman-contrib sudo" >&2
  fi
  exit 1
fi

# ── Font checks (warnings, not fatal) ──
if ! command -v grub-mkfont >/dev/null 2>&1; then
  echo "WARNING: grub-mkfont not found. GRUB theme will use default font." >&2
  echo "  Install with: sudo pacman -S --needed grub" >&2
fi

# CJK font needed on the BUILD machine for grub-mkfont to generate
# PF2 fonts that include the Japanese subtitle (ウマ娘 プリティーダービー).
cjk_found=0
for f in \
  /usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc \
  /usr/share/fonts/noto-cjk/NotoSansJP-Regular.otf \
  /usr/share/fonts/OTF/NotoSansCJK-Regular.ttc; do
  if [[ -f "$f" ]]; then
    cjk_found=1
    break
  fi
done
if [[ "$cjk_found" -eq 0 ]]; then
  echo "WARNING: noto-fonts-cjk not found. GRUB Japanese subtitle will use Unifont fallback." >&2
  echo "  Install with: sudo pacman -S --needed noto-fonts-cjk" >&2
fi

echo "Prerequisites OK"
echo "Umazing!"
