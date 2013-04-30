#!/bin/bash -x

case $1 in
    --test)
        test_mode=
        shift
    ;;
esac

readonly srcroot="$(cd "$(dirname "$0")"; pwd)"
readonly workdir=${TMPDIR}/9C727687-28A1-47CE-9C4A-97128FADE79A

readonly destroot=/tmp/com.github.mattintosh4 && install -d ${destroot} || exit
readonly bundle=${destroot}/NXWine.app
readonly deps_destroot=${bundle}/Contents/SharedSupport
readonly wine_destroot=${bundle}/Contents/Resources

test -x /usr/local/bin/ccache   && readonly ccache=$_   || exit
test -x /usr/local/bin/clang    && readonly clang=$_    || exit
test -x /usr/local/bin/uconv    && readonly uconv=$_    || exit
test -x /usr/local/bin/make     && export MAKE=$_       || :
test -x /usr/local/bin/objdump  && export OBJDUMP=$_    || :
test -x /usr/local/bin/objcopy  && export OBJCOPY=$_    || :

test -x /usr/local/git/bin/git && readonly git_dir=$(dirname $_) || exit
test -x /Library/Frameworks/Python.framework/Versions/2.7/bin/python2.7 && readonly python_dir=$(dirname $_) || exit

export SHELL=/bin/bash
export LC_ALL=C
export PATH=${deps_destroot}/bin:${git_dir}:${python_dir}:$(sysctl -n user.cs_path)
export ARCHFLAGS="-arch i386"
export CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)"
export CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)"
export CFLAGS="-pipe -O3 -march=core2 -mtune=core2 -mmacosx-version-min=10.6.8"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS=" -isysroot ${sdkroot=/Developer/SDKs/MacOSX10.6.sdk} -I${deps_destroot}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${deps_destroot}/lib"

configure_args="--prefix=${deps_destroot} --build=i386-apple-darwin10.8.0 --enable-shared"
jn="-j $(($(sysctl -n hw.ncpu) + 1))"


function BuildBundle_ {
    test ! -e ${bundle} || rm -rf ${bundle}
    sed "s|@DATE@|$(date +%F)|g" ${srcroot}/NXWine.applescript | osacompile -o ${bundle} &&
    rm ${bundle}/Contents/Resources/droplet.icns &&
    install -d ${deps_destroot}/{bin,include,lib,share/man} &&
    (cd ${deps_destroot} && ln -s share/man man) || exit
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
    local dest=${deps_destroot}/share/doc/$1
    install -d ${dest} &&
    cp $(find -E ${workdir}/$1 -depth 1 -regex '.*(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING|COPYING.LIB|LICENSE|NEWS|README|RELEASE|TODO|VERSION)') ${dest} || exit
} # end DocCopy_

function BuildDevel_ {
    test -n "$1" || exit
    
    cd ${workdir} &&
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
    
    make ${jn} &&
    make install &&
    DocCopy_ $1 || exit
    popd
} # end BuildDevel_

# begin stage 1
: && {
    # readline is required from unixODBC
    BuildDeps_ readline-6.2.tar.gz --with-curses && DocCopy_ readline-6.2
    BuildDeps_ m4-1.4.16.tar.bz2 --program-prefix=g && {
    export M4=${deps_destroot}/bin/gm4
    }
    BuildDeps_ autoconf-2.69.tar.gz
    BuildDeps_ automake-1.13.1.tar.gz
    BuildDeps_ libtool-2.4.2.tar.gz --program-prefix=g && {
        export LIBTOOL=${deps_destroot}/bin/glibtool
        export LIBTOOLIZE=${deps_destroot}/bin/glibtoolize
    }
    BuildDeps_ pkg-config-0.28.tar.gz \
        --disable-debug \
        --disable-host-tool \
        --with-internal-glib \
        --with-pc-path=${deps_destroot}/lib/pkgconfig:${deps_destroot}/share/pkgconfig:/usr/lib/pkgconfig
    BuildDeps_ gettext-0.18.2.tar.gz
    # m4 required gettext
    BuildDeps_ xz-5.0.4.tar.bz2
    BuildDevel_ libffi
} # end stage 1

