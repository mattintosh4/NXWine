#!/usr/bin/env - LC_ALL=C SHELL=/bin/bash TERM=xterm-color HOME=/tmp /bin/bash -ex

readonly build_version=$(date +%Y%m%d)
readonly domain=com.github.mattintosh4

readonly origin="$(cd "$(dirname "$0")"; pwd)"
readonly srcroot=${origin}/source
readonly workroot=/tmp/E43FF9C9-669C-4319-8351-FF99AFF3230C
readonly destroot=/Applications/NXWine.app
readonly wine_destroot=${destroot}/Contents/Resources
readonly deps_destroot=${destroot}/Contents/SharedSupport

# -------------------------------------- local tools
readonly ccache=/usr/local/bin/ccache
readonly uconv=/usr/local/bin/uconv
readonly git=/usr/local/git/bin/git
readonly sevenzip=/usr/local/bin/7z
export PKG_CONFIG=/usr/local/bin/pkg-config
export PKG_CONFIG_LIBDIR=${deps_destroot}/lib/pkgconfig:${deps_destroot}/share/pkgconfig:/usr/lib/pkgconfig
test -x ${ccache}
test -x ${uconv}
test -x ${git}
test -x ${sevenzip}
test -x ${PKG_CONFIG}

# -------------------------------------- Xcode
export MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f-2)
export DEVELOPER_DIR=$(xcode-select -print-path)
export SDKROOT=$(xcodebuild -version -sdk macosx${MACOSX_DEPLOYMENT_TARGET} | sed -n '/^Path/{;s/^Path: //;p;}')
test -n "${MACOSX_DEPLOYMENT_TARGET}"
test -d "${DEVELOPER_DIR}"
test -d "${SDKROOT}"

# -------------------------------------- envs
PATH=$(/usr/sbin/sysctl -n user.cs_path):${DEVELOPER_DIR}/bin:${DEVELOPER_DIR}/sbin
PATH=$(dirname ${git}):$PATH
PATH=${deps_destroot}/bin:${workroot}/bin:$PATH
export PATH
export CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)"
export CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)"
export CFLAGS="-pipe -m32 -O3 -march=core2 -mtune=core2 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-isysroot ${SDKROOT} -I${deps_destroot}/include"
export LDFLAGS="-Wl,-syslibroot,${SDKROOT} -L${deps_destroot}/lib"

triple=i686-apple-darwin$(uname -r)
configure_args="\
--prefix=${deps_destroot} \
--build=${triple} \
--enable-shared \
--disable-debug \
--disable-maintainer-mode \
--disable-dependency-tracking \
--without-x"
make_args="-j $(($(sysctl -n hw.ncpu) + 2))"

# -------------------------------------- package source
## bootstrap
pkgsrc_autoconf=autoconf-2.69.tar.gz
pkgsrc_automake=automake-1.13.2.tar.gz
pkgsrc_coreutils=coreutils-8.21.tar.bz2
pkgsrc_gettext=gettext-0.18.2.tar.gz
pkgsrc_libtool=libtool-2.4.2.tar.gz
pkgsrc_libelf=libelf-0.8.13.tar.gz
pkgsrc_m4=m4-1.4.16.tar.bz2
pkgsrc_readline=readline-master.tar.gz
pkgsrc_tar=tar-1.26.tar.gz
pkgsrc_xz=xz-5.0.4.tar.bz2
## stage 1
pkgsrc_gmp=gmp-5.1.2.tar.xz
pkgsrc_gnutls=gnutls-3.1.8.tar.xz
pkgsrc_libtasn1=libtasn1-3.3.tar.gz
pkgsrc_nettle=nettle-2.7.tar.gz
pkgsrc_usb=libusb-1.0.9.tar.bz2
pkgsrc_usbcompat=libusb-compat-0.1.4.tar.bz2
## stage 2
pkgsrc_glib=glib-2.36.2.tar.xz
## stage 3
pkgsrc_icns=libicns-0.8.1.tar.gz
pkgsrc_jasper=jasper-1.900.1.tar.bz2
pkgsrc_nasm=nasm-2.10.07.tar.xz
pkgsrc_odbc=unixODBC-2.3.1.tar.gz
pkgsrc_tiff=tiff-4.0.3.tar.gz
## stage 4
pkgsrc_flac=flac-1.2.1.tar.gz
pkgsrc_ogg=libogg-1.3.0.tar.gz
pkgsrc_sdl=SDL-1.2.15.tar.gz
pkgsrc_sdlsound=SDL_sound-1.0.3.tar.gz
pkgsrc_theora=libtheora-1.1.1.tar.bz2
pkgsrc_vorbis=libvorbis-1.3.3.tar.gz
## stage 5
pkgsrc_7z=7z920.exe

