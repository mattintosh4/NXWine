#!/usr/bin/env - LC_ALL=C SHELL=/bin/bash bash -x

while test -n "$1"
do
    case $1 in
        --test)
            test_mode= 
            shift
        ;;
    esac
done

readonly srcroot="$(cd "$(dirname "$0")"; pwd)"
readonly buildroot=/tmp/9C727687-28A1-47CE-9C4A-97128FADE79A
readonly domain=com.github.mattintosh4
readonly destroot=/tmp/${domain} && install -d ${destroot} || exit
readonly bundle=${destroot}/NXWine.app
readonly deps_destdir=${bundle}/Contents/SharedSupport
readonly wine_destdir=${bundle}/Contents/Resources

test -x /usr/local/bin/ccache   && readonly ccache=$_   || exit
test -x /usr/local/bin/clang    && readonly clang=$_    || exit
test -x /usr/local/bin/uconv    && readonly uconv=$_    || exit
test -x /usr/local/bin/make     && export MAKE=$_       || :

### Git and Python
test -x /usr/local/git/bin/git  && readonly git_dir=$(dirname $_) || exit
test -x /Library/Frameworks/Python.framework/Versions/2.7/bin/python2.7 && readonly python_dir=$(dirname $_) || exit

### Xcode
[ $(sw_vers -productVersion) == 10.6.8 ] &&
sdkroot=$(xcodebuild -version -sdk macosx10.6 | sed -n '/^Path/{;s/^Path: //;p;}') &&
test -d ${sdkroot} && readonly sdkroot || exit

PATH=/usr/bin:/bin:/usr/sbin:/sbin
PATH=${git_dir}:${python_dir}:$PATH
PATH=${deps_destdir}/bin:${deps_destdir}/sbin:$PATH
export PATH
export ARCHFLAGS="-arch i386"
export CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)"
export CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)"
export CFLAGS="-m32 -pipe -O3 -march=core2 -mtune=core2 -mmacosx-version-min=10.6.8"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-isysroot ${sdkroot} -I${deps_destdir}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${deps_destdir}/lib"
configure_args="--prefix=${deps_destdir} --build=i386-apple-darwin10.8.0 --enable-shared"
make_args="-j $(($(sysctl -n hw.ncpu) + 2))"

function BuildDeps_ {
    local f=${srcroot}/source/$1
    local n=$(echo $1 | sed -E 's#\.(zip|tbz2?|tgz|tar\..*)$##') || exit
    shift
    case ${f} in
        *.xz)
            if which xzcat; then
                xzcat ${f} | tar -x - || exit
            else
                /usr/local/bin/xzcat ${f} | tar -x - || exit
            fi
        ;;
        *)
            tar -xf ${f} || exit
        ;;
    esac
    pushd ${n} &&
        ./configure ${configure_args} "$@" &&
        make ${make_args} &&
        make install &&
    popd|| exit
} # end BuildDeps_

function DocCopy_ {
    test -n "$1" || exit
    local dest=${deps_destdir}/share/doc/$1
    install -d ${dest} &&
    cp $(find -E ${buildroot}/$1 -depth 1 -regex '.*(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING|COPYING.LIB|LICENSE|NEWS|README|RELEASE|TODO|VERSION)') ${dest} || exit
} # end DocCopy_

function BuildDevel_ {
    test -n "$1" || exit
    
    cd ${buildroot} &&
    ditto ${srcroot}/source/$1 $1 &&
    pushd $1 || exit
    
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
    esac
    (($? == 0)) || exit
    
    make ${make_args} &&
    make install &&
    DocCopy_ $1 || exit
    popd
} # end BuildDevel_

function BuildBundle_ {
    sed "s|@DATE@|$(date +%F)|g" ${srcroot}/NXWine.applescript | osacompile -o ${bundle} &&
    cp -f {${srcroot},${bundle}/Contents/Resources}/droplet.icns &&
    install -d ${deps_destdir}/{bin,include,lib,share/man} &&
    (cd ${deps_destdir} && ln -s share/man man) || exit
} # end BuildBundle_

# test mode check
if test -n "${test_mode+x}"; then
    # test build
    test -e ${bundle} || BuildBundle_
else
    # clean build
    rm -rf ${bundle} ${buildroot}
    BuildBundle_
fi
install -d ${buildroot}
cd ${buildroot} || exit

