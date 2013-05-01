#!/usr/bin/env - LC_ALL=C SHELL=/bin/bash bash -x

readonly srcroot="$(cd "$(dirname "$0")"; pwd)"
readonly build_version=$(date +%Y%m%d)
readonly domain=com.github.mattintosh4

readonly workroot=/tmp/9C727687-28A1-47CE-9C4A-97128FADE79A
readonly destroot=/tmp/${domain}
readonly wine_destdir=${destroot}/NXWine.app/Contents/Resources
readonly deps_destdir=${destroot}/NXWine.app/Contents/SharedSupport

readonly bootstrap_tar=${srcroot}/bootstrap.tar.bz2
readonly deps_tar=${srcroot}/deps.tar.bz2
readonly wine_tar=${srcroot}/wine.tar.bz2

test -x /usr/local/bin/ccache && readonly ccache=$_ || exit
test -x /usr/local/bin/clang  && readonly clang=$_  || exit
test -x /usr/local/bin/uconv  && readonly uconv=$_  || exit
test -x /usr/local/bin/make   && export MAKE=$_     || :
test -x /usr/local/bin/gdb    && export GDB=$_      || :

### Git and Python
test -x /usr/local/git/bin/git  && readonly git_dir=$(dirname $_) || exit
test -x /Library/Frameworks/Python.framework/Versions/2.7/bin/python2.7 && readonly python_dir=$(dirname $_) || exit

### Xcode
readonly arch=i386
readonly osx_version=$(sw_vers -productVersion | cut -d. -f-2) &&
readonly kernel_version=$(uname -r | cut -d. -f1) &&
readonly sdkroot=$(xcodebuild -version -sdk macosx${osx_version} | sed -n '/^Path/{;s/^Path: //;p;}') &&
test -d ${sdkroot} || exit

PATH=/usr/bin:/bin:/usr/sbin:/sbin
PATH=${git_dir}:${python_dir}:$PATH
PATH=${deps_destdir}/bin:${deps_destdir}/sbin:$PATH
export PATH
export CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)" || exit
export CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)" || exit
export CFLAGS="-m32 -pipe -O3 -march=core2 -mtune=core2 -mmacosx-version-min=${osx_version}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-isysroot ${sdkroot} -I${deps_destdir}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${deps_destdir}/lib"

configure_args="\
--prefix=${deps_destdir} \
--build=${arch}-apple-darwin${kernel_version} \
--enable-shared \
--disable-maintainer-mode \
--disable-dependency-tracking"
make_args="-j $(($(sysctl -n hw.ncpu) + 2))"

# -------------------------------------- begin utilities functions

function DocCopy_ {
  test -n "$1" || exit
  local d=${deps_destdir}/share/doc/$1
  install -d ${d} &&
  find -E ${workroot}/$1 -depth 1 -type f -regex '.*/(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING(.LIB)?|LICENSE|NEWS|README|RELEASE|TODO|VERSION)' | while read
  do
    cp "${REPLY}" ${d}
  done || exit
} # end DocCopy_

function Compress_ {
  test -n "$1" &&
  # !!! to compress with absolute path
  tar -cP ${destroot} | bzip2 > $1 || exit
} # end Compress_

function Extract_ {
  test -n "$1" &&
  # !!! to extract with absolute path
  tar -xvPf $1 || exit
} # end Extract_

# -------------------------------------- begin build processing functions

function BuildDeps_ {
  test -n "$1" &&
  test -f ${srcroot}/source/$1 &&
  local f=$_ &&
  local n=$(basename ${f} | sed -E 's#\.(zip|tbz2?|tgz|tar\..*)$##') &&
  shift || exit
  
  cd ${workroot} &&
  case ${f} in
    *.xz)
      xzcat ${f} | tar -x -
    ;;
    *)
      tar -xf ${f}
    ;;
  esac &&
  cd ${n} &&
  ./configure ${configure_args} "$@" &&
  make ${make_args} &&
  make install || exit
} # end BuildDeps_

