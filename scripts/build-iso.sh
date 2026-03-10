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
  umao-dev-setup
  umao-cursor-switcher
)
MISSING_REQUIRED_PKGS=()
ALLOW_AUR="${UMAOS_ALLOW_AUR:-0}"
CUSTOM_PKGS_DIR="$ROOT_DIR/custom-pkgs"
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
# Cursor themes are bundled in the umao-cursor-switcher package
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


# Cursor themes are now bundled in the umao-cursor-switcher package.

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
  # Pre-resize logo to 120px so it doesn't render at native 872×1000
  # even if QML sourceSize is ignored by the renderer.
  if command -v magick >/dev/null 2>&1; then
    magick "$URA_LOGO_SRC" -resize x120 "$images_dir/ura_logo.png"
  elif command -v convert >/dev/null 2>&1; then
    convert "$URA_LOGO_SRC" -resize x120 "$images_dir/ura_logo.png"
  else
    cp -f "$URA_LOGO_SRC" "$images_dir/ura_logo.png"
    log "WARNING: ImageMagick not available — ksplash logo not resized"
  fi

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

    // Subtle center glow — dark emerald radial highlight
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.7
        height: parent.height * 0.7
        radius: width / 2
        color: "#1a3d24"
        opacity: 0.25
    }

    // Secondary glow — slight pink tint offset right
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: parent.width * 0.15
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.05
        width: parent.width * 0.4
        height: parent.height * 0.4
        radius: width / 2
        color: "#3d1a2a"
        opacity: 0.12
    }

    // URA horse logo
    Image {
        id: logo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.085
        source: "images/ura_logo.png"
        fillMode: Image.PreserveAspectFit
        smooth: true

        // Fade in on load
        opacity: 0
        Component.onCompleted: opacity = 0.92
        Behavior on opacity {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }

    // Title: "UmaOS" — light weight, wide letter-spacing
    Text {
        id: title
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: Math.max(20, parent.height * 0.026)
        text: "UmaOS"
        color: "#ffffff"
        font.pixelSize: Math.max(18, parent.height * 0.026)
        font.weight: Font.Light
        font.family: "Noto Sans"
        font.letterSpacing: font.pixelSize * 0.2

        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }

    // Accent line: green-to-pink gradient
    Rectangle {
        id: accentLine
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: title.bottom
        anchors.topMargin: parent.height * 0.014
        width: parent.height * 0.074
        height: 2
        opacity: 0.5
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#42a54b" }
            GradientStop { position: 1.0; color: "#ff91c0" }
        }
    }

    // Loading dots — light up progressively with stage
    Row {
        id: dots
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: accentLine.bottom
        anchors.topMargin: parent.height * 0.03
        spacing: Math.max(8, parent.height * 0.011)

        Repeater {
            model: 5
            Rectangle {
                width: Math.max(4, root.height * 0.0056)
                height: width
                radius: width / 2
                color: "#42a54b"
                opacity: index <= root.stage ? 0.9 : 0.25
                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
                }
            }
        }
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

  # ── Lock screen: circular avatar + UmaOS styling ──
  local lockscreen_dir="$theme_root/contents/lockscreen"
  mkdir -p "$lockscreen_dir"

  cat > "$lockscreen_dir/LockScreenUi.qml" <<'LOCKEOF'
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

