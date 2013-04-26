#!/bin/bash -x

srcroot="$(cd "$(dirname "$0")"; pwd)"
winesrcroot=/usr/local/src/wine
bundle=/Applications/NXWine.app
prefix=${bundle}/Contents/Resources

test -x /usr/local/bin/ccache && ccache=$_ || exit
test -x /usr/local/bin/clang && { clang=$_; clangxx="${clang} -x c++ -stdlib=libstdc++"; } || exit
test -x /usr/local/bin/make && make=$_ || exit
test -x /usr/local/bin/uconv && uconv=$_ || exit

function BuildBundle_ {
    test ! -e ${bundle} || rm -rf ${bundle}
    sed "s|@DATE@|$(date +%F)|g" ${srcroot}/NXWine.applescript | osacompile -o ${bundle} || exit
    rm ${bundle}/Contents/Resources/droplet.icns
    install -d ${prefix}/{bin,include,lib} || exit
}
BuildBundle_

export PATH=${prefix}/bin:$(sysctl -n user.cs_path):/usr/local/git/bin
export ARCHFLAGS="-arch i386"
export CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)"
export CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)"
export CFLAGS="-pipe -O3 -march=core2 -mtune=core2 -mmacosx-version-min=10.6.8 -isysroot ${sdkroot=/Developer/SDKs/MacOSX10.6.sdk}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-I${prefix}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${prefix}/lib"
jn="-j $(($(sysctl -n hw.ncpu) + 1))"

cd $(mktemp -dt $$)

function BuildDeps_ {
    (( $# > 1 )) || exit
    case $1 in
        *.tar.xz)
            xzcat ${srcroot}/source/$1 | tar -x - || exit
        ;;
        *)
            tar -xf ${srcroot}/source/$1 || exit
        ;;
    esac
    shift &&
    pushd $1 &&
    shift &&
    ./configure \
        --prefix=${prefix} \
        --enable-shared \
        --disable-dependency-tracking \
        "$@" \
    &&
    ${make} ${jn} &&
    ${make} install || exit
    popd
}
BuildDeps_ pkg-config-0.28{.tar.gz,} \
    --disable-debug \
    --disable-host-tool \
    --with-internal-glib \
    --with-pc-path=${prefix}/lib/pkgconfig:${prefix}/share/pkgconfig:/usr/lib/pkgconfig
BuildDeps_ gettext-0.18.2{.tar.gz,}
BuildDeps_ xz-5.0.4{.tar.bz2,}
BuildDeps_ libffi-3.0.13{.tar.gz,}
BuildDeps_ glib-2.34.3{.tar.xz,}
BuildDeps_ freetype-2.4.11{.tar.gz,}
BuildDeps_ orc-0.4.17{.tar.gz,} \
    CC="${ccache} ${clang}" \
    CXX="${ccache} ${clangxx}" \
    CFLAGS="-m32 -arch i386 ${CFLAGS}" \
    CXXFLAGS="-m32 -arch i386 ${CFLAGS}"
BuildDeps_ libpng-1.6.1{.tar.gz,}
BuildDeps_ jpegsrc.v8d.tar.gz jpeg-8d
BuildDeps_ tiff-4.0.3{.tar.gz,}
BuildDeps_ jasper-1.900.1{.zip,} --disable-opengl --without-x
BuildDeps_ libicns-0.8.1{.tar.gz,}
BuildDeps_ libogg-1.3.0{.tar.gz,}
BuildDeps_ libvorbis-1.3.3{.tar.gz,}
BuildDeps_ flac-1.2.1{.tar.gz,} --disable-asm-optimizations --disable-xmms-plugin
BuildDeps_ SDL-1.2.15{.tar.gz,} --without-x && {
    install -d ${prefix}/share/doc/SDL
    cp SDL-1.2.15/{BUGS,COPYING,CREDITS,README,TODO} $_
}
BuildDeps_ SDL_sound-1.0.3{.tar.gz,} && {
    install -d ${prefix}/share/doc/SDL_sound
    cp SDL_sound-1.0.3/{CHANGELOG,COPYING,CREDITS,README,TODO} $_
}
BuildDeps_ unixODBC-2.3.1{.tar.gz,} && {
    install -d ${prefix}/share/doc/unixODBC &&
    cp unixODBC-2.3.1/{AUTHORS,ChangeLog,COPYING,NEWS,README} $_
}
# libtheora required SDL
BuildDeps_ libtheora-1.1.1{.tar.bz2,} \
    --disable-oggtest \
    --disable-vorbistest \
    --disable-examples \
    --disable-asm
