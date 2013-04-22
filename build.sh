#!/bin/bash -x

winesrcroot=/Volumes/HFSPlus/src/wine

srcroot="$(cd "$(dirname "$0")"; pwd)"
prefix=/tmp/local

test ! -d ${prefix} || rm -rf ${prefix}
install -d ${prefix}/{bin,include,lib}

export PATH=${prefix}/bin:$(sysctl -n user.cs_path):/usr/local/git/bin
export CC=/usr/local/bin/clang
export CXX=/usr/local/bin/clang++
export CFLAGS="-pipe -m32 -arch i386 -march=core2 -mtune=core2 -mmacosx-version-min=10.6.8 -isysroot ${sdkroot=/Developer/SDKs/MacOSX10.6.sdk}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-I${prefix}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${prefix}/lib"

function BuildDeps_ {
    cd $1 &&
    ./configure --build=x86_64-apple-darwin10 --prefix=${prefix} &&
    make -j$(sysctl -n hw.ncpu) &&
    make install || exit
    cd -
}

cd $(mktemp -dt $$) &&
tar -xf ${srcroot}/source/xz-5.0.4.tar.bz2 &&
tar -xf ${srcroot}/source/gettext-0.18.2.tar.gz &&
tar -xf ${srcroot}/source/freetype-2.4.11.tar.gz &&
tar -xf ${srcroot}/source/libpng-1.6.1.tar.gz &&
tar -xf ${srcroot}/source/jpegsrc.v8d.tar.gz &&
tar -xf ${srcroot}/source/tiff-4.0.3.tar.gz &&
BuildDeps_ xz-5.0.4
BuildDeps_ gettext-0.18.2
BuildDeps_ freetype-2.4.11
BuildDeps_ libpng-1.6.1
BuildDeps_ jpeg-8d
BuildDeps_ tiff-4.0.3

export CC=$( xcrun -find gcc-4.2)
export CXX=$(xcrun -find g++-4.2)

cd $(mktemp -dt $$) &&
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
make -j$(sysctl -n hw.ncpu) depend &&
make -j$(sysctl -n hw.ncpu) &&
make install || exit

test ! -f ${dmg=${srcroot}/NXWine_$(date +%F).dmg} || rm ${dmg}
hdiutil create -srcdir ${prefix} -volname NXWine ${dmg} &&
rm -rf ${prefix}
(cd ${srcroot} && ln -sf $(basename ${dmg}) NXWine.dmg)

:
afplay /System/Library/Sounds/Hero.aiff
