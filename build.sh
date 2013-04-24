#!/bin/bash -x

srcroot="$(cd "$(dirname "$0")"; pwd)"
winesrcroot=/usr/local/src/wine
bundle=/Applications/NXWine.app
prefix=${bundle}/Contents/Resources

test -x ${uconv=/opt/local/bin/uconv} || exit

test ! -e ${bundle} || rm -rf ${bundle}
sed "s|@DATE@|$(date +%F)|g" ${srcroot}/NXWine.applescript | osacompile -o ${bundle} || exit
rm ${bundle}/Contents/Resources/droplet.icns


install -d ${prefix}/{bin,include,lib} || exit

export PATH=${prefix}/bin:$(sysctl -n user.cs_path):/usr/local/git/bin
export CC=$( xcrun -find i686-apple-darwin10-gcc-4.2.1)
export CXX=$(xcrun -find i686-apple-darwin10-g++-4.2.1)
export OBJDUMP=/usr/local/bin/llvm-objdump
export CFLAGS="-pipe -O3 -march=core2 -mtune=core2 -mmacosx-version-min=10.6.8 -isysroot ${sdkroot=/Developer/SDKs/MacOSX10.6.sdk}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-I${prefix}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${prefix}/lib"
jn="-j $(($(sysctl -n hw.ncpu) + 1))"

cd $(mktemp -dt $$) &&
for x in \
    cabextract-1.4.tar.gz \
    freetype-2.4.11.tar.gz \
    gettext-0.18.2.tar.gz \
    jasper-1.900.1.zip \
    jpegsrc.v8d.tar.gz \
    libicns-0.8.1.tar.gz \
    libpng-1.6.1.tar.gz \
    pkg-config-0.28.tar.gz \
    SDL-1.2.15.tar.gz \
    tiff-4.0.3.tar.gz \
    unixODBC-2.3.1.tar.gz \
    xz-5.0.4.tar.bz2 \

do
    tar -xf ${srcroot}/source/${x} || exit
done

function BuildDeps_ {
    pushd $1 &&
    shift &&
    ./configure \
        --prefix=${prefix} \
        --enable-shared \
        --disable-dependency-tracking \
        $@ \
    &&
    make ${jn} &&
    make install || exit
    popd
}
BuildDeps_ pkg-config-0.28 --with-internal-glib
export PKG_CONFIG_LIBDIR=${prefix}/lib/pkgconfig:${prefix}/share/pkgconfig:/usr/lib/pkgconfig
BuildDeps_ gettext-0.18.2
BuildDeps_ freetype-2.4.11
BuildDeps_ xz-5.0.4
BuildDeps_ libpng-1.6.1
BuildDeps_ jpeg-8d
BuildDeps_ tiff-4.0.3
BuildDeps_ jasper-1.900.1 --disable-opengl --without-x
BuildDeps_ libicns-0.8.1
BuildDeps_ SDL-1.2.15 --without-x && {
    install -d ${prefix}/share/doc/SDL
    cp SDL-1.2.15/{BUGS,COPYING,CREDITS,README,TODO} $_
}
BuildDeps_ unixODBC-2.3.1 && {
    install -d ${prefix}/share/doc/unixODBC &&
    cp unixODBC-2.3.1/{AUTHORS,ChangeLog,COPYING,NEWS,README} $_
}
BuildDeps_ cabextract-1.4 && {
    install -d ${prefix}/share/doc/cabextract &&
    cp cabextract-1.4/{AUTHORS,ChangeLog,COPYING,NEWS,README,TODO} $_
}
# winetricks
install -d ${prefix}/share/doc/winetricks &&
install -m 0644 ${srcroot}/source/winetricks/src/COPYING $_ &&
install -m 0755 ${srcroot}/source/winetricks/src/winetricks ${prefix}/bin


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
    LIBS="-lxslt -lxml2 -lncurses -lcups" \
&&
make ${jn} depend &&
make ${jn} &&
make install || exit

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

:
afplay /System/Library/Sounds/Hero.aiff