function BuildDevel_ {
  test -n "$1" || exit
  
  cd ${workroot} &&
  ditto ${srcroot}/source/$1 $1 &&
  cd $1
  
  case $1 in
    libffi)
      git checkout -f master &&
      sh configure ${configure_args}
    ;;
    glib)
      git checkout -f 2.36.1 &&
      sh autogen.sh ${configure_args} --disable-gtk-doc
    ;;
    freetype)
      git checkout -f master &&
      sh autogen.sh &&
      sh configure ${configure_args}
    ;;
    libpng)
      git checkout -f libpng16 &&
      autoreconf -i &&
      sh configure ${configure_args}
    ;;
  esac &&
  make ${make_args} &&
  make install &&
  DocCopy_ $1 || exit
} # end BuildDevel_

function BuildBootstrap_ {
  ### readline is required from unixODBC
  BuildDeps_ readline-6.2.tar.gz --with-curses && DocCopy_ readline-6.2
  BuildDeps_ m4-1.4.16.tar.bz2 --program-prefix=g && (
    cd ${deps_destdir}/bin &&
    ln -sf {g,}m4 && ./$_ --version >/dev/null
  ) || exit
  BuildDeps_ autoconf-2.69.tar.gz
  BuildDeps_ automake-1.13.1.tar.gz
  BuildDeps_ libtool-2.4.2.tar.gz --program-prefix=g && (
    cd ${deps_destdir}/bin &&
    ln -sf {g,}libtool    && ./$_ --version >/dev/null &&
    ln -sf {g,}libtoolize && ./$_ --version >/dev/null
  ) || exit
  BuildDeps_ pkg-config-0.28.tar.gz \
    --disable-debug \
    --disable-host-tool \
    --with-internal-glib \
    --with-pc-path=${deps_destdir}/lib/pkgconfig:${deps_destdir}/share/pkgconfig:/usr/lib/pkgconfig
  BuildDeps_ gettext-0.18.2.tar.gz
  BuildDeps_ xz-5.0.4.tar.bz2
} # end Bootstrap_

function BuildStage1_ {
  BuildDeps_ libusb-1.0.9.tar.bz2
  BuildDeps_ libusb-compat-0.1.4.tar.bz2
  # valgrind add '-arch' flag, i686-apple-darwin10-gcc-4.2.1 will not work
  BuildDeps_ valgrind-3.8.1.tar.bz2 --enable-only32bit --without-mpicc CC=$(xcrun -find gcc-4.2) CXX=$(xcrun -find g++-4.2)
  
  cd ${workroot} &&
  tar -xf ${srcroot}/source/gmp-5.1.1.tar.bz2 && (
    cd gmp-5.1.1 &&
    sh configure ${configure_args} ABI=32 --enable-cxx &&
    make ${make_args} &&
    make check &&
    make install
  ) || exit
  BuildDeps_ libtasn1-3.3.tar.gz # libtasn1 required valgrind
  BuildDeps_ nettle-2.7.tar.gz
  BuildDeps_ gnutls-3.1.8.tar.xz \
    --with-libnettle-prefix=${deps_destdir} \
    LIBTASN1_CFLAGS="$(pkg-config --cflags libtasn1)" \
    LIBTASN1_LIBS="$(pkg-config --libs libtasn1)"
} # end BuildStage1_

function BuildStage2_ {
  BuildDevel_ libffi
  BuildDevel_ glib
  BuildDevel_ freetype && test -f ${deps_destdir}/lib/libfreetype.6.dylib || { echo "$_ is missing."; exit 1; }
} # end BuildStage2_

