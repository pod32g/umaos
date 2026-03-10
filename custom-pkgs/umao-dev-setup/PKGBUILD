# Maintainer: pod32g
pkgname=umao-dev-setup
pkgver=1.0.0
pkgrel=1
pkgdesc="UmaOS development environment setup wizard"
arch=('any')
url="https://github.com/pod32g/umao-dev-setup"
license=('MIT')
depends=('python' 'python-pyqt6' 'qt6-declarative')
optdepends=('kdialog: fallback GUI when PyQt6 is unavailable')
source=("$pkgname-$pkgver.tar.gz::https://github.com/pod32g/$pkgname/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$pkgname-$pkgver"

    # Main executable
    install -Dm755 umao-dev-setup "$pkgdir/usr/local/bin/umao-dev-setup"

    # QML files
    install -dm755 "$pkgdir/usr/share/umaos/dev-setup"
    install -Dm644 qml/*.qml "$pkgdir/usr/share/umaos/dev-setup/"
    install -Dm644 qml/qmldir "$pkgdir/usr/share/umaos/dev-setup/qmldir"

    # Icon
    install -Dm644 icon.png "$pkgdir/usr/share/umaos/dev-setup/icon.png"

    # Desktop entry
    install -Dm644 dev-setup.desktop "$pkgdir/etc/skel/Desktop/Dev Setup.desktop"
}
