# Maintainer: pod32g
pkgname=umao-cursor-switcher
pkgver=1.0.0
pkgrel=1
pkgdesc="UmaOS cursor theme switcher with Uma Musume character cursors"
arch=('any')
url="https://github.com/pod32g/umao-cursor-switcher"
license=('MIT')
depends=('python' 'python-pyqt6' 'qt6-declarative')
optdepends=('kdialog: fallback GUI when PyQt6 is unavailable')
source=("$pkgname-$pkgver.tar.gz::https://github.com/pod32g/$pkgname/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$pkgname-$pkgver"

    # Main executable
    install -Dm755 umao-cursor-switcher "$pkgdir/usr/local/bin/umao-cursor-switcher"

    # QML files
    install -dm755 "$pkgdir/usr/share/umaos/cursor-switcher"
    install -Dm644 qml/*.qml "$pkgdir/usr/share/umaos/cursor-switcher/"
    install -Dm644 qml/qmldir "$pkgdir/usr/share/umaos/cursor-switcher/qmldir"

    # Desktop entry
    install -Dm644 cursor-switcher.desktop "$pkgdir/etc/skel/Desktop/Cursor Switcher.desktop"

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
        rm -rf "$extract_root"
    done
}
