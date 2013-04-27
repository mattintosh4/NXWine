#!/bin/bash -x

uuid=9C727687-28A1-47CE-9C4A-97128FADE79A
srcroot="$(cd "$(dirname "$0")"; pwd)"
bundle=/Applications/NXWine.app
prefix=${bundle}/Contents/Resources

git_dir=/usr/local/git/bin
python_dir=/Library/Frameworks/Python.framework/Versions/2.7/bin

test -x /usr/local/bin/ccache && ccache=$_ || exit
test -x /usr/local/bin/clang && { clang=$_; clangxx="${clang} -x c++ -stdlib=libstdc++"; } || exit
test -x /usr/local/bin/make && make=$_ || exit
test -x /usr/local/bin/uconv && uconv=$_ || exit
test -x /usr/local/bin/pkg-config && {
    export PKG_CONFIG=$_
    export PKG_CONFIG_PATH=
    export PKG_CONFIG_LIBDIR=${prefix}/lib/pkgconfig:${prefix}/share/pkgconfig:/usr/lib/pkgconfig
} || exit

function BuildBundle_ {
    test ! -e ${bundle} || rm -rf ${bundle}
    sed "s|@DATE@|$(date +%F)|g" ${srcroot}/NXWine.applescript | osacompile -o ${bundle} || exit
    rm ${bundle}/Contents/Resources/droplet.icns
    install -d ${prefix}/{bin,include,lib} || exit
}

export PATH=${prefix}/bin:${git_dir}:${python_dir}:$(sysctl -n user.cs_path)
export ARCHFLAGS="-arch i386"
export CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)"
export CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)"
export CFLAGS="-pipe -O3 -march=core2 -mtune=core2 -mmacosx-version-min=10.6.8 -isysroot ${sdkroot=/Developer/SDKs/MacOSX10.6.sdk}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-I${prefix}/include"
export LDFLAGS="-Wl,-syslibroot,${sdkroot} -L${prefix}/lib"
jn="-j $(($(sysctl -n hw.ncpu) + 1))"
configure_args="--build=i386-apple-darwin10 --prefix=${prefix} --enable-shared"

case 0 in
    0)
        BuildBundle_
        readonly workdir=$(mktemp -dt $$)
    ;;
    1)  # test mode
        test -e ${bundle} || BuildBundle_
        readonly workdir=${TMPDIR}${uuid}
        install -d ${workdir} &&
        : trap "rm -rf ${workdir}" EXIT 0
    ;;
esac


cd ${workdir} || exit


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
    ./configure ${configure_args} "$@" &&
    ${make} ${jn} &&
    ${make} install || exit
    popd
} # end BuildDeps_

function DocCopy_ {
    test -n "$1" || exit
    local dest=${prefix}/share/doc/$1
    install -d ${dest} &&
    cp $(find -E ${workdir}/$1 -depth 1 -regex '.*(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING|COPYING.LIB|LICENSE|NEWS|README|RELEASE|TODO)') ${dest} || exit
} # end DocCopy_



# begin stage 1
: && {
    BuildDeps_ gettext-0.18.2{.tar.gz,}
    BuildDeps_ xz-5.0.4{.tar.bz2,}

    ditto ${srcroot}/source/libffi libffi && (
        cd libffi &&
        git checkout -f . &&
        ./configure ${configure_args} &&
        ${make} ${jn} &&
        ${make} install &&
        DocCopy_ libffi
    )
    
    # begin glib
    : && {
        ditto ${srcroot}/source/glib glib && (
            cd glib &&
            git checkout -f glib-2-36 &&
            (bash --login ./autogen.sh --disable-maintainer-mode --disable-gtk-doc) &&
            ${make} clean &&
            ./configure ${configure_args} &&
            ${make} ${jn} &&
            ${make} install &&
            DocCopy_ glib
        ) || exit
    } # end glib
} # end stage 1

# stage 2
: && {
    ditto ${srcroot}/source/freetype2 freetype2 && (
        cd freetype2 &&
        git checkout -f . &&
        (bash --login ./autogen.sh) &&
        ./configure ${configure_args} &&
        ${make} ${jn} &&
        ${make} install &&
        DocCopy_ freetype2
    ) || exit
    
    # valgrind add '-arch' flag
    BuildDeps_ valgrind-3.8.1{.tar.bz2,} \
        --enable-only32bit \
        CC=$( xcrun -find gcc-4.2) \
        CXX=$(xcrun -find g++-4.2) \
        CFLAGS="-isysroot ${sdkroot}" \
        CXXFLAGS="-isysroot ${sdkroot}"
    
    # orc required valgrind; to build with gcc failed
    BuildDeps_ orc-0.4.17{.tar.gz,} \
        CC="${ccache} ${clang}" \
        CXX="${ccache} ${clangxx}" \
        CFLAGS="-m32 -arch i386 ${CFLAGS}" \
        CXXFLAGS="-m32 -arch i386 ${CFLAGS}"
    
    BuildDeps_ unixODBC-2.3.1{.tar.gz,} && DocCopy_ unixODBC-2.3.1
    
    ditto ${srcroot}/source/libpng libpng && (
        cd libpng &&
        git checkout -f libpng16 &&
        (bash --login autoreconf -i) &&
        ./configure ${configure_args} &&
        ${make} ${jn} &&
        ${make} install &&
        DocCopy_ libpng
    ) || exit
    
    BuildDeps_ jpegsrc.v8d.tar.gz jpeg-8d
    BuildDeps_ tiff-4.0.3{.tar.gz,}
    BuildDeps_ jasper-1.900.1{.zip,} --disable-opengl --without-x
    BuildDeps_ libicns-0.8.1{.tar.gz,}
} # end stage 2

# begin stage 3
: && {
    BuildDeps_ libogg-1.3.0{.tar.gz,}
    BuildDeps_ libvorbis-1.3.3{.tar.gz,}
    BuildDeps_ flac-1.2.1{.tar.gz,} --disable-asm-optimizations --disable-xmms-plugin    
    BuildDeps_ SDL-1.2.15{.tar.gz,} --without-x && DocCopy_ SDL-1.2.15
    BuildDeps_ SDL_sound-1.0.3{.tar.gz,}        && DocCopy_ SDL_sound-1.0.3
    # libtheora required SDL
    BuildDeps_ libtheora-1.1.1{.tar.bz2,} \
        --disable-oggtest \
        --disable-vorbistest \
        --disable-examples \
        --disable-asm
} # end stage 3

# begin stage 4
: && {
    BuildDeps_ cabextract-1.4{.tar.gz,} && DocCopy_ cabextract-1.4
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
}


install -d wine && (
    cd wine &&
    ${srcroot}/source/wine/configure \
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
    ${make} install &&
) || exit

DocCopy_ wine

install_name_tool -add_rpath /usr/lib ${prefix}/bin/wine &&
install_name_tool -add_rpath /usr/lib ${prefix}/bin/wineserver &&
install_name_tool -add_rpath /usr/lib ${prefix}/lib/libwine.1.0.dylib || exit

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