function BuildStage3_ {
  ### orc required valgrind; to build with gcc failed
  BuildDeps_ orc-0.4.17.tar.gz \
    CC="${ccache} ${clang}" \
    CXX="${ccache} ${clang}++" \
    CFLAGS="-arch ${arch} ${CFLAGS}" \
    CXXFLAGS="-arch ${arch} ${CFLAGS}"

  BuildDeps_ unixODBC-2.3.1.tar.gz && DocCopy_ unixODBC-2.3.1
  BuildDevel_ libpng
  ### nasm is required from libjpeg-turbo
  BuildDeps_ nasm-2.10.07.tar.xz && DocCopy_ nasm-2.10.07
  BuildDeps_ libjpeg-turbo-1.2.1.tar.gz --with-jpeg8 && {
    install -d ${deps_destdir}/share/doc/libjpeg-turbo-1.2.1
    mv ${deps_destdir}/share/doc/{example.c,libjpeg.txt,README,README-turbo.txt,structure.txt,usage.txt,wizard.txt} $_
  }
  BuildDeps_ tiff-4.0.3.tar.gz
  BuildDeps_ jasper-1.900.1.zip --disable-opengl --without-x
  BuildDeps_ libicns-0.8.1.tar.gz
} # end BuildStage3_

function BuildStage4_ {
  BuildDeps_ libogg-1.3.0.tar.gz
  BuildDeps_ libvorbis-1.3.3.tar.gz
  BuildDeps_ flac-1.2.1.tar.gz --disable-asm-optimizations --disable-xmms-plugin
  BuildDeps_ SDL-1.2.15.tar.gz --without-x && DocCopy_ SDL-1.2.15
  BuildDeps_ SDL_sound-1.0.3.tar.gz        && DocCopy_ SDL_sound-1.0.3
  ### libtheora required SDL
  BuildDeps_ libtheora-1.1.1.tar.bz2 \
    --disable-oggtest \
    --disable-vorbistest \
    --disable-examples \
    --disable-asm
} # end BuildStage4_

function BuildStage5_ {
  ### cabextract
  cd ${workroot} &&
  tar -xf ${srcroot}/source/cabextract-1.4.tar.gz && (
    cd cabextract-1.4 &&
    sh configure ${configure_args/${deps_destdir}/${wine_destdir}} &&
    make ${make_args} &&
    make install &&
    install -d ${wine_destdir}/share/doc/cabextract-1.4 &&
    cp AUTHORS ChangeLog COPYING NEWS README TODO $_
  ) || exit
  
  ### winetricks
  install -d ${wine_destdir}/share/doc/winetricks &&
  install -m 0644 ${srcroot}/source/winetricks/src/COPYING $_ &&
  install -m 0755 ${srcroot}/source/winetricks/src/winetricks ${wine_destdir}/bin/winetricks.bin &&
  cat <<'__EOF__' > ${wine_destdir}/bin/winetricks && chmod +x ${wine_destdir}/bin/winetricks || exit
#!/bin/bash
export PATH="$(cd "$(dirname "$0")"; pwd)":/usr/bin:/bin:/usr/sbin:/sbin
which wine || { echo "wine not found."; exit 1; }
exec winetricks.bin "$@"
__EOF__
} # end BuildStage5_

