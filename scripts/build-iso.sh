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
  helium
  xorg-xkbcomp
  plasma6-wallpapers-smart-video-wallpaper-reborn
  yay
  helium-browser-bin
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
URA_LOGO_SRC="$ROOT_DIR/ura_logo.png"
DEFAULT_CURSOR_THEME="pixloen-haru-urara-v1.7"
EXPECTED_WALLHAVEN_COUNT=0

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

extract_valid_pgp_keys() {
  local pkgbuild="$1"
  [[ -f "$pkgbuild" ]] || return 0

  awk '
    BEGIN { in_keys=0 }
    {
      if ($0 ~ /^[[:space:]]*validpgpkeys[[:space:]]*=\(/) {
        in_keys=1
      }
      if (in_keys) {
        print
      }
      if (in_keys && $0 ~ /\)/) {
        in_keys=0
      }
    }
  ' "$pkgbuild" \
    | grep -Eo '[A-Fa-f0-9]{8,40}' \
    | tr '[:lower:]' '[:upper:]' \
    | sort -u || true
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
  chmod 644 "$pacman_conf"

  # Save a clean copy (without local repo) to ship in the ISO so that
  # yay / pacman work for regular users on the live and installed system.
  # mkarchiso uses the profile-level pacman.conf for installing packages,
  # but airootfs/etc/pacman.conf (if present) is what ends up in the image.
  install -d "$BUILD_PROFILE/airootfs/etc"
  grep -v "^\[$LOCAL_REPO_NAME\]" "$pacman_conf" \
    | grep -v "^SigLevel = Optional TrustAll" \
    | grep -v "^Server = file://$LOCAL_REPO_DIR" \
    > "$BUILD_PROFILE/airootfs/etc/pacman.conf"
  chmod 644 "$BUILD_PROFILE/airootfs/etc/pacman.conf"

  log "Injected local repo '$LOCAL_REPO_NAME' into build pacman.conf (clean copy in airootfs)"
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

ensure_default_cursor_theme() {
  local dest_icons="$BUILD_PROFILE/airootfs/usr/share/icons"
  local preferred="$DEFAULT_CURSOR_THEME"
  local detected_haru_theme

  if [[ -d "$dest_icons/$preferred" ]]; then
    log "Default cursor theme present: $preferred"
    return 0
  fi

  detected_haru_theme="$(
    find "$dest_icons" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; \
      | grep -Ei '^pixloen-.*haru.*urara' \
      | head -n 1 || true
  )"

  if [[ -n "$detected_haru_theme" ]]; then
    ln -sfn "$detected_haru_theme" "$dest_icons/$preferred"
    log "Created cursor alias '$preferred' -> '$detected_haru_theme'."
    return 0
  fi

  warn "Default cursor theme '$preferred' not found in $dest_icons. System may fall back to Breeze cursors."
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

    cat > "$pkg_dir/metadata.json" <<EOF
{
  "KPlugin": {
    "Id": "Wallhaven-$id",
    "Name": "Wallhaven $id",
    "Description": "Uma Musume wallpaper from Wallhaven ($id)",
    "Authors": [
      {
        "Name": "Wallhaven contributor"
      }
    ],
    "License": "Unknown"
  }
}
EOF

    imported=$((imported + 1))
  done < "$WALLHAVEN_MANIFEST"

  log "Imported $imported Wallhaven wallpaper option(s) from $WALLHAVEN_MANIFEST."
}

