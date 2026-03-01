#!/usr/bin/env bash
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  echo "[umaos] ERROR: scripts/build-iso.sh must be run with bash." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELENG_DIR="/usr/share/archiso/configs/releng"
BUILD_PROFILE="$ROOT_DIR/build/profile"
WORK_DIR="$ROOT_DIR/work"
OUT_DIR="$ROOT_DIR/out"
DATE_TAG="$(date +%Y.%m.%d)"
ISO_LABEL="UMAOS_$(date +%Y%m)"

REQUIRED_REPO_PKGS=(
  calamares
  xorg-xkbcomp
  plasma6-wallpapers-smart-video-wallpaper-reborn
)
MISSING_REQUIRED_PKGS=()
ALLOW_AUR="${UMAOS_ALLOW_AUR:-0}"
AUR_SRC_DIR="$ROOT_DIR/build/aur-src"
LOCAL_REPO_DIR="$ROOT_DIR/build/localrepo"
LOCAL_REPO_NAME="umaos-local"
LOCAL_REPO_DB="$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.db.tar.gz"
GRUB_BACKGROUND_SRC="$ROOT_DIR/assets/boot/uma1.png"
SYSLINUX_BACKGROUND_SRC="$ROOT_DIR/assets/boot/uma1-syslinux.png"
WALLHAVEN_ASSETS_DIR="$ROOT_DIR/assets/wallpapers/wallhaven"
WALLHAVEN_IMAGES_DIR="$WALLHAVEN_ASSETS_DIR/images"
WALLHAVEN_MANIFEST="$WALLHAVEN_ASSETS_DIR/manifest.tsv"
INCLUDE_WALLHAVEN="${UMAOS_INCLUDE_WALLHAVEN:-1}"

log() {
  echo "[umaos] $*"
}

die() {
  echo "[umaos] ERROR: $*" >&2
  exit 1
}

