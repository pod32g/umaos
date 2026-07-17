# Maintainer: pod32g
#
# NOTE: this file is the canonical copy. umaos/custom-pkgs/umao-cursor-switcher/
# must be kept byte-identical to it — the ISO build (scripts/build-iso.sh) uses
# that copy, so any fix made only here silently never ships. CI enforces this;
# see .github/workflows/ci.yml in the umaos repo.
pkgname=umao-cursor-switcher
pkgver=1.0.2
pkgrel=1
pkgdesc="UmaOS cursor theme switcher with Uma Musume character cursors"
arch=('any')
url="https://github.com/pod32g/umao-cursor-switcher"
license=('MIT')
# kconfig provides kwriteconfig6 and qt6-tools provides qdbus6; apply_theme
# calls both, and without them the KDE config write and KWin reconfigure were
# silently skipped. plasma-workspace provides plasma-apply-cursortheme, the
# supported way to apply a cursor theme to the running session.
depends=('python' 'python-pyqt6' 'qt6-declarative' 'kconfig' 'qt6-tools')
optdepends=('kdialog: fallback GUI when PyQt6 is unavailable'
            'plasma-workspace: apply the cursor theme to the running session without re-login')
source=("$pkgname-$pkgver.tar.gz::https://github.com/pod32g/$pkgname/archive/refs/tags/v$pkgver.tar.gz")
# Pinned, not SKIP: this is a fixed release tag fetched over the network, so an
# unverified source lets a repo/CDN compromise or a moved tag land arbitrary
# code in the ISO. Regenerate whenever pkgver changes:
#   makepkg -g   (or: curl -sSL <url> | sha256sum)
sha256sums=('47c96f3738239a5437fb607dfeb2fc38429f83e284dcf58657a9043d25667211')

package() {
    cd "$pkgname-$pkgver"

    # Main executable
    install -Dm755 umao-cursor-switcher "$pkgdir/usr/bin/umao-cursor-switcher"

    # QML files
    install -dm755 "$pkgdir/usr/share/umaos/cursor-switcher"
    install -Dm644 qml/*.qml "$pkgdir/usr/share/umaos/cursor-switcher/"
    install -Dm644 qml/qmldir "$pkgdir/usr/share/umaos/cursor-switcher/qmldir"

    # Desktop entry.
    # /usr/share/applications is what gives the app a menu entry and is the
    # only copy pre-existing users ever see; the skel copy only reaches users
    # created after install. Plasma treats a non-executable desktop launcher as
    # untrusted, so the skel Desktop copy must be 0755, not 0644.
    install -Dm644 cursor-switcher.desktop \
        "$pkgdir/usr/share/applications/umao-cursor-switcher.desktop"
    install -Dm755 cursor-switcher.desktop "$pkgdir/etc/skel/Desktop/Cursor Switcher.desktop"

    # MIT is declared in license=(); Arch requires the text to be shipped.
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"

    # Install cursor themes from bundled archives
    local dest_icons="$pkgdir/usr/share/icons"
    mkdir -p "$dest_icons"
    for archive in cursors/*.tar.gz; do
        [ -f "$archive" ] || continue
        local extract_root
        extract_root="$(mktemp -d)"
        tar -xzf "$archive" -C "$extract_root"

        # Find the index.theme to locate the theme root
        local idx_path
        idx_path="$(find "$extract_root" -name 'index.theme' -print -quit 2>/dev/null)"
        [ -n "$idx_path" ] || { rm -rf "$extract_root"; continue; }

        local theme_root
        theme_root="$(dirname "$idx_path")"
        [ -d "$theme_root/cursors" ] || { rm -rf "$extract_root"; continue; }

        # Derive theme directory name from index.theme Name= field
        local theme_name
        theme_name="$(awk -F= '/^Name=/{print $2; exit}' "$theme_root/index.theme" | tr -d '\r')"
        local theme_dir
        theme_dir="$(printf '%s' "$theme_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
        [ -n "$theme_dir" ] || { rm -rf "$extract_root"; continue; }

        cp -a "$theme_root" "$dest_icons/$theme_dir"

        # Most archives are tarbombs, so $theme_root is the mktemp -d dir
        # itself (mode 0700) and `cp -a` preserves that — the installed theme
        # would be unreadable by every non-root user, silently breaking cursor
        # discovery. The packs also ship data files with stray exec bits.
        # Normalize: dirs 755, files 644.
        find "$dest_icons/$theme_dir" -type d -exec chmod 755 {} +
        find "$dest_icons/$theme_dir" -type f -exec chmod 644 {} +

        # Packs ship their own README/Preview alongside the theme; they have no
        # business inside /usr/share/icons/<theme>/.
        rm -f "$dest_icons/$theme_dir/README.txt" "$dest_icons/$theme_dir/Preview.png"

        rm -rf "$extract_root"
    done
}
