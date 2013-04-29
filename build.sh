#!/bin/bash -x

case $1 in
    --test)
        test_mode=
        shift
    ;;
esac

readonly srcroot="$(cd "$(dirname "$0")"; pwd)"
readonly workdir=${TMPDIR}/9C727687-28A1-47CE-9C4A-97128FADE79A
readonly bundle=/Applications/NXWine.app
readonly prefix=${bundle}/Contents/Resources

test -x /usr/local/bin/ccache       && ccache=$_            || exit
test -x /usr/local/bin/clang        && clang=$_             || exit
test -x /usr/local/bin/uconv        && uconv=$_             || exit
test -x /usr/local/bin/make         && export MAKE=$_       || exit
test -x /usr/local/bin/nasm         && export NASM=$_       || exit
test -x /usr/local/bin/objdump      && export OBJDUMP=$_    || :
test -x /usr/local/bin/objcopy      && export OBJCOPY=$_    || :

test -x /usr/local/git/bin/git && readonly git_dir=$(dirname $_) || exit
test -x /Library/Frameworks/Python.framework/Versions/2.7/bin/python2.7 && readonly python_dir=$(dirname $_) || exit

export SHELL=/bin/bash
export LC_ALL=C
export PATH=${prefix}/bin:${git_dir}:${python_dir}:$(sysctl -n user.cs_path)
export ARCHFLAGS="-arch i386"
export CC="${ccache} $(xcrun -find i686-apple-darwin10-gcc-4.2.1)"
export CXX="${CC/gcc/g++}"
export CFLAGS="-pipe -O3 -march=core2 -mtune=core2 -mmacosx-version-min=10.6.8"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS=" -isysroot ${sdkroot=/Developer/SDKs/MacOSX10.6.sdk} -I${prefix}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${prefix}/lib"

configure_args="--prefix=${prefix} --build=i386-apple-darwin10.8.0 --enable-shared"
jn="-j $(($(sysctl -n hw.ncpu) + 1))"


function BuildBundle_ {
    test ! -e ${bundle} || rm -rf ${bundle}
    sed "s|@DATE@|$(date +%F)|g" ${srcroot}/NXWine.applescript | osacompile -o ${bundle} || exit
    rm ${bundle}/Contents/Resources/droplet.icns
    install -d ${prefix}/{bin,include,lib} || exit
} # end BuildBundle_
test -n "${test_mode+x}" || rm -rf ${bundle} ${workdir}
test -e ${bundle} || BuildBundle_
install -d ${workdir}
cd ${workdir} || exit



function BuildDeps_ {
    local f=${srcroot}/source/$1
    local name=$(echo $1 | sed -E 's#\.(zip|tar\..*)$##') || exit
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
    pushd ${name} &&
    ./configure ${configure_args} "$@" &&
    make ${jn} &&
    make install || exit
    popd
} # end BuildDeps_

function DocCopy_ {
    test -n "$1" || exit
    local dest=${prefix}/share/doc/$1
    install -d ${dest} &&
    cp $(find -E ${workdir}/$1 -depth 1 -regex '.*(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING|COPYING.LIB|LICENSE|NEWS|README|RELEASE|TODO|VERSION)') ${dest} || exit
} # end DocCopy_

function BuildDevel_ {
    local name=$1
    cd ${workdir} &&
    ditto ${srcroot}/source/${name} ${name} &&
    pushd ${name} || exit
    
    case $1 in
        libffi)
            git checkout -f master &&
            sh configure ${configure_args}
        ;;
        glib)
            git checkout -f 2.36.1 &&
            sh autogen.sh ${configure_args} --disable-gtk-doc
        ;;
        freetype2)
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
    
    (($? == 0)) &&
    make ${jn} &&
    make install &&
    DocCopy_ ${name} || exit
    popd
} # end BuildDevel_

# begin stage 1
: && {
    BuildDeps_ pkg-config-0.28.tar.gz \
        --disable-debug \
        --disable-host-tool \
        --with-internal-glib \
        --with-pc-path=${prefix}/lib/pkgconfig:${prefix}/share/pkgconfig:/usr/lib/pkgconfig
    BuildDeps_ autoconf-2.69.tar.gz
    BuildDeps_ automake-1.13.1.tar.gz
    BuildDeps_ libtool-2.4.2.tar.gz --program-prefix=g && {
        export LIBTOOL=${prefix}/bin/glibtool
        export LIBTOOLIZE=${prefix}/bin/glibtoolize
    }
    BuildDeps_ gettext-0.18.2.tar.gz
    # m4 required gettext
    BuildDeps_ m4-1.4.16.tar.bz2 --program-prefix=g && {
        export M4=${prefix}/bin/gm4
    }
    BuildDeps_ xz-5.0.4.tar.bz2
    BuildDevel_ libffi
} # end stage 1

# begin stage 1+
: && {
    BuildDevel_ glib
    BuildDevel_ freetype2
} # end stage 1+

# begin stage 2
: && {
    # valgrind add '-arch' flag
    BuildDeps_ valgrind-3.8.1.tar.bz2 \
        --enable-only32bit \
        CC=$( xcrun -find gcc-4.2) \
        CXX=$(xcrun -find g++-4.2) \
        CFLAGS="-isysroot ${sdkroot}" \
        CXXFLAGS="-isysroot ${sdkroot}"
    
    # orc required valgrind; to build with gcc failed
    BuildDeps_ orc-0.4.17.tar.gz \
        CC="${ccache} ${clang}" \
        CXX="${ccache} ${clang}++" \
        CFLAGS="-m32 -arch i386 ${CFLAGS}" \
        CXXFLAGS="-m32 -arch i386 ${CFLAGS}"
    
    BuildDeps_ unixODBC-2.3.1.tar.gz && DocCopy_ unixODBC-2.3.1
    
    BuildDevel_ libpng
    BuildDeps_ libjpeg-turbo-1.2.1.tar.gz --with-jpeg8 && {
        install -d ${prefix}/share/doc/libjpeg-turbo-1.2.1
        mv ${prefix}/share/doc/{example.c,libjpeg.txt,README,README-turbo.txt,structure.txt,usage.txt,wizard.txt} $_
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
    BuildDeps_ cabextract-1.4.tar.gz && DocCopy_ cabextract-1.4
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
} # end stage 4



ditto ${srcroot}/source/wine wine && (
    cd wine &&
    ./configure \
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
    make ${jn} depend &&
    make ${jn} &&
    make install || exit
    
    # add rpath to /usr/lib
    install_name_tool -add_rpath /usr/lib ${prefix}/bin/wine &&
    install_name_tool -add_rpath /usr/lib ${prefix}/bin/wineserver &&
    install_name_tool -add_rpath /usr/lib ${prefix}/lib/libwine.1.0.dylib || exit

    # copy documents
    DocCopy_ wine
    
    # update wine.inf
    inf=${prefix}/share/wine/wine.inf
    mv ${inf}{,.orig}
    ${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${inf}{,.orig} &&
    patch ${inf} ${srcroot}/patch/nxwine.patch || exit
) || exit



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
dmg_srcdir=$(install -d /tmp/$(uuidgen); cd $_; pwd) &&
mv ${bundle} ${dmg_srcdir} &&
ln -s /Applications ${dmg_srcdir} &&
hdiutil create -srcdir ${dmg_srcdir} -volname NXWine ${dmg} &&
rm -rf ${dmg_srcdir} || exit

:
afplay /System/Library/Sounds/Hero.aiff