# -------------------------------------- begin utilities functions
DocCopy_ ()
{
    test -n "$1"
    local d=${deps_destroot}/share/doc/$1
    install -d ${d}
    find -E ${workroot}/$1 -maxdepth 1 -type f -regex '.*/(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING(.LIB)?|LICENSE|NEWS|README|RELEASE|TODO|VERSION)' | while read
    do
        cp "${REPLY}" ${d}
    done
} # end DocCopy_

# -------------------------------------- begin build processing functions
BuildDeps_ ()
{
    (($# != 0)) || { echo "Invalid argment."; exit 1; }
    local n=$1
    shift
    $(which tar) xf ${srcroot}/${n} -C ${workroot}
    cd ${workroot}/$(echo ${n} | sed -E 's#\.(zip|tbz2?|tgz|tar\..*)$##')
    case ${n} in
        coreutils-*|\
        m4-*|\
        autoconf-*|\
        automake-*|\
        libtool-*)
            ./configure --prefix=${workroot} \
                        --build=x86_64-apple-darwin$(uname -r) \
                        "$@" \
                        CC="${ccache} $( xcrun -find gcc-4.2)" \
                        CXX="${ccache} $(xcrun -find g++-4.2)" \
                        CFLAGS= \
                        CXXFLAGS=
        ;;
        *)
            ./configure ${configure_args} "$@"
        ;;
    esac
    make ${make_args}
    make install
} # end BuildDeps_

BuildDevel_ ()
{
    if
        test -n "$1" &&
        test -d ${srcroot}/$1
    then :
    else
        echo "Invalid argment or directory does not exist."
        exit 1
    fi
    ditto {${srcroot},${workroot}}/$1
    cd $_
    case $1 in
        freetype)
            git checkout -f master
            ./autogen.sh
            ./configure ${configure_args}
        ;;
        glib)
            git checkout -f glib-2-36
            ./autogen.sh ${configure_args} --disable-{gtk-doc{,-html,-pdf},selinux,fam,xattr,libelf} --with-threads=posix --without-{html-dir,xml-catalog}
        ;;
        libffi)
            git checkout -f master
            ./configure ${configure_args}
        ;;
        libjpeg-turbo)
            git checkout -f master
            autoreconf -i
            ./configure ${configure_args} --with-jpeg8
        ;;
        libpng)
            git checkout -f libpng15
            autoreconf -i
            ./configure ${configure_args}
        ;;
        orc)
            git checkout -f master
            ./autogen.sh ${configure_args} --disable-gtk-doc{,-html,-pdf} --without-html-dir
        ;;
    esac
    make ${make_args}
    make install
    DocCopy_ $1
} # end BuildDevel_