function BuildWine_ {
  local srcdir=${srcroot}/source/wine && test -d ${srcdir} || exit
  local bindir=${wine_destdir}/bin
  local libdir=${wine_destdir}/lib
  local docdir=${wine_destdir}/share/doc/wine
  local inf=${wine_destdir}/share/wine/wine.inf
  
  cd ${workroot} &&
  ditto ${srcdir} wine &&
  cd wine &&
  git checkout -f master &&
  ./configure \
    --prefix=${wine_destdir} \
    --without-sane \
    --without-v4l \
    --without-gphoto \
    --without-oss \
    --without-capi \
    --without-gsm \
    --without-cms \
    --without-x \
  &&
  make ${make_args} depend &&
  make ${make_args} &&
  make install || exit

  ### add rpath to /usr/lib
  install_name_tool -add_rpath /usr/lib ${bindir}/wine &&
  install_name_tool -add_rpath /usr/lib ${bindir}/wineserver &&
  install_name_tool -add_rpath /usr/lib ${libdir}/libwine.1.0.dylib || exit
  
  install -d ${docdir} &&
  cp ${srcdir}/{ANNOUNCE,AUTHORS,COPYING.LIB,LICENSE,README,VERSION} ${docdir} || exit

  ### WINELOADER
  mv ${bindir}/wine{,.bin} &&
  cat <<__EOF__ > ${bindir}/wine && chmod +x ${bindir}/wine || exit
#!/bin/bash
install -d ${destroot}
ln -sf "\$(cd "\$(dirname "\$0")/../../.." && pwd)" ${destroot} || exit
exec ${bindir}/wine.bin "\$@"
__EOF__
  
  mv ${inf}{,.orig} &&
  ${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${inf}{,.orig} &&
  patch ${inf} ${srcroot}/patch/nxwine.patch || exit
} # end BuildWine_

function BuildBundle_ {
  local App=NXWine.app
  local Resources=${App}/Contents/Resources
  
  test ! -d ${destroot} || rm -rf ${destroot}
  install -d ${destroot} &&
  cd $_ &&
  sed "s|@DATE@|$(date +%F)|g" ${srcroot}/NXWine.applescript | osacompile -o ${App} &&
  rm ${Resources}/droplet.icns &&
  install -m 0644 {${srcroot},${Resources}}/nxwine.icns || exit
  
  # !!! to extract with absolute path
  Extract_ ${wine_tar} &&
  local wine_version=$(${Resources}/bin/wine.bin --version) &&
  test -n "${wine_version}" || exit
  
  while read
  do
    /usr/libexec/PlistBuddy -c "${REPLY}" ${App}/Contents/Info.plist || exit
  done <<__CMD__
Set :CFBundleIconFile nxwine
Add :NSHumanReadableCopyright string ${wine_version}, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine
Add :CFBundleVersion string ${build_version}
Add :CFBundleIdentifier string ${domain}.NXWine
Add :CFBundleDocumentTypes:1:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:1:CFBundleTypeExtensions:0 string exe
Add :CFBundleDocumentTypes:1:CFBundleTypeName string Windows Executable File
Add :CFBundleDocumentTypes:1:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:2:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:2:CFBundleTypeExtensions:0 string msi
Add :CFBundleDocumentTypes:2:CFBundleTypeName string Microsoft Windows Installer
Add :CFBundleDocumentTypes:2:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:3:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:3:CFBundleTypeExtensions:0 string lnk
Add :CFBundleDocumentTypes:3:CFBundleTypeName string Windows Shortcut File
Add :CFBundleDocumentTypes:3:CFBundleTypeRole string Viewer
__CMD__
  
  local dmg=${srcroot}/NXWine_${build_version}_${wine_version/wine-}.dmg
  test ! -f ${dmg} || rm ${dmg}
  ln -s /Applications &&
  hdiutil create -format UDBZ -srcdir ${destroot} -volname NXWine ${dmg} &&
  rm -rf ${destroot} || exit
} # end BuildBundle_

# -------------------------------------- begin processing section

if test -f ${wine_tar}; then :
else
  # initialize
  rm -rf ${destroot} ${workroot} &&
  install -d  ${deps_destdir}/{bin,include,share/man} \
              ${wine_destdir}/lib \
              ${workroot} \
  && (
    cd ${deps_destdir} &&
    ln -s ../Resources/lib lib &&
    ln -s share/man man
  ) || exit
  
  # dependencies
  if test -f ${deps_tar}; then Extract_ ${deps_tar}
  else
    # bootstrap
    if test -f ${bootstrap_tar}; then Extract_ ${bootstrap_tar}
    else
      BuildBootstrap_
      Compress_ ${bootstrap_tar}
    fi
    
    BuildStage1_
    BuildStage2_
    BuildStage3_
    BuildStage4_
    BuildStage5_
    Compress_ ${deps_tar}
  fi
  
  BuildWine_
  Compress_ ${wine_tar}
fi

### bundle
BuildBundle_

# -------------------------------------- end processing section

:
afplay /System/Library/Sounds/Hero.aiff