# bootstrap check
build_bootstrap=
readonly bootstrap_tar=${srcroot}/bootstrap.tbz2
if test -f "${bootstrap_tar}"; then
    tar -xf $_ -C ${bundle}/Contents &&
    test -d ${deps_destdir} &&
    unset build_bootstrap || exit
fi

# begin bootstrap
test -n "${build_bootstrap+x}" && {
    # readline is required from unixODBC
    BuildDeps_ readline-6.2.tar.gz --with-curses && DocCopy_ readline-6.2
    BuildDeps_ m4-1.4.16.tar.bz2 --program-prefix=g && {
        pushd ${deps_destdir}/bin &&
            ln -s {g,}m4 && ./$_ --version >/dev/null &&
        popd || exit
    }
    BuildDeps_ autoconf-2.69.tar.gz
    BuildDeps_ automake-1.13.1.tar.gz
    BuildDeps_ libtool-2.4.2.tar.gz --program-prefix=g && {
        pushd ${deps_destdir}/bin &&
            ln -sf {g,}libtool    && ./$_ --version >/dev/null &&
            ln -sf {g,}libtoolize && ./$_ --version >/dev/null &&
        popd || exit
    }
    BuildDeps_ pkg-config-0.28.tar.gz \
        --disable-debug \
        --disable-host-tool \
        --with-internal-glib \
        --with-pc-path=${deps_destdir}/lib/pkgconfig:${deps_destdir}/share/pkgconfig:/usr/lib/pkgconfig
    BuildDeps_ gettext-0.18.2.tar.gz
    BuildDeps_ xz-5.0.4.tar.bz2
    
    ditto -cj --keepParent ${deps_destdir} ${bootstrap_tar} || exit
} # end bootstrap


# begin stage 1
: && {
    BuildDeps_ libusb-1.0.9.tar.bz2
    BuildDeps_ libusb-compat-0.1.4.tar.bz2
    
    # valgrind add '-arch' flag, i686-apple-darwin10-gcc-4.2.1 will not work
    BuildDeps_ valgrind-3.8.1.tar.bz2 --enable-only32bit CC=$(xcrun -find gcc-4.2) CXX=$(xcrun -find g++-4.2)
    
    cd ${buildroot} &&
    tar -xf ${srcroot}/source/gmp-5.1.1.tar.bz2 &&
    pushd gmp-5.1.1 &&
        sh configure ${configure_args} ABI=32 --enable-cxx &&
        make ${make_args} &&
        make check &&
        make install &&
    popd || exit
    BuildDeps_ libtasn1-3.3.tar.gz # libtasn1 required valgrind
    BuildDeps_ nettle-2.7.tar.gz
    BuildDeps_ gnutls-3.1.8.tar.xz \
        --with-libnettle-prefix=${deps_destdir} \
        LIBTASN1_CFLAGS="$(pkg-config --cflags libtasn1)" \
        LIBTASN1_LIBS="$(pkg-config --libs libtasn1)"
} # end stage 1

# begin stage 1+
: && {
    BuildDevel_ libffi
    BuildDevel_ glib
    BuildDevel_ freetype
} # end stage 1+

# begin stage 2
: && {
    # orc required valgrind; to build with gcc failed
    BuildDeps_ orc-0.4.17.tar.gz \
        CC="${ccache} ${clang}" \
        CXX="${ccache} ${clang}++" \
        CFLAGS="-arch i386 ${CFLAGS}" \
        CXXFLAGS="-arch i386 ${CFLAGS}"
    
    BuildDeps_ unixODBC-2.3.1.tar.gz && DocCopy_ unixODBC-2.3.1
    
    BuildDevel_ libpng
    # nasm is required from libjpeg-turbo
    BuildDeps_ nasm-2.10.07.tar.xz && DocCopy_ nasm-2.10.07
    BuildDeps_ libjpeg-turbo-1.2.1.tar.gz --with-jpeg8 && {
        install -d ${deps_destdir}/share/doc/libjpeg-turbo-1.2.1
        mv ${deps_destdir}/share/doc/{example.c,libjpeg.txt,README,README-turbo.txt,structure.txt,usage.txt,wizard.txt} $_
    }
    BuildDeps_ tiff-4.0.3.tar.gz
    BuildDeps_ jasper-1.900.1.zip --disable-opengl --without-x
    BuildDeps_ libicns-0.8.1.tar.gz
} # end stage 2