Bootstrap_ ()
{
    # -------------------------------------- begin preparing
    ### source check ###
    for x in ${!pkgsrc_*}
    do
        echo -n "checking ${!x} ... "
        [ -f ${srcroot}/${!x} ] && echo "yes" || { echo "no"; exit 1; }
    done
    
    ### clean up ###
    rm -rf ${workroot} ${destroot}
    
    sed "s|@DATE@|$(date +%F)|g" ${origin}/NXWine.applescript | osacompile -o ${destroot}
    install -m 0644 ${origin}/nxwine.icns ${destroot}/Contents/Resources/droplet.icns
    
    ### directory installation ###
    install -d  ${deps_destroot}/{bin,include,share/man} \
                ${wine_destroot}/lib \
                ${workroot}/bin
    (
        cd ${deps_destroot}
        ln -s ../Resources/lib lib
        ln -s share/man man
    )
    
    # -------------------------------------- begin build
    {
        tar xf ${srcroot}/${pkgsrc_tar} -C ${workroot}
        cd ${workroot}/${pkgsrc_tar%.tar.*}
        ./configure --prefix=${workroot} \
                    --build=x86_64-apple-darwin$(uname -r) \
                    --disable-nls \
                    CC="${ccache} $( xcrun -find gcc-4.2)" CFLAGS=
        make ${make_args}
        make install
        cd -
    }
    BuildDeps_  ${pkgsrc_coreutils} --program-prefix=g --enable-threads=posix --disable-nls --without-gmp
    (
        cd ${workroot}/bin
        ln -s {g,}readlink
    )
    BuildDeps_  ${pkgsrc_readline} --with-curses --enable-multibyte
    BuildDeps_  ${pkgsrc_m4} --program-prefix=g
    (
        cd ${workroot}/bin
        ln -s {g,}m4
        ./m4 --version &>/dev/null
    )
    BuildDeps_  ${pkgsrc_autoconf}
    (
        cd ${workroot}/bin
        for x in auto{conf,header,m4te,reconf,scan,update} ifnames ; do ln ${x} ${x}-2.69 ; done
    )
    BuildDeps_  ${pkgsrc_automake}
    BuildDeps_  ${pkgsrc_libtool} --program-prefix=g
    (
        cd ${workroot}/bin
        ln -s {g,}libtool
        ln -s {g,}libtoolize
        ./libtool       --version &>/dev/null
        ./libtoolize    --version &>/dev/null
    )
    BuildDeps_  ${pkgsrc_gettext} --enable-threads=posix --without-emacs
    BuildDeps_  ${pkgsrc_libelf} --disable-compat
    BuildDeps_  ${pkgsrc_xz}
} # end Bootstrap_

BuildStage1_ ()
{
    {
        $(which tar) xf ${srcroot}/${pkgsrc_gmp} -C ${workroot}
        cd ${workroot}/${pkgsrc_gmp%.tar.*}
        ./configure ${configure_args} ABI=32 CC=$(xcrun -find gcc-4.2) CXX=$(xcrun -find g++-4.2)
        make ${make_args}
        make check
        make install
        cd -
    }
    BuildDeps_  ${pkgsrc_libtasn1}
    BuildDeps_  ${pkgsrc_nettle}
    BuildDeps_  ${pkgsrc_gnutls} --disable-guile --without-p11-kit
    BuildDeps_  ${pkgsrc_usb}
    BuildDeps_  ${pkgsrc_usbcompat}
} # end BuildStage1_

BuildStage2_ ()
{
    BuildDevel_ libffi
#    BuildDevel_ glib
    BuildDeps_  ${pkgsrc_glib} --disable-{gtk-doc{,-html,-pdf},selinux,fam,xattr,libelf} --with-threads=posix --without-{html-dir,xml-catalog}
    BuildDevel_ freetype
    [ -f ${deps_destroot}/lib/libfreetype.6.dylib ]
} # end BuildStage2_

BuildStage3_ ()
{
    BuildDevel_ orc
    BuildDeps_  ${pkgsrc_odbc}
    BuildDevel_ libpng
    BuildDeps_  ${pkgsrc_nasm}
    BuildDevel_ libjpeg-turbo
    BuildDeps_  ${pkgsrc_tiff}
    BuildDeps_  ${pkgsrc_jasper} --disable-opengl --without-x
    BuildDeps_  ${pkgsrc_icns}
} # end BuildStage3_