BuildDeps_ gstreamer-0.11.99{.tar.xz,} \
    --disable-tests \
    --disable-benchmarks \
    --disable-examples \
    CC="${ccache} ${clang}" \
    CXX="${ccache} ${clangxx}" \
    CFLAGS="-m32 -arch i386 ${CFLAGS}" \
    CXXFLAGS="-m32 -arch i386 ${CFLAGS}" && {
        install -d ${prefix}/share/doc/gstreamer
        cp gstramer-0.11.99/{AUTHORS,ChangeLog,COPYING,NEWS,README,RELEASE,TODO} $_
}
BuildDeps_ gst-plugins-base-0.11.99{.tar.xz,} \
    --enable-experimental \
    --disable-examples \
    --disable-x \
    --disable-xvideo \
    --disable-xshm \
    --disable-alsa \
    --disable-cdparanoia \
    --disable-ivorbis \
    --disable-libvisual \
    --disable-pango \
    CC="${ccache} ${clang}" \
    CXX="${ccache} ${clangxx}" \
    CFLAGS="-m32 -arch i386 ${CFLAGS}" \
    CXXFLAGS="-m32 -arch i386 ${CFLAGS}" && {
        install -d ${prefix}/share/doc/gst-plugins-base
        cp gst-plugins-base-0.11.99/{AUTHORS,ChangeLog,COPYING,COPYING.LIB,NEWS,README,RELEASE} $_
}
BuildDeps_ cabextract-1.4{.tar.gz,} && {
    install -d ${prefix}/share/doc/cabextract &&
    cp cabextract-1.4/{AUTHORS,ChangeLog,COPYING,NEWS,README,TODO} $_
}
# winetricks
install -d ${prefix}/share/doc/winetricks &&
install -m 0644 ${srcroot}/source/winetricks/src/COPYING $_ &&
install -m 0755 ${srcroot}/source/winetricks/src/winetricks ${prefix}/bin/winetricks.bin &&
cat <<'__EOF__' > ${prefix}/bin/winetricks && chmod +x ${prefix}/bin/winetricks || exit
#!/bin/bash
export PATH="$(cd "$(dirname "$0")"; pwd)":/usr/bin:/bin:/usr/sbin:/sbin
which wine || { echo "wine not found."; exit; }
exec winetricks.bin "$@"
__EOF__


install -d wine &&
cd wine &&
${winesrcroot}/configure \
    --prefix=${prefix} \
    --without-sane \
    --without-v4l \
    --without-gphoto \
    --without-oss \
    --without-capi \
    --without-gsm \
    --without-cms \
    --without-x \
&&
${make} ${jn} depend &&
${make} ${jn} &&
${make} install || exit

install_name_tool -add_rpath /usr/lib ${prefix}/bin/wine &&
install_name_tool -add_rpath /usr/lib ${prefix}/bin/wineserver &&
install_name_tool -add_rpath /usr/lib ${prefix}/lib/libwine.1.0.dylib || exit

install -d ${prefix}/share/doc/wine
cp ${winesrcroot}/{ANNOUNCE,AUTHORS,COPYING.LIB,LICENSE,README} ${prefix}/share/doc/wine

infsrc=${prefix}/share/wine/wine.inf
inftmp=$(uuidgen)
patch -o ${inftmp} ${infsrc} ${srcroot}/patch/nxwine.patch &&
${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${infsrc} ${inftmp} || exit


wine_version=$(${prefix}/bin/wine --version)
while read
do
    /usr/libexec/PlistBuddy -c "${REPLY}" ${bundle}/Contents/Info.plist
done <<__CMD__
Add :NSHumanReadableCopyright string ${wine_version}, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine
Add :CFBundleVersion string $(date +%F)
Add :CFBundleIdentifier string com.github.mattintosh4.NXWine
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


test ! -f ${dmg=${srcroot}/NXWine_$(date +%F)_${wine_version#*-}.dmg} || rm ${dmg}
dmg_srcdir=$(mktemp -dt $$)
mv ${bundle} ${dmg_srcdir}
ln -s /Applications ${dmg_srcdir}
hdiutil create -srcdir ${dmg_srcdir} -volname NXWine ${dmg} &&
rm -rf ${dmg_srcdir}

:
afplay /System/Library/Sounds/Hero.aiff