# begin stage 1+
: && {
    BuildDevel_ glib
    BuildDevel_ freetype
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
    # nasm is required from libjpeg-turbo
    BuildDeps_ nasm-2.10.07.tar.xz && DocCopy_ nasm-2.10.07
    BuildDeps_ libjpeg-turbo-1.2.1.tar.gz --with-jpeg8 && {
        install -d ${deps_destroot}/share/doc/libjpeg-turbo-1.2.1
        mv ${deps_destroot}/share/doc/{example.c,libjpeg.txt,README,README-turbo.txt,structure.txt,usage.txt,wizard.txt} $_
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
    (
        cd ${workdir} &&
        tar -xf ${srcroot}/source/cabextract-1.4.tar.gz &&
        cd cabextract-1.4 &&
        ./configure ${configure_args/${deps_destroot}/${wine_destroot}} &&
        make ${jn} &&
        make install &&
        DocCopy_ cabextract-1.4
    ) || exit
    
    # winetricks
    install -d ${wine_destroot}/share/doc/winetricks &&
    install -m 0644 ${srcroot}/source/winetricks/src/COPYING $_ &&
    install -m 0755 ${srcroot}/source/winetricks/src/winetricks ${wine_destroot}/bin/winetricks.bin &&
    cat <<'__EOF__' > ${wine_destroot}/bin/winetricks && chmod +x ${wine_destroot}/bin/winetricks || exit
#!/bin/bash
export PATH="$(cd "$(dirname "$0")"; pwd)":/usr/bin:/bin:/usr/sbin:/sbin
which wine || { echo "wine not found."; exit; }
exec winetricks.bin "$@"
__EOF__
} # end stage 4



ditto ${srcroot}/source/wine wine && (
    cd wine &&
    ./configure \
        --prefix=${wine_destroot} \
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
    
    # add rpath to ${deps_destroot} and /usr/lib
    for x in \
        bin/wine \
        bin/wineserver \
        lib/libwine.1.0.dylib
    do
        install_name_tool -add_rpath ${deps_destroot}/lib   ${wine_destroot}/${x} &&
        install_name_tool -add_rpath /usr/lib               ${wine_destroot}/${x} || exit
    done
    unset x
    
    # WINELOADER
    mv ${wine_destroot}/bin/wine{,.bin} &&
    cat <<__EOF__ > ${wine_destroot}/bin/wine && chmod +x ${wine_destroot}/bin/wine
#!/bin/bash
install -d ${destroot}
ln -sf "\$(cd "\$(dirname "\$0")/../.." && pwd)" ${destroot}
exec ${wine_destroot}/bin/wine "\$@"
__EOF__

    # copy documents
    DocCopy_ wine
    
    # wine.inf
    inf=${wine_destroot}/share/wine/wine.inf
    mv ${inf}{,.orig}
    ${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${inf}{,.orig} &&
    patch ${inf} ${srcroot}/patch/nxwine.patch || exit
    
    # native dlls
    fakedlls_dir=${wine_destroot}/lib/wine/fakedlls
    nativedlls_dir=${srcroot}/nativedlls
    mv ${fakedlls_dir}/quartz.dll{,.orig} &&
    install -m 0644 ${nativedlls_dir}/quartz.dll ${fakedlls_dir} &&
    mv ${fakedlls_dir}/gdiplus.dll{,.orig} &&
    install -m 0644 ${nativedlls_dir}/FL_gdiplus_dll_____X86.3643236F_FC70_11D3_A536_0090278A1BB8 ${fakedlls_dir}/gdiplus.dll || exit
) || exit



wine_version=$(${wine_destroot}/bin/wine --version)
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
ln -s /Applications ${destroot} &&
hdiutil create -format UDBZ -srcdir ${destroot} -volname NXWine ${dmg}

:
afplay /System/Library/Sounds/Hero.aiff