install_uma_ksplash_theme() {
  local theme_id="com.umaos.desktop"
  local theme_root="$BUILD_PROFILE/airootfs/usr/share/plasma/look-and-feel/$theme_id"
  local splash_dir="$theme_root/contents/splash"
  local images_dir="$splash_dir/images"

  if [[ ! -f "$URA_LOGO_SRC" ]]; then
    log "No KSplash logo source found at $URA_LOGO_SRC; skipping custom Plasma loading logo."
    return 0
  fi

  rm -rf "$theme_root"
  mkdir -p "$images_dir"
  cp -f "$URA_LOGO_SRC" "$images_dir/ura_logo.png"

  cat > "$theme_root/metadata.json" <<'EOF'
{
  "KPlugin": {
    "Id": "com.umaos.desktop",
    "Name": "UmaOS",
    "Description": "UmaOS custom startup splash",
    "Version": "1.0",
    "License": "CC-BY-NC-ND",
    "Website": "https://github.com/pod32g/umaos"
  }
}
EOF

  cat > "$splash_dir/Splash.qml" <<'EOF'
import QtQuick 2.15

Rectangle {
    id: root
    property int stage: 0
    color: "#0e1f14"

    Image {
        id: logo
        anchors.centerIn: parent
        source: "images/ura_logo.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        sourceSize.width: Math.min(parent.width * 0.32, 560)
        sourceSize.height: Math.min(parent.height * 0.32, 560)
        opacity: 0.92
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: Math.max(24, parent.height * 0.03)
        text: "UmaOS"
        color: "#e8f5ea"
        font.pixelSize: Math.max(20, parent.height * 0.034)
        font.bold: true
        opacity: 0.9
    }
}
EOF

  # ── Layout.js: defines the default panel for first-login ──
  local layouts_dir="$theme_root/contents/layouts"
  mkdir -p "$layouts_dir"

  cat > "$layouts_dir/org.kde.plasma.desktop-layout.js" <<'LAYOUTEOF'
// UmaOS default panel layout — translucent floating bottom panel
var panel = new Panel
panel.location = "bottom"
panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2)

// Restrict panel width on ultra-wide monitors
var maximumAspectRatio = 21/9;
if (panel.formFactor === "horizontal") {
    var geo = screenGeometry(panel.screen);
    var maximumWidth = Math.ceil(geo.height * maximumAspectRatio);
    if (geo.width > maximumWidth) {
        panel.alignment = "center";
        panel.minimumLength = maximumWidth;
        panel.maximumLength = maximumWidth;
    }
}

// Kickoff launcher with custom UmaOS icon
var kickoff = panel.addWidget("org.kde.plasma.kickoff")
kickoff.currentConfigGroup = ["Configuration", "General"]
kickoff.writeConfig("icon", "umaos-launcher")
kickoff.writeConfig("favoritesPortedToKAstats", true)

// Pinned application launchers
var tasks = panel.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["Configuration", "General"]
tasks.writeConfig("launchers", [
    "applications:systemsettings.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:helium-browser.desktop"
].join(","))

// Separator before system tray
panel.addWidget("org.kde.plasma.marginsseparator")

// System tray
panel.addWidget("org.kde.plasma.systemtray")

// Digital clock with date
var clock = panel.addWidget("org.kde.plasma.digitalclock")
clock.currentConfigGroup = ["Configuration", "Appearance"]
clock.writeConfig("showDate", true)
clock.writeConfig("dateFormat", "shortDate")

// Panel appearance: translucent and floating
// panelOpacity: 0=adaptive, 1=opaque, 2=translucent
panel.currentConfigGroup = ["General"]
panel.writeConfig("panelOpacity", 2)
LAYOUTEOF

  # ── Defaults: maps config keys Plasma reads when applying this global theme ──
  cat > "$theme_root/contents/defaults" <<'DEFAULTSEOF'
[kdeglobals][General]
ColorScheme=UmaSkyPink

[kdeglobals][Icons]
Theme=UmaOS-Papirus

[kdeglobals][KDE]
widgetStyle=Breeze
LookAndFeelPackage=com.umaos.desktop

[KSplash]
Theme=com.umaos.desktop

[plasmarc][Theme]
name=default

[Wallpaper]
Image=UmaOS
DEFAULTSEOF

  log "Installed custom Plasma KSplash theme using $URA_LOGO_SRC."
}