# begin stage 3
: && {
    BuildDeps_ libogg-1.3.0.tar.gz
    BuildDeps_ libvorbis-1.3.3.tar.gz
    BuildDeps_ flac-1.2.1.tar.gz --disable-asm-optimizations --disable-xmms-plugin
    BuildDeps_ SDL-1.2.15.tar.gz --without-x && DocCopy_ SDL-1.2.15
    BuildDeps_ SDL_sound-1.0.3.tar.gz        && DocCopy_ SDL_sound-1.0.3
    # libtheora required SDL
    BuildDeps_ libtheora-1.1.1.tar.bz2 \
        --disable-oggtest \
        --disable-vorbistest \
        --disable-examples \
        --disable-asm
} # end stage 3

# begin stage 4
: && {
    # cabextract
    cd ${buildroot} &&
    tar -xf ${srcroot}/source/cabextract-1.4.tar.gz &&
    pushd cabextract-1.4 &&
        sh configure ${configure_args/${deps_destdir}/${wine_destdir}} &&
        make ${make_args} &&
        make install &&
        install -d ${wine_destdir}/share/doc/cabextract-1.4 &&
        cp AUTHORS ChangeLog COPYING NEWS README TODO $_ &&
    popd || exit

    # winetricks
    install -d ${wine_destdir}/share/doc/winetricks &&
    install -m 0644 ${srcroot}/source/winetricks/src/COPYING $_ &&
    install -m 0755 ${srcroot}/source/winetricks/src/winetricks ${wine_destdir}/bin/winetricks.bin &&
    cat <<'__EOF__' > ${wine_destdir}/bin/winetricks && chmod +x ${wine_destdir}/bin/winetricks || exit
#!/bin/bash
export PATH="$(cd "$(dirname "$0")"; pwd)":/usr/bin:/bin:/usr/sbin:/sbin
which wine || { echo "wine not found."; exit 1; }
exec winetricks.bin "$@"
__EOF__
} # end stage 4

# begin stage wine
: && {
    cd ${buildroot} &&
    ditto ${srcroot}/source/wine wine &&
    cd wine &&
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
        PKG_CONFIG=${deps_destdir}/bin/pkg-config \
    &&
    make ${make_args} depend &&
    make ${make_args} &&
    make install &&
    install -d ${wine_destdir}/share/doc/wine &&
    cp ANNOUNCE AUTHORS COPYING.LIB LICENSE README VERSION $_ || exit
    
    wine_version=$(${wine_destdir}/bin/wine --version)
    
    # add rpath to ${deps_destdir} and /usr/lib
    for x in \
        bin/wine \
        bin/wineserver \
        lib/libwine.1.0.dylib \
        
    do
        install_name_tool -add_rpath ${deps_destdir}/lib    ${wine_destdir}/${x} &&
        install_name_tool -add_rpath /usr/lib               ${wine_destdir}/${x} || exit
    done
    unset x
    
    # WINELOADER
    mv ${wine_destdir}/bin/wine{,.bin} &&
    cat <<__EOF__ > ${wine_destdir}/bin/wine && chmod +x ${wine_destdir}/bin/wine || exit
#!/bin/bash
install -d ${destroot}
ln -sf "\$(cd "\$(dirname "\$0")/../../.." && pwd)" ${destroot}
exec ${wine_destdir}/bin/wine.bin "\$@"
__EOF__
    
    # wine.inf
    inf=${wine_destdir}/share/wine/wine.inf
    mv ${inf}{,.orig} &&
    ${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${inf}{,.orig} &&
    patch ${inf} ${srcroot}/patch/nxwine.patch || exit
    

} || exit # end stage wine



while read
do
    /usr/libexec/PlistBuddy -c "${REPLY}" ${bundle}/Contents/Info.plist
done <<__CMD__
Add :NSHumanReadableCopyright string ${wine_version}, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine
Add :CFBundleVersion string $(date +%F)
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

test ! -f "${dmg=${srcroot}/NXWine_$(date +%F)_${wine_version/wine-}.dmg}" || rm ${dmg}
ln -s /Applications ${destroot} &&
hdiutil create -format UDBZ -srcdir ${destroot} -volname NXWine ${dmg} || exit

:
afplay /System/Library/Sounds/Hero.aiff