BuildStage4_ ()
{
    BuildDeps_  ${pkgsrc_ogg}
    BuildDeps_  ${pkgsrc_vorbis}
    BuildDeps_  ${pkgsrc_flac} --disable-{asm-optimizations,xmms-plugin}
    ## SDL required nasm
    BuildDeps_  ${pkgsrc_sdl}
    BuildDeps_  ${pkgsrc_sdlsound}
    ## libtheora required SDL
    BuildDeps_  ${pkgsrc_theora} --disable-{oggtest,vorbistest,examples,asm}
} # end BuildStage4_

BuildStage5_ ()
{
    # -------------------------------------- begin cabextract
    $(which tar) -xf ${srcroot}/cabextract-1.4.tar.gz -C ${workroot}
    (
        cd ${workroot}/cabextract-1.4
        ./configure ${configure_args/${deps_destroot}/${wine_destroot}}
        make ${make_args}
        make install
        install -d ${wine_destroot}/share/doc/cabextract-1.4
        cp AUTHORS ChangeLog COPYING NEWS README TODO $_
    )
    
    # -------------------------------------- begin winetricks
    ditto {${srcroot}/winetricks/src,${wine_destroot}/share/doc/winetricks}/COPYING
    install -m 0755 ${srcroot}/winetricks/src/winetricks ${wine_destroot}/bin/winetricks.bin
    winetricks=${wine_destroot}/bin/winetricks
    touch ${winetricks}
    chmod +x ${winetricks}
    cat <<__EOF__ > ${winetricks}
#!/bin/bash
export PATH=${wine_destroot}/bin:$(sysctl -n user.cs_path)
which wine || { echo "wine not found."; exit 1; }
exec winetricks.bin "\$@"
__EOF__
    
    # ------------------------------------- 7-Zip
    ${sevenzip} x -o${wine_destroot}/lib/wine/programs/7-Zip -x'!$*' ${srcroot}/${pkgsrc_7z}
} # end BuildStage5_