Item {
    id: root

    // ── Auth state ──
    property string errorText: ""

    // Background overlay — dark green tint so wallpaper shows dimmed
    Rectangle {
        anchors.fill: parent
        color: "#cc0e1f14"
    }

    // Subtle center glow
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.7
        height: parent.height * 0.7
        radius: width / 2
        color: "#1a3d24"
        opacity: 0.18
    }

    // ── Clock (top center) ──
    Column {
        id: clockBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.08
        spacing: 4

        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            font.pixelSize: Math.max(48, root.height * 0.065)
            font.weight: Font.Light
            font.family: "Noto Sans"
            font.letterSpacing: 2
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#aaffffff"
            font.pixelSize: Math.max(14, root.height * 0.02)
            font.weight: Font.Normal
            font.family: "Noto Sans"
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                var now = new Date();
                clockText.text = Qt.formatTime(now, "hh:mm");
                dateText.text = Qt.formatDate(now, "dddd, MMMM d");
            }
        }
    }

    // ── Frosted glass card ──
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 320
        height: cardColumn.implicitHeight + 60
        radius: 16
        color: "#30ffffff"
        border.color: "#20ffffff"
        border.width: 1

        Column {
            id: cardColumn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 30
            width: parent.width - 60
            spacing: 14

            // ── Circular avatar ──
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 80; height: 80

                // User face image (circular crop)
                Rectangle {
                    id: faceClip
                    anchors.fill: parent
                    radius: 40
                    clip: true
                    color: "transparent"
                    visible: faceImage.status === Image.Ready

                    Image {
                        id: faceImage
                        anchors.fill: parent
                        source: typeof kscreenlocker_userImage !== "undefined"
                                ? kscreenlocker_userImage : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                }

                // Fallback green circle with silhouette
                Rectangle {
                    id: avatarFallback
                    anchors.fill: parent
                    radius: 40
                    color: "#42a54b"
                    visible: !faceClip.visible

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.18
                        width: parent.width * 0.34
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        opacity: 0.7
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.58
                        width: parent.width * 0.58
                        height: parent.height * 0.36
                        radius: width / 2
                        color: "#ffffff"
                        opacity: 0.7
                    }
                }

                // Green ring around avatar
                Rectangle {
                    anchors.fill: parent
                    radius: 40
                    color: "transparent"
                    border.color: "#42a54b"
                    border.width: 2
                }
            }

            // ── Username ──
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: typeof kscreenlocker_userName !== "undefined"
                      ? kscreenlocker_userName : "User"
                color: "#ffffff"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.family: "Noto Sans"
            }

            // ── Password label ──
            Text {
                text: "Password"
                color: "#aaffffff"
                font.pixelSize: 11
                font.family: "Noto Sans"
            }

            // ── Password input (dark glass) ──
            QQC2.TextField {
                id: passwordInput
                width: parent.width
                height: 42
                echoMode: TextInput.Password
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "Noto Sans"
                horizontalAlignment: TextInput.AlignLeft
                leftPadding: 14
                enabled: typeof authenticator !== "undefined" ? !authenticator.busy : true

                background: Rectangle {
                    radius: 10
                    color: passwordInput.activeFocus ? "#25ffffff" : "#20ffffff"
                    border.color: passwordInput.activeFocus ? "#42a54b" : "#30ffffff"
                    border.width: 1
                }

                Keys.onReturnPressed: startAuth()
                Keys.onEnterPressed: startAuth()
            }

            // ── Error message ──
            Text {
                id: errorLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.errorText
                color: "#ff6b6b"
                font.pixelSize: 12
                font.family: "Noto Sans"
                visible: text !== ""
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            // ── Unlock button ──
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 40
                radius: 10
                color: unlockMouse.containsMouse ? "#4db85a" : "#42a54b"

                Text {
                    anchors.centerIn: parent
                    text: "Unlock"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.family: "Noto Sans"
                }

                MouseArea {
                    id: unlockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: startAuth()
                }
            }
        }
    }

    // ── Authentication logic ──
    function startAuth() {
        if (typeof authenticator === "undefined") return;
        root.errorText = "";
        authenticator.startAuthenticating();
    }

    Connections {
        target: typeof authenticator !== "undefined" ? authenticator : null

        function onPromptForSecretChanged() {
            if (authenticator.promptForSecret) {
                authenticator.respond(passwordInput.text);
            }
        }

        function onSucceeded() {
            Qt.quit();
        }

        function onFailed() {
            root.errorText = "Authentication failed. Try again.";
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }

        function onInfoMessageChanged() {
            if (authenticator.infoMessage) {
                root.errorText = authenticator.infoMessage;
            }
        }

        function onErrorMessageChanged() {
            if (authenticator.errorMessage) {
                root.errorText = authenticator.errorMessage;
            }
        }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
    }
}
LOCKEOF

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
  #
  # Priority order:
  #   1. CJK-capable fonts (Noto Sans CJK / Noto Sans JP) — includes both
  #      Latin and Japanese glyphs for the "ウマ娘 プリティーダービー" subtitle.
  #   2. Latin-only fonts (Noto Sans, DejaVu Sans, Liberation Sans, FreeSans).
  #
  # When using a CJK font, --range flags limit the PF2 to Latin + Katakana +
  # the single kanji 娘 (U+5A18) so the file stays small.

  local font_regular="" font_bold="" font_is_cjk=0

  # ── Search for CJK-capable fonts first ──
  for candidate in \
    /usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc \
    /usr/share/fonts/noto-cjk/NotoSansJP-Regular.otf \
    /usr/share/fonts/OTF/NotoSansCJK-Regular.ttc \
    /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc \
    /usr/share/fonts/google-noto-cjk/NotoSansCJK-Regular.ttc \
    /usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc; do
    if [[ -f "$candidate" ]]; then
      font_regular="$candidate"
      font_is_cjk=1
      log "Found CJK font: $candidate (Japanese subtitle enabled)"
      break
    fi
  done

  if [[ "$font_is_cjk" -eq 1 ]]; then
    # Search for matching bold CJK font
    for candidate in \
      /usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc \
      /usr/share/fonts/noto-cjk/NotoSansJP-Bold.otf \
      /usr/share/fonts/OTF/NotoSansCJK-Bold.ttc \
      /usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc \
      /usr/share/fonts/google-noto-cjk/NotoSansCJK-Bold.ttc \
      /usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc; do
      if [[ -f "$candidate" ]]; then
        font_bold="$candidate"
        break
      fi
    done
  fi

  # ── Fall back to Latin-only fonts if no CJK found ──
  if [[ -z "$font_regular" ]]; then
    for candidate in \
      /usr/share/fonts/noto/NotoSans-Regular.ttf \
      /usr/share/fonts/noto/NotoSans[wght].ttf \
      /usr/share/fonts/TTF/NotoSans-Regular.ttf \
      /usr/share/fonts/TTF/DejaVuSans.ttf \
      /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf \
      /usr/share/fonts/TTF/LiberationSans-Regular.ttf \
      /usr/share/fonts/liberation/LiberationSans-Regular.ttf \
      /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf \
      /usr/share/fonts/gnu-free/FreeSans.ttf; do
      if [[ -f "$candidate" ]]; then
        font_regular="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$font_bold" ]]; then
    for candidate in \
      /usr/share/fonts/noto/NotoSans-Bold.ttf \
      /usr/share/fonts/TTF/NotoSans-Bold.ttf \
      /usr/share/fonts/TTF/DejaVuSans-Bold.ttf \
      /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
      /usr/share/fonts/TTF/LiberationSans-Bold.ttf \
      /usr/share/fonts/liberation/LiberationSans-Bold.ttf \
      /usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf \
      /usr/share/fonts/gnu-free/FreeSansBold.ttf; do
      if [[ -f "$candidate" ]]; then
        font_bold="$candidate"
        break
      fi
    done
  fi

  # Fall back: use regular font for bold if no bold variant found.
  [[ -z "$font_bold" && -n "$font_regular" ]] && font_bold="$font_regular"

  # Unicode ranges for CJK fonts (keeps PF2 small):
  #   Latin + Latin Extended  : 0x0020–0x024F
  #   General Punctuation     : 0x2000–0x206F
  #   Arrows                  : 0x2190–0x21FF
  #   Geometric Shapes        : 0x25A0–0x25FF
  #   Box Drawing             : 0x2500–0x257F
  #   Katakana (full block)   : 0x30A0–0x30FF
  #   CJK: 娘 (U+5A18)       : 0x5A18–0x5A18
  local cjk_ranges=(
    --range=0x0020-0x024F
    --range=0x2000-0x206F
    --range=0x2190-0x21FF
    --range=0x25A0-0x25FF
    --range=0x2500-0x257F
    --range=0x30A0-0x30FF
    --range=0x5A18-0x5A18
  )

  local fonts_generated=0
  if command -v grub-mkfont >/dev/null 2>&1; then
    local mkfont_range=()
    [[ "$font_is_cjk" -eq 1 ]] && mkfont_range=("${cjk_ranges[@]}")

    if [[ -n "$font_regular" ]]; then
      for size in 12 14 16; do
        grub-mkfont -n "UmaOS Regular" -s "$size" \
          "${mkfont_range[@]}" \
          -o "$theme_src/UmaOS_Regular_${size}.pf2" "$font_regular"
        log "Generated UmaOS Regular ${size}pt from $(basename "$font_regular")"
      done
      fonts_generated=1
    fi
    if [[ -n "$font_bold" ]]; then
      for size in 16 28; do
        grub-mkfont -n "UmaOS Bold" -s "$size" \
          "${mkfont_range[@]}" \
          -o "$theme_src/UmaOS_Bold_${size}.pf2" "$font_bold"
        log "Generated UmaOS Bold ${size}pt from $(basename "$font_bold")"
      done
    fi
  else
    log "WARNING: grub-mkfont not found; GRUB theme will use default font."
  fi

  if [[ "$fonts_generated" -eq 0 ]]; then
    log "WARNING: No TTF fonts found for GRUB theme. Install noto-fonts or ttf-dejavu."
    log "  The GRUB theme will fall back to the built-in Unifont (small text)."
    log "  For Japanese subtitle: install noto-fonts-cjk."
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

    if [[ -f "$CUSTOM_PKGS_DIR/$pkg/PKGBUILD" ]]; then
      # Use local custom PKGBUILD from custom-pkgs/ directory
      rm -rf "$pkg_src"
      mkdir -p "$pkg_src"
      cp "$CUSTOM_PKGS_DIR/$pkg/"* "$pkg_src/"
      if [[ "$EUID" -eq 0 ]]; then
        chown -R "$builder_user":"$builder_user" "$pkg_src"
      fi
      log "Using custom PKGBUILD for '$pkg' from custom-pkgs/"
    elif [[ "$EUID" -eq 0 ]]; then
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
      print "set menu_color_normal=#8ab892/#000000"
      print "set menu_color_highlight=#ffffff/#1a5a28"
      print "# Load custom theme fonts (generated by install_grub_theme)"
      print "for font in /boot/grub/themes/umaos/*.pf2; do"
      print "    if [ -f \"$font\" ]; then loadfont \"$font\"; fi"
      print "done"
      print ""
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

  # Apply Syslinux splash background for BIOS boots.
  # Prefer the GRUB theme gradient (dark emerald) for visual consistency
  # across both UEFI and BIOS boot modes.  Fall back to the dedicated
  # syslinux asset, then to the GRUB background image.
  local grub_theme_bg="$ROOT_DIR/archiso/airootfs/usr/share/grub/themes/umaos/background.png"
  if [[ -f "$grub_theme_bg" ]]; then
    syslinux_src="$grub_theme_bg"
  elif [[ -f "$SYSLINUX_BACKGROUND_SRC" ]]; then
    syslinux_src="$SYSLINUX_BACKGROUND_SRC"
  fi
  if [[ -f "$syslinux_src" && -f "$syslinux_splash" ]]; then
    cp -f "$syslinux_src" "$syslinux_splash"
    log "Applied Syslinux splash background: $syslinux_src"
  else
    log "No Syslinux splash override applied (missing $syslinux_src or syslinux/splash.png)."
  fi

  # Style the Syslinux menu for the dark emerald gradient background.
  # Colors are ARGB (#AARRGGBB).  The dark background lets us use
  # transparent item backgrounds so the gradient shows through, with a
  # green highlight for the selected entry — matching the GRUB theme.
  if [[ -f "$syslinux_head" ]]; then
    sed -i.bak \
      -e 's|^MENU TITLE.*|MENU TITLE UmaOS|' \
      -e 's|^MENU COLOR border.*|MENU COLOR border       37;40   #40ffffff #00000000 std|' \
      -e 's|^MENU COLOR title.*|MENU COLOR title        1;37;40 #ffffffff #00000000 std|' \
      -e 's|^MENU COLOR sel.*|MENU COLOR sel          7;37;40 #ffffffff #c042a54b all|' \
      -e 's|^MENU COLOR unsel.*|MENU COLOR unsel        37;40   #ff8ab892 #00000000 std|' \
      -e 's|^MENU COLOR help.*|MENU COLOR help         37;40   #ff7ab882 #00000000 std|' \
      -e 's|^MENU COLOR timeout_msg.*|MENU COLOR timeout_msg  37;40   #ff5a8a62 #00000000 std|' \
      -e 's|^MENU COLOR timeout .*|MENU COLOR timeout      1;37;40 #ff42a54b #00000000 std|' \
      -e 's|^MENU COLOR msg07.*|MENU COLOR msg07        37;40   #ff7ab882 #00000000 std|' \
      -e 's|^MENU COLOR tabmsg.*|MENU COLOR tabmsg       37;40   #ff5a8a62 #00000000 std|' \
      "$syslinux_head"
    rm -f "$syslinux_head.bak"
    log "Applied UmaOS dark-theme Syslinux menu colors."
  fi
}