install_grub_theme() {
  local theme_name="umaos"
  local theme_src="$ROOT_DIR/archiso/airootfs/usr/share/grub/themes/$theme_name"
  local theme_txt="$theme_src/theme.txt"
  local iso_theme_dir="$BUILD_PROFILE/grub/themes/$theme_name"
  local installed_theme_dir="$BUILD_PROFILE/airootfs/usr/share/grub/themes/$theme_name"
  local gen_script="$ROOT_DIR/scripts/generate-grub-theme-assets.py"

  if [[ ! -f "$theme_txt" ]]; then
    log "No GRUB theme.txt found at $theme_txt; skipping custom GRUB theme."
    return 0
  fi

  # Generate PNG assets (background, selected-item highlight, accent line, menu bg)
  if [[ -x "$gen_script" ]] || [[ -f "$gen_script" ]]; then
    log "Generating GRUB theme PNG assets..."
    python3 "$gen_script" "$theme_src"
  else
    log "WARNING: GRUB theme asset generator not found at $gen_script."
  fi

  # Generate .pf2 fonts from system fonts for the theme.
  # Try Noto Sans first (best coverage), fall back to DejaVu Sans.
  local font_regular="" font_bold=""
  for candidate in \
    /usr/share/fonts/noto/NotoSans-Regular.ttf \
    /usr/share/fonts/noto/NotoSans[wght].ttf \
    /usr/share/fonts/TTF/NotoSans-Regular.ttf \
    /usr/share/fonts/TTF/DejaVuSans.ttf \
    /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf; do
    if [[ -f "$candidate" ]]; then
      font_regular="$candidate"
      break
    fi
  done
  for candidate in \
    /usr/share/fonts/noto/NotoSans-Bold.ttf \
    /usr/share/fonts/TTF/NotoSans-Bold.ttf \
    /usr/share/fonts/TTF/DejaVuSans-Bold.ttf \
    /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf; do
    if [[ -f "$candidate" ]]; then
      font_bold="$candidate"
      break
    fi
  done

  if command -v grub-mkfont >/dev/null 2>&1; then
    if [[ -n "$font_regular" ]]; then
      for size in 12 14 16; do
        grub-mkfont -n "UmaOS Regular" -s "$size" \
          -o "$theme_src/UmaOS_Regular_${size}.pf2" "$font_regular"
        log "Generated UmaOS Regular ${size}pt font"
      done
    fi
    if [[ -n "$font_bold" ]]; then
      for size in 16 28; do
        grub-mkfont -n "UmaOS Bold" -s "$size" \
          -o "$theme_src/UmaOS_Bold_${size}.pf2" "$font_bold"
        log "Generated UmaOS Bold ${size}pt font"
      done
    fi
  else
    log "WARNING: grub-mkfont not found; GRUB theme will use default font."
  fi

  # Copy theme to ISO's GRUB directory (for live boot)
  rm -rf "$iso_theme_dir"
  mkdir -p "$iso_theme_dir"
  cp -a "$theme_src"/* "$iso_theme_dir/"
  log "Installed GRUB theme for live ISO at $iso_theme_dir"

  # Ensure the installed-system theme dir has all assets too
  rm -rf "$installed_theme_dir"
  mkdir -p "$installed_theme_dir"
  cp -a "$theme_src"/* "$installed_theme_dir/"
  log "Installed GRUB theme for installed system at $installed_theme_dir"
}

sync_calamares_defaults() {
  local cal_root="$BUILD_PROFILE/airootfs/etc/calamares"
  local defaults_root="$cal_root/umaos-defaults"
  local module
  local -a required_modules=(
    bootloader
    displaymanager
    keyboard
    locale
    partition
    users
    unpackfs
    shellprocess-preinit
    shellprocess-postboot
  )

  [[ -d "$cal_root" ]] || die "Missing Calamares directory in profile: $cal_root"
  [[ -f "$cal_root/settings.conf" ]] || die "Missing Calamares settings.conf in profile"
  [[ -d "$cal_root/modules" ]] || die "Missing Calamares modules directory in profile"
  [[ -d "$cal_root/branding/umaos" ]] || die "Missing Calamares UmaOS branding directory in profile"

  rm -rf "$defaults_root"
  mkdir -p "$defaults_root/modules" "$defaults_root/branding"
  cp -f "$cal_root/settings.conf" "$defaults_root/settings.conf"

  for module in "${required_modules[@]}"; do
    [[ -f "$cal_root/modules/$module.conf" ]] || die "Missing required Calamares module config: $module.conf"
    cp -f "$cal_root/modules/$module.conf" "$defaults_root/modules/$module.conf"
  done

  # Copy optional module configs (non-fatal if missing)
  for module in finished; do
    if [[ -f "$cal_root/modules/$module.conf" ]]; then
      cp -f "$cal_root/modules/$module.conf" "$defaults_root/modules/$module.conf"
    fi
  done

  cp -a "$cal_root/branding/umaos" "$defaults_root/branding/"
  log "Synced Calamares defaults into /etc/calamares/umaos-defaults."
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
  local key
  local imported
  local ks
  local -a pgpkeys=()
  local -a keyservers=(
    "hkps://keyserver.ubuntu.com"
    "hkps://keys.openpgp.org"
    "hkps://pgp.surf.nl"
  )
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
      sudo -u "$builder_user" -H bash -lc "rm -rf '$pkg_src' && git clone --depth=1 'https://aur.archlinux.org/$pkg.git' '$pkg_src'"
    else
      rm -rf "$pkg_src"
      git clone --depth=1 "https://aur.archlinux.org/$pkg.git" "$pkg_src"
    fi

    # Import PKGBUILD signing keys into the builder user's keyring so
    # makepkg signature verification succeeds on clean environments.
    if [[ -f "$pkg_src/PKGBUILD" ]]; then
      mapfile -t pgpkeys < <(extract_valid_pgp_keys "$pkg_src/PKGBUILD")
      for key in "${pgpkeys[@]}"; do
        if [[ "$EUID" -eq 0 ]]; then
          if sudo -u "$builder_user" -H gpg --list-keys "$key" >/dev/null 2>&1; then
            continue
          fi
        else
          if gpg --list-keys "$key" >/dev/null 2>&1; then
            continue
          fi
        fi

        imported=0
        for ks in "${keyservers[@]}"; do
          if [[ "$EUID" -eq 0 ]]; then
            if sudo -u "$builder_user" -H gpg --keyserver "$ks" --recv-keys "$key" >/dev/null 2>&1; then
              imported=1
              break
            fi
          else
            if gpg --keyserver "$ks" --recv-keys "$key" >/dev/null 2>&1; then
              imported=1
              break
            fi
          fi
        done

        if ((imported == 0)); then
          die "Failed to import required PGP key $key for $pkg. Import manually and retry."
        fi
      done
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
      sudo -u "$builder_user" -H bash -lc "cd '$pkg_src' && makepkg -s --needed --noconfirm"
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

apply_grub_theme_block() {
  local file="$1"
  local tmp_file
  [[ -f "$file" ]] || return 0

  replace_boot_branding_strings "$file"

  # GRUB background/theming requires gfxterm, not plain console output.
  sed -i.bak \
    -e 's/^[[:space:]]*terminal_output[[:space:]]\+console[[:space:]]*$/    terminal_output gfxterm/' \
    "$file"
  rm -f "$file.bak"

  if grep -q "### UMAOS GRUB THEME START" "$file"; then
    return 0
  fi

  tmp_file="$(mktemp)"
  awk '
    { print }
    /^timeout_style=menu$/ {
      print ""
      print "### UMAOS GRUB THEME START"
      print "insmod gfxterm"
      print "insmod png"
      print "insmod all_video"
      print "set gfxmode=auto"
      print "set gfxpayload=keep"
      print "set menu_color_normal=light-green/black"
      print "set menu_color_highlight=white/green"
      print "# Use full GRUB theme if available, else fall back to background image"
      print "if [ -d /boot/grub/themes/umaos ]; then"
      print "    set theme=/boot/grub/themes/umaos/theme.txt"
      print "    export theme"
      print "elif [ -f /boot/syslinux/splash.png ]; then"
      print "    background_image /boot/syslinux/splash.png"
      print "fi"
      print "### UMAOS GRUB THEME END"
      print ""
    }
  ' "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
}

configure_boot_branding() {
  local syslinux_splash="$BUILD_PROFILE/syslinux/splash.png"
  local syslinux_head="$BUILD_PROFILE/syslinux/archiso_head.cfg"
  local syslinux_src="$GRUB_BACKGROUND_SRC"
  local cfg

  # Brand boot menu text across GRUB, Syslinux and EFI loader entries.
  if [[ -d "$BUILD_PROFILE/grub" ]]; then
    while IFS= read -r cfg; do
      apply_grub_theme_block "$cfg"
    done < <(find "$BUILD_PROFILE/grub" -type f -name "*.cfg" | sort)
  fi
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

  # Log whether the GRUB background source image is available.
  # Actual injection into grub.cfg happens in apply_grub_theme_block above.
  if [[ -f "$GRUB_BACKGROUND_SRC" ]]; then
    log "GRUB background source found: $GRUB_BACKGROUND_SRC"
  else
    log "No GRUB background override available (missing $GRUB_BACKGROUND_SRC)."
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
      -e 's|^MENU COLOR sel.*|MENU COLOR sel          7;37;40 #ffffffff #e02a7a35 all|' \
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

sync_calamares_defaults
if [[ -x "$ROOT_DIR/scripts/verify-calamares-profile.sh" ]]; then
  bash "$ROOT_DIR/scripts/verify-calamares-profile.sh" "$BUILD_PROFILE/airootfs"
fi

install_custom_cursor_themes
ensure_default_cursor_theme
install_wallhaven_wallpapers
install_uma_ksplash_theme
install_grub_theme
if [[ "$INCLUDE_WALLHAVEN" == "1" && -f "$WALLHAVEN_MANIFEST" ]]; then
  EXPECTED_WALLHAVEN_COUNT="$(tail -n +2 "$WALLHAVEN_MANIFEST" | wc -l | tr -d '[:space:]')"
fi
if [[ -x "$ROOT_DIR/scripts/verify-customization-profile.sh" ]]; then
  bash "$ROOT_DIR/scripts/verify-customization-profile.sh" \
    "$BUILD_PROFILE/airootfs" \
    "$BUILD_PROFILE/packages.x86_64" \
    "${EXPECTED_WALLHAVEN_COUNT:-0}"
fi

# Harden permissions for helper entrypoints in case host fs metadata gets normalized.
chmod +x "$BUILD_PROFILE/airootfs/usr/local/bin/umao-install" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/uma-update" \
  "$BUILD_PROFILE/airootfs/root/customize_airootfs.sh" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-sync-calamares-config" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-prepare-calamares" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-fix-initcpio-preset" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-fix-boot-root-cmdline" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-finalize-installed-customization" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-apply-grub-branding" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-driver-setup" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-audio-doctor" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-installer-autostart" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-apply-theme" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-install-steam-root" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-first-login-umamusume" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-refresh-lsb-release" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-show-ascii" \
  "$BUILD_PROFILE/airootfs/etc/profile.d/umaos-welcome.sh" \
  "$BUILD_PROFILE/airootfs/home/arch/Desktop/Install Uma Musume.sh" \
  "$BUILD_PROFILE/airootfs/etc/skel/Desktop/Install Uma Musume.sh" \
  "$BUILD_PROFILE/airootfs/home/arch/Desktop/UmaOS Update.desktop" \
  "$BUILD_PROFILE/airootfs/home/arch/Desktop/Driver Setup.desktop" \
  "$BUILD_PROFILE/airootfs/home/arch/Desktop/Audio Doctor.desktop" \
  "$BUILD_PROFILE/airootfs/etc/skel/Desktop/UmaOS Update.desktop" \
  "$BUILD_PROFILE/airootfs/etc/skel/Desktop/Driver Setup.desktop" \
  "$BUILD_PROFILE/airootfs/etc/skel/Desktop/Audio Doctor.desktop"

if [[ -f "$LOCAL_REPO_DB" ]]; then
  prepare_local_repo_pacman_conf
fi

sed -i.bak "s/^iso_name=.*/iso_name=\"umaos\"/" "$BUILD_PROFILE/profiledef.sh"
sed -i.bak "s/^iso_label=.*/iso_label=\"$ISO_LABEL\"/" "$BUILD_PROFILE/profiledef.sh"
if grep -q '^install_dir=' "$BUILD_PROFILE/profiledef.sh"; then
  sed -i.bak "s|^install_dir=.*|install_dir=\"arch\"|" "$BUILD_PROFILE/profiledef.sh"
else
  echo 'install_dir="arch"' >> "$BUILD_PROFILE/profiledef.sh"
fi
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
  ["/usr/local/bin/umao-sync-calamares-config"]="0:0:755"
  ["/usr/local/bin/umao-prepare-calamares"]="0:0:755"
  ["/usr/local/bin/umao-fix-initcpio-preset"]="0:0:755"
  ["/usr/local/bin/umao-fix-boot-root-cmdline"]="0:0:755"
  ["/usr/local/bin/umao-finalize-installed-customization"]="0:0:755"
  ["/usr/local/bin/umao-apply-grub-branding"]="0:0:755"
  ["/usr/local/bin/umao-driver-setup"]="0:0:755"
  ["/usr/local/bin/umao-audio-doctor"]="0:0:755"
  ["/usr/local/bin/umao-installer-autostart"]="0:0:755"
  ["/usr/local/bin/umao-apply-theme"]="0:0:755"
  ["/usr/local/bin/umao-install-steam-root"]="0:0:755"
  ["/usr/local/bin/umao-first-login-umamusume"]="0:0:755"
  ["/usr/local/bin/umao-refresh-lsb-release"]="0:0:755"
  ["/usr/local/bin/umao-show-ascii"]="0:0:755"
  ["/etc/profile.d/umaos-welcome.sh"]="0:0:755"
  ["/home/arch/Desktop/Install Uma Musume.sh"]="1000:1000:755"
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