warn() {
  echo "[umaos] WARN: $*" >&2
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

find_missing_required_packages() {
  local pkg
  for pkg in "${REQUIRED_REPO_PKGS[@]}"; do
    if ! package_available_official "$pkg"; then
      MISSING_REQUIRED_PKGS+=("$pkg")
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

find_cursor_archives() {
  find "$ROOT_DIR/assets/cursors" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null | sort -u
}

sanitize_theme_dir() {
  local raw="$1"
  printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

install_custom_cursor_themes() {
  local dest_icons="$BUILD_PROFILE/airootfs/usr/share/icons"
  local archive
  local idx_path
  local source_subdir
  local extract_root
  local extract_dir
  local theme_name
  local theme_dir
  local target_dir
  local installed=0
  local -a archives=()

  mapfile -t archives < <(find_cursor_archives)
  if ((${#archives[@]} == 0)); then
    log "No custom cursor archives found; skipping cursor import."
    return 0
  fi

  mkdir -p "$dest_icons"

  for archive in "${archives[@]}"; do
    if ! idx_path="$(tar -tzf "$archive" 2>/dev/null | awk '
      /(^|\/)index\.theme$/ && !found {
        print
        found=1
      }
      END {
        if (!found) {
          exit 1
        }
      }
    ')"; then
      warn "Skipping cursor archive without index.theme: $archive"
      continue
    fi

    source_subdir="${idx_path%/index.theme}"
    if [[ "$idx_path" == "index.theme" ]]; then
      source_subdir=""
    fi

    extract_root="$(mktemp -d)"
    tar -xzf "$archive" -C "$extract_root"
    extract_dir="$extract_root"

    if [[ -n "$source_subdir" ]]; then
      extract_dir="$extract_dir/$source_subdir"
    fi

    if [[ ! -f "$extract_dir/index.theme" || ! -d "$extract_dir/cursors" ]]; then
      warn "Skipping invalid cursor archive layout: $archive"
      rm -rf "$extract_root"
      continue
    fi

    theme_name="$(awk -F= '/^Name=/{print $2; exit}' "$extract_dir/index.theme" | tr -d '\r')"
    if [[ -z "$theme_name" ]]; then
      theme_name="$(basename "$archive")"
      theme_name="${theme_name%.tar.gz}"
      theme_name="${theme_name%.tgz}"
    fi

    theme_dir="$(sanitize_theme_dir "$theme_name")"
    if [[ -z "$theme_dir" ]]; then
      warn "Skipping cursor archive with unresolvable theme name: $archive"
      rm -rf "$extract_root"
      continue
    fi

    target_dir="$dest_icons/$theme_dir"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -a "$extract_dir"/. "$target_dir"/

    installed=$((installed + 1))
    log "Installed cursor theme '$theme_name' as '$theme_dir'"
    rm -rf "$extract_root"
  done

  log "Installed $installed custom cursor theme(s)."
}

install_wallhaven_wallpapers() {
  local wallpapers_root="$BUILD_PROFILE/airootfs/usr/share/wallpapers"
  local id
  local width
  local height
  local ext
  local filename
  local url
  local src
  local pkg_dir
  local img_dir
  local out_name
  local safe_width
  local safe_height
  local imported=0

  if [[ "$INCLUDE_WALLHAVEN" != "1" ]]; then
    log "Wallhaven wallpaper import disabled (UMAOS_INCLUDE_WALLHAVEN=$INCLUDE_WALLHAVEN)."
    return 0
  fi

  if [[ ! -f "$WALLHAVEN_MANIFEST" ]]; then
    log "No Wallhaven manifest found at $WALLHAVEN_MANIFEST; skipping import."
    return 0
  fi

  mkdir -p "$wallpapers_root"

  while IFS=$'\t' read -r id width height ext filename url; do
    [[ -z "$id" || "$id" == "id" ]] && continue
    src="$WALLHAVEN_IMAGES_DIR/$filename"
    if [[ ! -s "$src" ]]; then
      warn "Skipping missing Wallhaven file for id=$id: $src"
      continue
    fi

    safe_width="$width"
    safe_height="$height"
    if [[ ! "$safe_width" =~ ^[0-9]+$ ]]; then
      safe_width=1920
    fi
    if [[ ! "$safe_height" =~ ^[0-9]+$ ]]; then
      safe_height=1080
    fi
    if [[ ! "$ext" =~ ^\.[A-Za-z0-9]+$ ]]; then
      ext=".jpg"
    fi

    pkg_dir="$wallpapers_root/Wallhaven-$id"
    img_dir="$pkg_dir/contents/images"
    out_name="${safe_width}x${safe_height}${ext,,}"

    rm -rf "$pkg_dir"
    mkdir -p "$img_dir"
    cp -f "$src" "$img_dir/$out_name"

    cat > "$pkg_dir/metadata.desktop" <<EOF
[Desktop Entry]
Type=Service
Name=Wallhaven $id
Comment=Uma Musume wallpaper from Wallhaven ($id)

[X-KDE-PluginInfo]
Name=Wallhaven-$id
Author=Wallhaven contributor
License=Unknown
EOF

    imported=$((imported + 1))
  done < "$WALLHAVEN_MANIFEST"

  log "Imported $imported Wallhaven wallpaper option(s) from $WALLHAVEN_MANIFEST."
}

build_missing_required_from_aur() {
  local builder_user="${USER:-}"
  local pkg
  local pkg_src
  local pkg_files
  local file
  local copied_count
  local has_requested_pkg
  local cached_pkg
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

  log "AUR fallback enabled. Building missing packages as user '$builder_user': ${MISSING_REQUIRED_PKGS[*]}"

  mkdir -p "$AUR_SRC_DIR" "$LOCAL_REPO_DIR"
  if [[ "$EUID" -eq 0 ]]; then
    chown -R "$builder_user":"$builder_user" "$AUR_SRC_DIR"
  fi

  for pkg in "${MISSING_REQUIRED_PKGS[@]}"; do
    cached_pkg="$(find "$LOCAL_REPO_DIR" -maxdepth 1 -type f -name "$pkg-*.pkg.tar.*" \
      ! -name "*.sig" ! -name "*-debug-*.pkg.tar.*" | sort | tail -n 1)"
    if [[ -n "$cached_pkg" ]]; then
      built_pkg_files+=("$cached_pkg")
      log "Reusing cached local package for '$pkg': $(basename "$cached_pkg")"
      continue
    fi

    pkg_src="$AUR_SRC_DIR/$pkg"

    if [[ "$EUID" -eq 0 ]]; then
      sudo -u "$builder_user" bash -lc "rm -rf '$pkg_src' && git clone --depth=1 'https://aur.archlinux.org/$pkg.git' '$pkg_src'"
    else
      rm -rf "$pkg_src"
      git clone --depth=1 "https://aur.archlinux.org/$pkg.git" "$pkg_src"
    fi

    if [[ "$pkg" == "calamares" && -f "$pkg_src/PKGBUILD" ]]; then
      # Ensure Python-backed installer modules are built in AUR fallback builds.
      if ! grep -q "'python'" "$pkg_src/PKGBUILD"; then
        sed -i "/'qt6-translations'/a\\  'python'" "$pkg_src/PKGBUILD"
      fi
      if ! grep -q -- "-DWITH_PYTHON=ON" "$pkg_src/PKGBUILD"; then
        sed -i "/-DWITH_QT6=ON/a\\    -DWITH_PYTHON=ON\\n    -DWITH_PYBIND11=ON" "$pkg_src/PKGBUILD"
      fi
    fi

    if [[ "$EUID" -eq 0 ]]; then
      sudo -u "$builder_user" bash -lc "cd '$pkg_src' && makepkg -s --needed --noconfirm"
    else
      (cd "$pkg_src" && makepkg -s --needed --noconfirm)
    fi

    copied_count=0
    has_requested_pkg=0
    while IFS= read -r file; do
      cp -f "$file" "$LOCAL_REPO_DIR/"
      built_pkg_files+=("$LOCAL_REPO_DIR/$(basename "$file")")
      if [[ "$(basename "$file")" == "$pkg"-*.pkg.tar.* ]]; then
        has_requested_pkg=1
      fi
      copied_count=$((copied_count + 1))
    done < <(find "$pkg_src" -maxdepth 1 -type f -name "*.pkg.tar.*" \
      ! -name "*.sig" ! -name "*-debug-*.pkg.tar.*" | sort)

    [[ "$copied_count" -gt 0 ]] || die "AUR build for '$pkg' did not produce installable package files"
    [[ "$has_requested_pkg" -eq 1 ]] || die "AUR build for '$pkg' did not produce a '$pkg' package artifact"
  done

  rm -f "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.db" "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.db.tar.gz" \
    "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.files" "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.files.tar.gz"

  repo-add "$LOCAL_REPO_DB" "${built_pkg_files[@]}"
  log "Created local package repo at $LOCAL_REPO_DIR"
}

replace_boot_branding_strings() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  sed -i.bak \
    -e "s/Arch Linux/UmaOS/g" \
    -e "s/archlinux/umaos/g" \
    "$file"
  rm -f "$file.bak"
}

configure_boot_branding() {
  local grub_cfg="$BUILD_PROFILE/grub/grub.cfg"
  local grub_loopback="$BUILD_PROFILE/grub/loopback.cfg"
  local syslinux_splash="$BUILD_PROFILE/syslinux/splash.png"
  local syslinux_head="$BUILD_PROFILE/syslinux/archiso_head.cfg"
  local syslinux_src="$GRUB_BACKGROUND_SRC"
  local tmp_file
  local cfg

  # Brand boot menu text across GRUB, Syslinux and EFI loader entries.
  replace_boot_branding_strings "$grub_cfg"
  replace_boot_branding_strings "$grub_loopback"
  if [[ -d "$BUILD_PROFILE/syslinux" ]]; then
    while IFS= read -r cfg; do
      replace_boot_branding_strings "$cfg"
    done < <(find "$BUILD_PROFILE/syslinux" -maxdepth 1 -type f -name "*.cfg" | sort)
  fi
  if [[ -d "$BUILD_PROFILE/efiboot/loader/entries" ]]; then
    while IFS= read -r cfg; do
      replace_boot_branding_strings "$cfg"
    done < <(find "$BUILD_PROFILE/efiboot/loader/entries" -maxdepth 1 -type f -name "*.conf" | sort)
  fi

  # Apply custom GRUB background if the configured image exists.
  if [[ -f "$GRUB_BACKGROUND_SRC" ]]; then
    for cfg in "$grub_cfg" "$grub_loopback"; do
      [[ -f "$cfg" ]] || continue
      if ! grep -q "background_image /boot/syslinux/splash.png" "$cfg"; then
        tmp_file="$(mktemp)"
        awk '
          { print }
          /^timeout_style=menu$/ {
            print ""
            print "insmod png"
            print "if background_image /boot/syslinux/splash.png; then"
            print "    true"
            print "fi"
            print ""
          }
        ' "$cfg" > "$tmp_file"
        mv "$tmp_file" "$cfg"
      fi
    done

    log "Applied GRUB background: $GRUB_BACKGROUND_SRC"
  else
    log "No GRUB background override applied (missing $GRUB_BACKGROUND_SRC)."
  fi

  # Apply custom Syslinux splash for BIOS boots.
  if [[ -f "$SYSLINUX_BACKGROUND_SRC" ]]; then
    syslinux_src="$SYSLINUX_BACKGROUND_SRC"
  fi
  if [[ -f "$syslinux_src" && -f "$syslinux_splash" ]]; then
    cp -f "$syslinux_src" "$syslinux_splash"
    log "Applied Syslinux splash background: $syslinux_src"
  else
    log "No Syslinux splash override applied (missing $syslinux_src or syslinux/splash.png)."
  fi

  # Improve BIOS boot menu readability on bright backgrounds.
  if [[ -f "$syslinux_head" ]]; then
    sed -i.bak \
      -e 's|^MENU COLOR border.*|MENU COLOR border       37;40   #ffffffff #d0000000 std|' \
      -e 's|^MENU COLOR title.*|MENU COLOR title        1;37;40 #ffffffff #d0000000 std|' \
      -e 's|^MENU COLOR sel.*|MENU COLOR sel          7;37;40 #ffffffff #e0304f78 all|' \
      -e 's|^MENU COLOR unsel.*|MENU COLOR unsel        37;40   #ffffffff #b0000000 std|' \
      -e 's|^MENU COLOR help.*|MENU COLOR help         37;40   #ffffffff #c0000000 std|' \
      -e 's|^MENU COLOR timeout_msg.*|MENU COLOR timeout_msg  37;40   #ffffffff #00000000 std|' \
      -e 's|^MENU COLOR timeout .*|MENU COLOR timeout      1;37;40 #ffffffff #00000000 std|' \
      -e 's|^MENU COLOR msg07.*|MENU COLOR msg07        37;40   #ffffffff #c0000000 std|' \
      -e 's|^MENU COLOR tabmsg.*|MENU COLOR tabmsg       37;40   #ffffffff #00000000 std|' \
      "$syslinux_head"
    rm -f "$syslinux_head.bak"
    log "Applied high-contrast Syslinux menu colors."
  fi
}

if [[ ! -d "$RELENG_DIR" ]]; then
  die "releng profile not found at $RELENG_DIR. Install archiso: sudo pacman -S --needed archiso"
fi

require_cmd rsync
require_cmd sed
require_cmd mkarchiso
require_cmd pacman
require_cmd grub-mkstandalone

find_missing_required_packages
if ((${#MISSING_REQUIRED_PKGS[@]} > 0)); then
  if [[ "$ALLOW_AUR" == "1" ]]; then
    build_missing_required_from_aur
  else
    die "Missing required packages in official repos: ${MISSING_REQUIRED_PKGS[*]}. Re-run with UMAOS_ALLOW_AUR=1 to enable AUR fallback."
  fi
fi

# Start from a clean state so mkarchiso does not reuse stale run markers.
clean_dir_contents() {
  local dir="$1"
  mkdir -p "$dir"
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

clean_dir_contents "$BUILD_PROFILE"
clean_dir_contents "$WORK_DIR"
clean_dir_contents "$OUT_DIR"

rsync -a --delete "$RELENG_DIR/" "$BUILD_PROFILE/"

configure_boot_branding

if [[ -f "$ROOT_DIR/archiso/packages.x86_64" ]]; then
  cat "$ROOT_DIR/archiso/packages.x86_64" >> "$BUILD_PROFILE/packages.x86_64"
fi

if [[ -d "$ROOT_DIR/archiso/airootfs" ]]; then
  rsync -a "$ROOT_DIR/archiso/airootfs/" "$BUILD_PROFILE/airootfs/"
fi

# grml-zsh-config owns /etc/skel/.zshrc; pre-seeding it in airootfs causes
# pacman file-conflict failures during mkarchiso package installation.
rm -f "$BUILD_PROFILE/airootfs/etc/skel/.zshrc"

install_custom_cursor_themes
install_wallhaven_wallpapers

# Harden permissions for helper entrypoints in case host fs metadata gets normalized.
chmod +x "$BUILD_PROFILE/airootfs/usr/local/bin/umao-install" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/uma-update" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-installer-autostart" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-apply-theme" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-install-steam-root" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-first-login-umamusume" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-show-ascii" \
  "$BUILD_PROFILE/airootfs/etc/profile.d/umaos-welcome.sh" \
  "$BUILD_PROFILE/airootfs/home/arch/Desktop/Install Uma Musume.sh" \
  "$BUILD_PROFILE/airootfs/etc/skel/Desktop/Install Uma Musume.sh" 2>/dev/null || true

if [[ -f "$LOCAL_REPO_DB" ]]; then
  prepare_local_repo_pacman_conf
fi

sed -i.bak "s/^iso_name=.*/iso_name=\"umaos\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_label=.*/iso_label=\"$ISO_LABEL\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_publisher=.*/iso_publisher=\"UmaOS Project <https:\/\/example.com\/umaos>\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_application=.*/iso_application=\"UmaOS Live ISO\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_version=.*/iso_version=\"$DATE_TAG\"/" "$BUILD_PROFILE/profiledef.sh"
rm -f "$BUILD_PROFILE/profiledef.sh.bak"

cat >> "$BUILD_PROFILE/profiledef.sh" <<'EOF'

# Force UEFI to GRUB so UEFI path gets the same branding/theming controls.
bootmodes=('bios.syslinux'
           'uefi.grub')

# UmaOS custom permissions for executable helper entrypoints copied via custom airootfs.
file_permissions+=(
  ["/usr/local/bin/umao-install"]="0:0:755"
  ["/usr/local/bin/uma-update"]="0:0:755"
  ["/usr/local/bin/umao-installer-autostart"]="0:0:755"
  ["/usr/local/bin/umao-apply-theme"]="0:0:755"
  ["/usr/local/bin/umao-install-steam-root"]="0:0:755"
  ["/usr/local/bin/umao-first-login-umamusume"]="0:0:755"
  ["/usr/local/bin/umao-show-ascii"]="0:0:755"
  ["/etc/profile.d/umaos-welcome.sh"]="0:0:755"
  ["/home/arch/Desktop/UmaOS Installer.desktop"]="0:0:755"
  ["/home/arch/Desktop/Install Uma Musume.sh"]="0:0:755"
  ["/etc/skel/Desktop/Install Uma Musume.sh"]="0:0:755"
)
EOF

log "Building UmaOS ISO..."
mkarchiso_help="$(mkarchiso -h 2>&1 || true)"
mkarchiso_cmd=(mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR")

# Newer archiso releases require explicit build modes.
if grep -q "Build mode(s) to use" <<<"$mkarchiso_help"; then
  mkarchiso_cmd+=(-m "${MKARCHISO_MODES:-iso}")
fi

mkarchiso_cmd+=("$BUILD_PROFILE")
"${mkarchiso_cmd[@]}"

log "Build complete. Output artifacts:"
mapfile -t out_files < <(find "$OUT_DIR" -maxdepth 5 -type f 2>/dev/null | sort)
if ((${#out_files[@]} == 0)); then
  die "No output files found in $OUT_DIR. mkarchiso may have only validated options. Set MKARCHISO_MODES if needed."
else
  printf '%s\n' "${out_files[@]}"
  if [[ "${UMAOS_SKIP_BRANDING_VERIFY:-0}" != "1" ]]; then
    mapfile -t iso_files < <(printf '%s\n' "${out_files[@]}" | grep -E '\.iso$' || true)
    if ((${#iso_files[@]} > 0)); then
      log "Running branding verification checks..."
      for iso_file in "${iso_files[@]}"; do
        bash "$ROOT_DIR/scripts/verify-iso-branding.sh" "$iso_file"
      done
    else
      log "No ISO artifacts found for branding verification."
    fi
  fi
  log "Umazing!"
fi
