#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIROOTFS="${1:-$ROOT_DIR/archiso/airootfs}"

if [[ ! -d "$AIROOTFS" ]]; then
  echo "[umaos-parity-audit] ERROR: missing airootfs path: $AIROOTFS" >&2
  exit 2
fi

pass_count=0
warn_count=0
fail_count=0

pass() {
  echo "[umaos-parity-audit] PASS: $*"
  pass_count=$((pass_count + 1))
}

warn() {
  echo "[umaos-parity-audit] WARN: $*" >&2
  warn_count=$((warn_count + 1))
}

fail() {
  echo "[umaos-parity-audit] FAIL: $*" >&2
  fail_count=$((fail_count + 1))
}

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "Found $(realpath --relative-to="$ROOT_DIR" "$f" 2>/dev/null || echo "$f")"
  else
    fail "Missing file: $f"
  fi
}

check_contains() {
  local f="$1"
  local pat="$2"
  local msg="$3"
  if [[ -f "$f" ]] && grep -Eq "$pat" "$f"; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

check_any_contains() {
  local msg="$1"
  local pat="$2"
  shift 2
  local f
  for f in "$@"; do
    if [[ -f "$f" ]] && grep -Eq "$pat" "$f"; then
      pass "$msg"
      return 0
    fi
  done
  fail "$msg"
}

sddm_theme_live="$AIROOTFS/etc/sddm.conf.d/umaos-theme.conf"
finalizer="$AIROOTFS/usr/local/bin/umao-finalize-installed-customization"
apply_theme="$AIROOTFS/usr/local/bin/umao-apply-theme"
postboot="$AIROOTFS/etc/calamares/modules/shellprocess-postboot.conf"
preinit="$AIROOTFS/etc/calamares/modules/shellprocess-preinit.conf"
settings="$AIROOTFS/etc/calamares/settings.conf"
bootloader="$AIROOTFS/etc/calamares/modules/bootloader.conf"
users_conf="$AIROOTFS/etc/calamares/modules/users.conf"
users_defaults="$AIROOTFS/etc/calamares/umaos-defaults/modules/users.conf"
lsb_hook="$AIROOTFS/etc/pacman.d/hooks/96-umao-lsb-release.hook"
umazing_hook="$AIROOTFS/etc/pacman.d/hooks/95-umao-umazing.hook"
welcome_sh="$AIROOTFS/etc/profile.d/umaos-welcome.sh"
motd="$AIROOTFS/etc/motd"

# Base artifact presence
require_file "$sddm_theme_live"
require_file "$finalizer"
require_file "$apply_theme"
require_file "$AIROOTFS/usr/local/bin/umao-debug"
require_file "$AIROOTFS/usr/local/bin/umao-debug-upload"
require_file "$AIROOTFS/usr/local/bin/umao-ensure-proton-ge"
require_file "$AIROOTFS/usr/local/bin/neofetch"
require_file "$postboot"
require_file "$preinit"
require_file "$settings"
require_file "$bootloader"
require_file "$users_conf"
require_file "$users_defaults"
require_file "$lsb_hook"
require_file "$umazing_hook"
require_file "$welcome_sh"
require_file "$motd"
require_file "$AIROOTFS/usr/share/umaos/neofetch.txt"

# SDDM parity
check_contains "$sddm_theme_live" '^Current=umaos-race$' "Live default SDDM theme is umaos-race"
check_contains "$AIROOTFS/etc/sddm.conf.d/umaos-live.conf" '^Session=plasmax11\.desktop$' "Live autologin session defaults to Plasma X11"
check_contains "$finalizer" 'sddm_theme="umaos-race"' "Installed default SDDM theme target is umaos-race"
check_contains "$finalizer" 'sanitize_sddm_configuration' "Installed finalizer sanitizes Calamares-generated SDDM config"
check_contains "$finalizer" 'Session=plasma\.desktop' "Installed finalizer rewrites invalid SDDM plasma session aliases"
check_contains "$finalizer" 'rm -f /etc/sddm\.conf\.d/umaos-live\.conf' "Installed system removes live-only SDDM autologin"

# KDE colors/icons parity
check_contains "$AIROOTFS/etc/skel/.config/kdeglobals" '^ColorScheme=UmaSkyPink$' "Live user default color scheme is UmaSkyPink"
check_contains "$AIROOTFS/etc/skel/.config/kdeglobals" '^Theme=UmaOS-Papirus$' "Live user default icon theme is UmaOS-Papirus"
check_contains "$finalizer" 'ColorScheme=UmaSkyPink' "Installed default color scheme is UmaSkyPink"
check_contains "$finalizer" 'Theme=UmaOS-Papirus' "Installed default icon theme is UmaOS-Papirus"
check_contains "$AIROOTFS/usr/share/konsole/UmaOS-GoldShip.colorscheme" 'Wallpaper=/usr/share/umaos/themes/konsole/goldship\.webp' "Konsole color scheme uses Gold Ship wallpaper"
check_contains "$AIROOTFS/usr/share/konsole/UmaOS.profile" '^ColorScheme=UmaOS-GoldShip$' "Konsole default profile uses UmaOS-GoldShip"
check_contains "$AIROOTFS/etc/xdg/konsolerc" '^DefaultProfile=UmaOS\.profile$' "System-wide Konsole default profile is UmaOS.profile"
check_contains "$AIROOTFS/etc/skel/.config/konsolerc" '^DefaultProfile=UmaOS\.profile$' "Installed-user skeleton Konsole default profile is UmaOS.profile"
check_contains "$AIROOTFS/home/arch/.config/konsolerc" '^DefaultProfile=UmaOS\.profile$' "Live-user Konsole default profile is UmaOS.profile"
check_contains "$finalizer" '/etc/skel/\.config/konsolerc' "Installed user finalizer syncs Konsole config from skeleton"
check_contains "$AIROOTFS/etc/skel/.config/mimeapps.list" '^x-scheme-handler/http=helium\.desktop$' "Live user default HTTP handler is Helium"
check_contains "$AIROOTFS/etc/skel/.config/mimeapps.list" '^x-scheme-handler/https=helium\.desktop$' "Live user default HTTPS handler is Helium"
check_contains "$AIROOTFS/home/arch/.config/mimeapps.list" '^x-scheme-handler/http=helium\.desktop$' "Live session HTTP handler is Helium"
check_contains "$finalizer" '/etc/xdg/mimeapps\.list' "Installed system default MIME mapping is written"
check_contains "$finalizer" 'helium\.desktop' "Installed system/browser defaults reference Helium desktop entry"

# Cursor parity
check_contains "$AIROOTFS/etc/skel/.config/kcminputrc" '^cursorTheme=pixloen-haru-urara-v1\.7$' "Live user default cursor is Haru Urara"
check_contains "$sddm_theme_live" '^CursorTheme=pixloen-haru-urara-v1\.7$' "Live SDDM cursor is Haru Urara"
check_contains "$finalizer" 'resolve_cursor_theme' "Installed flow resolves cursor theme with fallback"
check_contains "$finalizer" 'cursorTheme=__CURSOR_THEME__' "Installed user cursor config gets propagated"
check_any_contains "Cursor default alias strategy present" 'DEFAULT_CURSOR_THEME|ensure_default_cursor_theme' "$ROOT_DIR/scripts/build-iso.sh"

# Wallpaper + first login apply parity
require_file "$AIROOTFS/usr/share/wallpapers/UmaOS/metadata.desktop"
require_file "$AIROOTFS/usr/share/wallpapers/UmaOS/metadata.json"
require_file "$AIROOTFS/usr/share/wallpapers/UmaBoot/metadata.json"
require_file "$AIROOTFS/usr/share/wallpapers/UmaOS/contents/images/1920x1080.jpg"
require_file "$AIROOTFS/usr/share/wallpapers/UmaOS/contents/videos/qloo.mp4"
require_file "$AIROOTFS/usr/share/umaos/themes/konsole/goldship.webp"
check_contains "$AIROOTFS/etc/skel/.config/autostart/umaos-first-login.desktop" 'Exec=/usr/local/bin/umao-apply-theme --once' "Installed user autostart reapplies theme once"
check_contains "$apply_theme" 'wallpaper_video="/usr/share/wallpapers/UmaOS/contents/videos/qloo\.mp4"' "Theme apply script uses qloo.mp4 video target"
check_contains "$apply_theme" 'video-wallpaper\.disabled' "Theme apply script persists video crash disable marker"
check_contains "$apply_theme" 'video-wallpaper\.failcount' "Theme apply script tracks video failure count before disabling"
check_contains "$apply_theme" 'plasma-apply-wallpaperimage' "Theme apply script has static wallpaper fallback"

# KSplash parity (generated during build)
check_contains "$AIROOTFS/etc/skel/.config/ksplashrc" '^Theme=com\.umaos\.desktop$' "Live/installed user KSplash default references com.umaos.desktop"
check_contains "$ROOT_DIR/scripts/build-iso.sh" 'install_uma_ksplash_theme' "Build flow injects custom KSplash theme assets"

# Boot parity
check_contains "$bootloader" '^efiBootLoader:[[:space:]]*"grub"$' "Installed default UEFI bootloader is GRUB"
check_contains "$postboot" 'umao-apply-grub-branding' "Installed postboot stage applies GRUB branding"
check_contains "$AIROOTFS/usr/local/bin/umao-apply-grub-branding" 'set_grub_var GRUB_BACKGROUND' "Installed GRUB branding updates /etc/default/grub directly"
check_contains "$AIROOTFS/usr/local/bin/umao-apply-grub-branding" 'GRUB_THEME' "Installed GRUB branding sets custom theme"
check_contains "$ROOT_DIR/scripts/build-iso.sh" 'install_grub_theme' "Live ISO build installs custom GRUB theme"
check_contains "$finalizer" 'ensure_graphical_boot' "Installed finalizer enforces graphical target + sddm symlinks"
check_contains "$finalizer" 'DisplayServer=x11' "Installed finalizer pins SDDM display server to X11"
check_contains "$users_conf" '^sudoersConfigureWithGroup:[[:space:]]*true$' "Calamares users module enables wheel sudoers policy"
check_contains "$users_defaults" '^sudoersConfigureWithGroup:[[:space:]]*true$' "Synced Calamares defaults keep wheel sudoers policy enabled"
check_contains "$finalizer" '/etc/sudoers\.d/10-umaos-wheel' "Installed finalizer writes wheel sudoers drop-in"
check_contains "$finalizer" '%wheel ALL=\(ALL:ALL\) ALL' "Installed finalizer grants wheel sudo privileges"
check_contains "$finalizer" 'usermod -aG wheel' "Installed finalizer ensures created users are in wheel"
check_contains "$ROOT_DIR/scripts/build-iso.sh" 'configure_boot_branding' "Live ISO build applies boot branding"

# LSB/OS branding parity
check_contains "$AIROOTFS/etc/os-release" '^NAME="UmaOS"$' "Live os-release is branded UmaOS"
check_contains "$AIROOTFS/usr/local/bin/neofetch" '/usr/share/umaos/neofetch\.txt' "neofetch wrapper points to UmaOS neofetch ASCII asset"
check_contains "$AIROOTFS/usr/local/bin/neofetch" 'source \"\$ascii_file\"' "neofetch wrapper forwards custom ASCII source to neofetch"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'chmod 0644 "\$conf"' "Steam helper restores pacman.conf readable permissions for non-root tooling"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'PROTONUP_QT_APP_ID="net\.davidotek\.pupgui2"' "Steam helper targets ProtonUp-Qt Flatpak app ID"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'flatpak install --system -y' "Steam helper installs ProtonUp-Qt from Flathub"
check_contains "$AIROOTFS/usr/local/bin/umao-ensure-proton-ge" 'GE-Proton' "Proton GE helper checks GE-Proton install state"
check_contains "$AIROOTFS/usr/local/bin/umao-ensure-proton-ge" 'flatpak run "\$PROTONUP_QT_APP_ID"' "Proton GE helper launches ProtonUp-Qt"
check_contains "$finalizer" 'umao-refresh-lsb-release' "Installed post-install refreshes /etc/lsb-release branding"
check_contains "$lsb_hook" 'umao-refresh-lsb-release' "Package hook keeps lsb-release branding persistent"

# Umazing parity
check_contains "$umazing_hook" '^Exec = /usr/bin/echo Umazing!$' "Pacman post-transaction celebration is enabled"
check_contains "$AIROOTFS/etc/profile.d/umao-umazing.sh" 'Umazing!' "Interactive shell celebration hook is present"

# Game installer parity
check_contains "$AIROOTFS/home/arch/Desktop/Install Uma Musume.sh" 'APP_ID=\"3224770\"' "Live desktop game installer points to expected Steam app"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'lib32-vulkan-icd-loader' "Steam helper installs 32-bit Vulkan loader runtime"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'lib32-mesa' "Steam helper installs 32-bit Mesa runtime"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'lib32-libxrandr' "Steam helper installs 32-bit Xrandr runtime"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'lib32-libxinerama' "Steam helper installs 32-bit Xinerama runtime"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'lib32-libxcursor' "Steam helper installs 32-bit Xcursor runtime"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'lib32-openal' "Steam helper installs 32-bit OpenAL runtime"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'lib32-alsa-plugins' "Steam helper installs 32-bit ALSA plugin runtime"
check_contains "$AIROOTFS/usr/local/bin/umao-install-steam-root" 'lib32-gnutls' "Steam helper installs 32-bit GnuTLS runtime"
check_contains "$AIROOTFS/home/arch/Desktop/Install Uma Musume.sh" 'umao-ensure-proton-ge' "Live desktop game installer enforces Proton GE setup"
check_contains "$AIROOTFS/etc/skel/Desktop/Install Uma Musume.sh" 'umao-ensure-proton-ge' "Installed-user game launcher enforces Proton GE setup"
check_contains "$AIROOTFS/usr/local/bin/umao-first-login-umamusume" 'ensure_proton_ge' "First-login game bootstrap enforces Proton GE setup"
check_contains "$finalizer" 'Install Uma Musume\.sh' "Installed user desktop gets game installer launcher"
check_contains "$AIROOTFS/etc/skel/.config/autostart/umao-umamusume-first-login.desktop" 'umao-first-login-umamusume' "Installed user autostart includes Steam/game bootstrap"

# KDE Panel layout and icon parity
require_file "$AIROOTFS/usr/share/icons/hicolor/scalable/apps/umaos-launcher.svg"
require_file "$AIROOTFS/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js"
check_contains "$AIROOTFS/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js" 'umaos-launcher' "Shell layout.js sets Kickoff icon to umaos-launcher"
check_contains "$AIROOTFS/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js" 'panelOpacity.*2' "Shell layout.js sets panel opacity to translucent"
check_contains "$AIROOTFS/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js" 'helium\.desktop' "Shell layout.js pins Helium browser in taskbar"
check_contains "$AIROOTFS/usr/local/bin/umao-apply-theme" 'apply_panel_properties_dbus' "Theme script applies panel properties via DBus"
check_contains "$AIROOTFS/usr/local/bin/umao-apply-theme" 'floating=1' "Theme script sets panel floating in plasmashellrc"
check_contains "$AIROOTFS/root/customize_airootfs.sh" 'chown -R arch:arch /home/arch' "Live user home ownership is fixed in customize_airootfs"

# Live-only behavior isolation checks
check_contains "$welcome_sh" '/run/archiso' "Welcome message distinguishes live vs installed sessions"
check_contains "$finalizer" 'write_installed_motd' "Installed flow rewrites live MOTD to installed quickstart"
check_contains "$AIROOTFS/usr/local/bin/umao-install" 'set-x11-keymap us pc105' "Installer launcher normalizes invalid keyboard layouts before Calamares"

if ((fail_count > 0)); then
  echo "[umaos-parity-audit] FAILED: $fail_count failed, $warn_count warning(s), $pass_count passed." >&2
  exit 1
fi

echo "[umaos-parity-audit] OK: $pass_count passed, $warn_count warning(s), $fail_count failed."
