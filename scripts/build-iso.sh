#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELENG_DIR="/usr/share/archiso/configs/releng"
BUILD_PROFILE="$ROOT_DIR/build/profile"
WORK_DIR="$ROOT_DIR/work"
OUT_DIR="$ROOT_DIR/out"
DATE_TAG="$(date +%Y.%m.%d)"
ISO_LABEL="UMAOS_$(date +%Y%m)"

CALAMARES_REQUIRED_PKGS=(calamares ckbcomp)
MISSING_CALAMARES_PKGS=()
ALLOW_AUR="${UMAOS_ALLOW_AUR:-0}"
AUR_SRC_DIR="$ROOT_DIR/build/aur-src"
LOCAL_REPO_DIR="$ROOT_DIR/build/localrepo"
LOCAL_REPO_NAME="umaos-local"
LOCAL_REPO_DB="$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.db.tar.gz"

log() {
  echo "[umaos] $*"
}

die() {
  echo "[umaos] ERROR: $*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Missing required command: $cmd"
  fi
}

package_available_official() {
  local pkg="$1"
  pacman -Si "$pkg" >/dev/null 2>&1
}

find_missing_calamares_packages() {
  local pkg
  for pkg in "${CALAMARES_REQUIRED_PKGS[@]}"; do
    if ! package_available_official "$pkg"; then
      MISSING_CALAMARES_PKGS+=("$pkg")
    fi
  done
}

prepare_local_repo_pacman_conf() {
  local pacman_conf="$BUILD_PROFILE/pacman.conf"
  local patched_conf="$BUILD_PROFILE/pacman.conf.with-local"

  if [[ ! -d "$LOCAL_REPO_DIR" ]]; then
    return 0
  fi

  cat > "$patched_conf" <<PACCONF
[$LOCAL_REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$LOCAL_REPO_DIR

PACCONF
  cat "$pacman_conf" >> "$patched_conf"
  mv "$patched_conf" "$pacman_conf"

  log "Injected local repo '$LOCAL_REPO_NAME' into build pacman.conf"
}

build_missing_calamares_from_aur() {
  local builder_user="${USER:-}"
  local pkg
  local pkg_src
  local pkg_file
  local built_pkg_files=()

  require_cmd git
  require_cmd makepkg
  require_cmd repo-add

  if [[ "$EUID" -eq 0 ]]; then
    require_cmd sudo
    if [[ -z "${SUDO_USER:-}" ]]; then
      die "AUR fallback requires a non-root builder user. Run with sudo from a normal user account."
    fi
    builder_user="$SUDO_USER"
  fi

  log "AUR fallback enabled. Building missing packages as user '$builder_user': ${MISSING_CALAMARES_PKGS[*]}"

  mkdir -p "$AUR_SRC_DIR" "$LOCAL_REPO_DIR"

  for pkg in "${MISSING_CALAMARES_PKGS[@]}"; do
    pkg_src="$AUR_SRC_DIR/$pkg"

    if [[ "$EUID" -eq 0 ]]; then
      sudo -u "$builder_user" bash -lc "rm -rf '$pkg_src' && git clone --depth=1 'https://aur.archlinux.org/$pkg.git' '$pkg_src'"
      sudo -u "$builder_user" bash -lc "cd '$pkg_src' && makepkg -s --needed --noconfirm"
    else
      rm -rf "$pkg_src"
      git clone --depth=1 "https://aur.archlinux.org/$pkg.git" "$pkg_src"
      (cd "$pkg_src" && makepkg -s --needed --noconfirm)
    fi

    pkg_file=""
    for candidate in "$pkg_src"/"$pkg"-*.pkg.tar.*; do
      [[ -f "$candidate" ]] || continue
      [[ "$candidate" == *.sig ]] && continue
      pkg_file="$candidate"
    done

    [[ -n "$pkg_file" ]] || die "AUR build for '$pkg' did not produce a package file"
    cp -f "$pkg_file" "$LOCAL_REPO_DIR/"
    built_pkg_files+=("$LOCAL_REPO_DIR/$(basename "$pkg_file")")
  done

  rm -f "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.db" "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.db.tar.gz" \
    "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.files" "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.files.tar.gz"

  repo-add "$LOCAL_REPO_DB" "${built_pkg_files[@]}"
  log "Created local package repo at $LOCAL_REPO_DIR"
}

if [[ ! -d "$RELENG_DIR" ]]; then
  die "releng profile not found at $RELENG_DIR. Install archiso: sudo pacman -S --needed archiso"
fi

require_cmd rsync
require_cmd sed
require_cmd mkarchiso
require_cmd pacman

find_missing_calamares_packages
if ((${#MISSING_CALAMARES_PKGS[@]} > 0)); then
  if [[ "$ALLOW_AUR" == "1" ]]; then
    build_missing_calamares_from_aur
  else
    die "Missing Calamares packages in official repos: ${MISSING_CALAMARES_PKGS[*]}. Re-run with UMAOS_ALLOW_AUR=1 to enable AUR fallback."
  fi
fi

rm -rf "$BUILD_PROFILE"
mkdir -p "$BUILD_PROFILE" "$WORK_DIR" "$OUT_DIR"

rsync -a --delete "$RELENG_DIR/" "$BUILD_PROFILE/"

if [[ -f "$ROOT_DIR/archiso/packages.x86_64" ]]; then
  cat "$ROOT_DIR/archiso/packages.x86_64" >> "$BUILD_PROFILE/packages.x86_64"
fi

if [[ -d "$ROOT_DIR/archiso/airootfs" ]]; then
  rsync -a "$ROOT_DIR/archiso/airootfs/" "$BUILD_PROFILE/airootfs/"
fi

if [[ -f "$LOCAL_REPO_DB" ]]; then
  prepare_local_repo_pacman_conf
fi

sed -i.bak "s/^iso_name=.*/iso_name=\"umaos\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_label=.*/iso_label=\"$ISO_LABEL\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_publisher=.*/iso_publisher=\"UmaOS Project <https:\/\/example.com\/umaos>\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_application=.*/iso_application=\"UmaOS Live ISO\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_version=.*/iso_version=\"$DATE_TAG\"/" "$BUILD_PROFILE/profiledef.sh"
rm -f "$BUILD_PROFILE/profiledef.sh.bak"

log "Building UmaOS ISO..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$BUILD_PROFILE"

log "Build complete. ISO files:"
ls -1 "$OUT_DIR"/*.iso
