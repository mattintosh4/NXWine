#!/bin/bash -x

srcroot="$(cd "$(dirname "$0")"; pwd)"
winesrcroot=/usr/local/src/wine
bundle=/Applications/NXWine.app
prefix=${bundle}/Contents/Resources

test -x ${uconv=/opt/local/bin/uconv} || exit

test ! -e ${bundle} || rm -rf ${bundle}
osacompile -o ${bundle} <<__APPLESCRIPT__ || exit
--
-- NXWine.app - No X11 Wine
-- Created by mattintosh4 on $(date +%F).
-- Copyright (c) 2013 mattintosh4, mattintosh4@gmx.com
-- https://github.com/mattintosh4/NXWine
--

on main(input)
    set wine to quoted form of (POSIX path of (path to me) & "Contents/Resources/bin/wine")
    try
        do shell script wine & space & input
    end try
end main

on open argv
    repeat with aFile in argv
        main("start /Unix" & space & quoted form of (POSIX path of aFile))
    end repeat
end open

on run
    main("explorer")
end run
__APPLESCRIPT__
rm ${bundle}/Contents/Resources/droplet.icns


install -d ${prefix}/{bin,include,lib} || exit

export PATH=${prefix}/bin:$(sysctl -n user.cs_path):/usr/local/git/bin
export CC=/usr/local/bin/clang
export CXX=/usr/local/bin/clang++
export CFLAGS="-pipe -m32 -arch i386 -O3 -march=core2 -mtune=core2 -mmacosx-version-min=10.6.8 -isysroot ${sdkroot=/Developer/SDKs/MacOSX10.6.sdk}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-I${prefix}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${prefix}/lib"
jobs="-j $(($(sysctl -n hw.ncpu) + 1))"

function BuildDeps_ {
    cd $1 &&
    ./configure --build=x86_64-apple-darwin10 --prefix=${prefix} --disable-static --disable-dependency-tracking &&
    make ${jobs} &&
    make install || exit
    cd -
}
cd $(mktemp -dt $$) &&
tar -xf ${srcroot}/source/gettext-0.18.2.tar.gz &&
tar -xf ${srcroot}/source/freetype-2.4.11.tar.gz &&
tar -xf ${srcroot}/source/xz-5.0.4.tar.bz2 &&
tar -xf ${srcroot}/source/libpng-1.6.1.tar.gz &&
tar -xf ${srcroot}/source/jpegsrc.v8d.tar.gz &&
tar -xf ${srcroot}/source/tiff-4.0.3.tar.gz &&
tar -xf ${srcroot}/source/libicns-0.8.1.tar.gz &&
BuildDeps_ gettext-0.18.2
BuildDeps_ freetype-2.4.11
BuildDeps_ xz-5.0.4
BuildDeps_ libpng-1.6.1
BuildDeps_ jpeg-8d
BuildDeps_ tiff-4.0.3
BuildDeps_ libicns-0.8.1


export CC=$( xcrun -find gcc-4.2)
export CXX=$(xcrun -find g++-4.2)
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
make ${jobs} depend &&
make ${jobs} &&
make install || exit

infsrc=${prefix}/share/wine/wine.inf
inftmp=$(uuidgen)
patch -o ${inftmp} ${infsrc} ${srcroot}/patch/ipamona.patch &&
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
hdiutil create -srcdir ${bundle} -volname NXWine ${dmg} &&

:
afplay /System/Library/Sounds/Hero.aiff
