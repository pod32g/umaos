# Maintainer: pod32g
#
# NOTE: this file is the canonical copy. umaos/custom-pkgs/umao-dev-setup/ must
# be kept byte-identical to it — the ISO build (scripts/build-iso.sh) uses that
# copy, so any fix made only here silently never ships. CI enforces this; see
# .github/workflows/ci.yml in the umaos repo.
pkgname=umao-dev-setup
pkgver=1.0.3
pkgrel=1
pkgdesc="UmaOS development environment setup wizard"
arch=('any')
url="https://github.com/pod32g/umao-dev-setup"
license=('MIT')
# polkit provides pkexec, which both GUI install paths use to escalate.
depends=('python' 'python-pyqt6' 'qt6-declarative' 'polkit')
optdepends=('kdialog: fallback GUI when PyQt6 is unavailable'
            'qt6-tools: progress dialog updates (qdbus6) in the kdialog fallback'
            'yay: install AUR packages for the AI/editor stacks')
source=("$pkgname-$pkgver.tar.gz::https://github.com/pod32g/$pkgname/archive/refs/tags/v$pkgver.tar.gz")
# Pinned, not SKIP: this is a fixed release tag fetched over the network, so an
# unverified source lets a repo/CDN compromise or a moved tag land arbitrary
# code in the ISO. Regenerate whenever pkgver changes:
#   makepkg -g   (or: curl -sSL <url> | sha256sum)
sha256sums=('59aa138dcd8e9d6ccad621adf2142e394e2b055038839b25eb8894a2df548cd9')

package() {
    cd "$pkgname-$pkgver"

    # Main executable
    install -Dm755 umao-dev-setup "$pkgdir/usr/bin/umao-dev-setup"

    # QML files
    install -dm755 "$pkgdir/usr/share/umaos/dev-setup"
    install -Dm644 qml/*.qml "$pkgdir/usr/share/umaos/dev-setup/"
    install -Dm644 qml/qmldir "$pkgdir/usr/share/umaos/dev-setup/qmldir"

    # Icon
    install -Dm644 icon.png "$pkgdir/usr/share/umaos/dev-setup/icon.png"

    # Desktop entry
    # /usr/share/applications gives the app a menu entry and is the only copy
    # pre-existing users ever see; skel only reaches users created later.
    # Plasma treats a non-executable desktop launcher as untrusted -> 0755.
    install -Dm644 dev-setup.desktop "$pkgdir/usr/share/applications/umao-dev-setup.desktop"
    install -Dm755 dev-setup.desktop "$pkgdir/etc/skel/Desktop/Dev Setup.desktop"

    # MIT is declared in license=(); Arch requires shipping the text.
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
