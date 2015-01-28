# Maintainer: juankfree <juan77.sonic at gmail dot com>
pkgname=hosty
pkgver=1.3.1
pkgrel=1
pkgdesc="Ad blocker script"
arch=('any')
url="https://github.com/juankfree/hosty"
license=('GPL2')
depends=('sudo' 'wget' 'curl' 'gawk')
options=('!strip')
install="hosty.install"
source=('https://github.com/juankfree/hosty/raw/5564c7fa544b4484bb23913359159e070c8abd47/hosty')
md5sums=('6604fa5d83ed54ff06c5146093048404')
package() {
	install -Dm755 "${srcdir}/hosty" "${pkgdir}/usr/bin/hosty"
}