BuildWine_ ()
{
    install -d ${workroot}/wine
    cd $_
    ${srcroot}/wine/configure   --prefix=${wine_destroot} --build=${triple} \
                                --without-{capi,cms,gphoto,gsm,oss,sane,v4l} \
                                CPPFLAGS="${CPPFLAGS} -I/opt/X11/include" \
                                LDFLAGS="${LDFLAGS} -L/opt/X11/lib"
    make ${make_args}
    make install
    
    ### install name ###
    install_name_tool -add_rpath /usr/lib ${wine_destroot}/bin/wine
    install_name_tool -add_rpath /usr/lib ${wine_destroot}/bin/wineserver
    install_name_tool -add_rpath /usr/lib ${wine_destroot}/lib/libwine.1.0.dylib
    
    ### mono and gecko ###
    ditto {${srcroot},${wine_destroot}/share/wine/mono}/wine-mono-0.0.8.msi
    ditto {${srcroot},${wine_destroot}/share/wine/gecko}/wine_gecko-2.21-x86.msi
    
    ### docs ###
    install -d ${wine_destroot}/share/doc/wine
    cp ${srcroot}/wine/{ANNOUNCE,AUTHORS,COPYING.LIB,LICENSE,README,VERSION} $_
    
    ### fonts ###
    cp  ${srcroot}/Konatu_ver_20121218/*.ttf \
        ${srcroot}/opfc-ModuleHP-1.1.1_withIPAMonaFonts-1.0.8/fonts/*.ttf \
        ${wine_destroot}/share/wine/fonts
    
    ### inf ###
    local inf=${wine_destroot}/share/wine/wine.inf
    local inftmp=$(mktemp -t XXXXXX)
    mv ${inf}{,.orig}
    cat <<'__EOS__' | cat ${inf}.orig /dev/fd/3 3<&0 > ${inftmp}

;; added by NXWine ;;

[Fonts]
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Microsoft Sans Serif",,"KonatuTohaba.ttf"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Sans Serif",,"KonatuTohaba.ttf"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Gothic",,"KonatuTohaba.ttf"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS PGothic",,"Konatu.ttf"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Serif",,"ipam-mona.ttf"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Mincho",,"ipam-mona.ttf"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS PMincho",,"ipamp-mona.ttf"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Tahoma",,"Konatu.ttf"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Verdana",,"Konatu.ttf"

HKCU,Software\Wine\Fonts\Replacements,"MS UI Gothic",,"小夏"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ ゴシック",,"小夏 等幅"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐゴシック",,"小夏"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ 明朝",,"IPA モナー 明朝"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐ明朝",,"IPA モナー P明朝"

;; Mouse ;;
HKCU,Control Panel\Mouse,"DoubleClickHeight",,"8"
HKCU,Control Panel\Mouse,"DoubleClickWidth",,"8"
__EOS__
    ${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${inf} ${inftmp}
    
    # -------------------------------------- wine loader
    install -d ${wine_destroot}/libexec
    mv ${wine_destroot}/{bin,libexec}/wine
    install -m 0755 ${origin}/wineloader.in ${wine_destroot}/bin/wine
    sed -i "" "s|@DATE@|$(date +%F)|g" ${wine_destroot}/bin/wine
    
    ### native dlls ###
    install -d ${wine_destroot}/lib/wine/nativedlls
    cp ${origin}/nativedlls/* $_
    
    ### update plist ###
    iconfile=droplet
    wine_version="$(${wine_destroot}/bin/wine --version)"
    test "${wine_version}"
    
    while read
    do
        /usr/libexec/PlistBuddy -c "${REPLY}" ${destroot}/Contents/Info.plist
    done <<__EOS__
Set :CFBundleIconFile ${iconfile}
Add :NSHumanReadableCopyright string ${wine_version}, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine
Add :CFBundleVersion string ${build_version}
Add :CFBundleIdentifier string ${domain}.NXWine
Add :CFBundleDocumentTypes:1:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:1:CFBundleTypeExtensions:0 string exe
Add :CFBundleDocumentTypes:1:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:1:CFBundleTypeName string Windows Executable File
Add :CFBundleDocumentTypes:1:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:2:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:2:CFBundleTypeExtensions:0 string msi
Add :CFBundleDocumentTypes:2:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:2:CFBundleTypeName string Microsoft Windows Installer
Add :CFBundleDocumentTypes:2:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:3:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:3:CFBundleTypeExtensions:0 string lnk
Add :CFBundleDocumentTypes:3:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:3:CFBundleTypeName string Windows Shortcut File
Add :CFBundleDocumentTypes:3:CFBundleTypeRole string Viewer
__EOS__

} # end BuildWine_

BuildDmg_ ()
{
    local dmg=${origin}/NXWine_${build_version}_${wine_version/wine-}.dmg
    local srcdir=$(mktemp -dt XXXXXX)
    
    test ! -f ${dmg} || rm ${dmg}
    mv ${destroot} ${srcdir}
    ln -s /Applications ${srcdir}
    
    install -d ${srcdir}/sources
    cp ${srcroot}/opfc-ModuleHP-1.1.1_withIPAMonaFonts-1.0.8.tar.gz ${srcdir}/sources
    
    hdiutil create -format UDBZ -srcdir ${srcdir} -volname NXWine ${dmg}
    rm -rf ${srcdir}
} # end BuildDmg_

# -------------------------------------- begin processing section
Bootstrap_
BuildStage1_
BuildStage2_
BuildStage3_
BuildStage4_
BuildStage5_
BuildWine_
BuildDmg_

# -------------------------------------- end processing section

:
afplay /System/Library/Sounds/Hero.aiff