if [[ ! -d "$RELENG_DIR" ]]; then
  die "releng profile not found at $RELENG_DIR. Install archiso: sudo pacman -S --needed archiso"
fi

# Refresh package database to avoid stale mirror 404s (especially in Docker)
pacman -Sy --noconfirm 2>/dev/null || true

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

# Start from a clean state so mkarchiso does not reuse stale _run_once markers.
# Stale markers cause mkarchiso to skip steps (e.g. squashfs image creation)
# even when the actual build artifacts no longer exist.
clean_dir_contents() {
  local dir="$1"
  mkdir -p "$dir"
  # Remove everything at depth 1 (includes mkarchiso marker files like base.*)
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
  # Verify the directory is truly empty
  if [[ -n "$(ls -A "$dir" 2>/dev/null)" ]]; then
    log "WARNING: Could not fully clean $dir — some files remain:"
    ls -la "$dir" >&2
  fi
}

clean_dir_contents "$BUILD_PROFILE"
clean_dir_contents "$WORK_DIR"
clean_dir_contents "$OUT_DIR"

# Double-check no stale mkarchiso markers remain in work directory
if compgen -G "$WORK_DIR/base.*" >/dev/null 2>&1 || \
   compgen -G "$WORK_DIR/iso.*" >/dev/null 2>&1; then
  log "WARNING: Stale mkarchiso markers found after cleaning. Force-removing..."
  rm -f "$WORK_DIR"/base.* "$WORK_DIR"/iso.* 2>/dev/null || true
fi

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

# Cursor themes are now installed by the umao-cursor-switcher package
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
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-ensure-proton-ge" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-refresh-lsb-release" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-show-ascii" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-welcome" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-login-sound" \
  "$BUILD_PROFILE/airootfs/usr/local/bin/umao-pacman-quote" \
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
  ["/usr/local/bin/umao-ensure-proton-ge"]="0:0:755"
  ["/usr/local/bin/umao-refresh-lsb-release"]="0:0:755"
  ["/usr/local/bin/umao-show-ascii"]="0:0:755"
  ["/usr/local/bin/umao-welcome"]="0:0:755"
  ["/usr/local/bin/umao-login-sound"]="0:0:755"
  ["/usr/local/bin/umao-pacman-quote"]="0:0:755"
  ["/etc/profile.d/umaos-welcome.sh"]="0:0:755"
  ["/usr/lib/systemd/system-sleep/rmi4-resume.sh"]="0:0:755"
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
