name 'pkg-build'
maintainer 'Heavy Water'
maintainer_email 'support@hw-ops.com'
description 'Recipes for building packages'

version '0.1.9'

supports 'ubuntu'

depends 'builder'
depends 'fpm-tng'
depends 'reprepro'
depends 'apt'
depends 'ohai'
depends 'discovery', '>= 0.2.0'
