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
}
