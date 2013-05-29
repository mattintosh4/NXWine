#!/usr/bin/env - LC_ALL=C SHELL=/bin/bash TERM=xterm-color HOME=/tmp /bin/bash -ex

readonly proj_name=NXWine
readonly proj_uuid=E43FF9C9-669C-4319-8351-FF99AFF3230C
readonly proj_root="$(cd "$(dirname "$0")"; pwd)"
readonly proj_version=$(date +%Y%m%d)
readonly proj_domain=com.github.mattintosh4

readonly gnutoolbundle=${proj_root}/gnu-tools.sparsebundle
readonly gnuprefix=/Volumes/${proj_uuid}

readonly srcroot=${proj_root}/source
readonly workroot=/tmp/${proj_uuid}
readonly destroot=/Applications/${proj_name}.app
readonly wine_destroot=${destroot}/Contents/Resources
readonly deps_destroot=${destroot}/Contents/SharedSupport

# -------------------------------------- local tools
readonly ccache=/usr/local/bin/ccache
readonly uconv=/usr/local/bin/uconv
readonly git=/usr/local/git/bin/git
readonly sevenzip=/usr/local/bin/7z
test -x ${ccache}
test -x ${uconv}
test -x ${git}
test -x ${sevenzip}

if [ -x ${FONTFORGE=/opt/local/bin/fontforge} ]; then export FONTFORGE; fi

# -------------------------------------- Xcode
export MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f-2)
export DEVELOPER_DIR=$(xcode-select -print-path)
export SDKROOT=$(xcodebuild -version -sdk macosx${MACOSX_DEPLOYMENT_TARGET} | sed -n '/^Path: /{;s/^Path: //;p;}')
test -n "${MACOSX_DEPLOYMENT_TARGET}"
test -d "${DEVELOPER_DIR}"
test -d "${SDKROOT}"

# -------------------------------------- envs
PATH=$(/usr/sbin/sysctl -n user.cs_path)
PATH=$(dirname ${git}):$PATH
PATH=${deps_destroot}/bin:${gnuprefix}/bin:$PATH
export PATH
export CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)"
export CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)"
export CFLAGS="-pipe -m32 -O3 -march=core2 -mtune=core2 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-isysroot ${SDKROOT} -I${deps_destroot}/include"
export CPATH=${SDKROOT}/include/sys
export LDFLAGS="-Wl,-syslibroot,${SDKROOT} -L${deps_destroot}/lib"
export ACLOCAL_PATH=${deps_destroot}/share/aclocal

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
## gnutools
pkgsrc_autoconf=autoconf-2.69.tar.gz
pkgsrc_automake=automake-1.13.2.tar.gz
pkgsrc_coreutils=coreutils-8.21.tar.bz2
pkgsrc_libtool=libtool-2.4.2.tar.gz
pkgsrc_m4=m4-1.4.16.tar.bz2
## bootstrap
pkgsrc_gettext=gettext-0.18.2.tar.gz
pkgsrc_libelf=libelf-0.8.13.tar.gz
pkgsrc_ncurses=ncurses-5.9.tar.gz
pkgsrc_readline=readline-master.tar.gz
pkgsrc_tar=tar-1.26.tar.gz
pkgsrc_xz=xz-5.0.4.tar.bz2
pkgsrc_zlib=zlib-1.2.8.tar.gz
## stage 1
pkgsrc_gmp=gmp-5.1.2.tar.xz
pkgsrc_gnutls=gnutls-3.1.8.tar.xz
pkgsrc_libtasn1=libtasn1-3.3.tar.gz
pkgsrc_nettle=nettle-2.7.tar.gz
pkgsrc_usb=libusb-1.0.9.tar.bz2
pkgsrc_usbcompat=libusb-compat-0.1.4.tar.bz2
## stage 2
pkgsrc_glib=glib-2.37.1.tar.xz
## stage 3
pkgsrc_icns=libicns-0.8.1.tar.gz
pkgsrc_jasper=jasper-1.900.1.tar.bz2
pkgsrc_nasm=nasm-2.10.07.tar.xz
pkgsrc_odbc=unixODBC-2.3.1.tar.gz
pkgsrc_tiff=tiff-4.0.3.tar.gz
## stage 4
pkgsrc_flac=flac-1.2.1.tar.gz
pkgsrc_ogg=libogg-1.3.1.tar.xz
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
    test -n "$1" || { echo "Invalid argment."; exit 1; }
    local n=$1
    shift
    $(which gnutar) xf ${srcroot}/${n} -C ${workroot}
    cd ${workroot}/$(echo ${n} | sed -E 's#\.(zip|tbz2?|tgz|tar\..*)$##')
    case ${n} in
        tar-*|\
        coreutils-*|\
        m4-*|\
        autoconf-*|\
        automake-*)
            ./configure ${configure_args/${deps_destroot}/${gnuprefix}} "$@"
        ;;
        zlib-*)
            ./configure --prefix=${deps_destroot}
        ;;
        *)
            ./configure ${configure_args} "$@"
        ;;
    esac
    make ${make_args}
    make install
    cd -
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
        fontconfig)
            git checkout -f master
            ./autogen.sh ${configure_args} --with-add-fonts=/Library/Fonts,~/Library/Fonts
        ;;
        freetype)
            git checkout -f master
            ./autogen.sh
            ./configure ${configure_args}
        ;;
        glib)
            git checkout -f glib-2-36
            ./autogen.sh ${configure_args} --disable-{gtk-doc{,-html,-pdf},selinux,fam,xattr} --with-threads=posix --without-{html-dir,xml-catalog}
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
        pkg-config)
            git checkout -f master
            ./autogen.sh ${configure_args}  --disable-host-tool \
                                            --with-internal-glib \
                                            --with-pc-path=${deps_destroot}/lib/pkgconfig:${deps_destroot}/share/pkgconfig:/usr/lib/pkgconfig
        ;;
        python) # Python 2.7
            ./configure ${configure_args}
        ;;
        libxml2)
            git checkout -f master
            ./autogen.sh ${configure_args}
        ;;
        libxslt)
            git checkout -f master
            ./autogen.sh ${configure_args}
        ;;
    esac
    make ${make_args}
    make install
    DocCopy_ $1
    cd -
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
    
    sed "s|@DATE@|$(date +%F)|g" ${proj_root}/main.applescript | osacompile -o ${destroot}
    install -m 0644 ${proj_root}/nxwine.icns ${destroot}/Contents/Resources/droplet.icns
    
    ### directory installation ###
    install -d  ${deps_destroot}/{bin,include,share/man} \
                ${wine_destroot}/lib \
                ${workroot}
    (
        cd ${deps_destroot}
        ln -s ../Resources/lib lib
        ln -s share/man man
    )
    
    # -------------------------------------- begin tools build
    if [ -e ${gnutoolbundle} ]
    then
        hdiutil attach ${gnutoolbundle}
    else
        hdiutil create -type SPARSEBUNDLE -fs HFS+ -size 1g -volname ${proj_uuid} ${gnutoolbundle}
        hdiutil attach ${gnutoolbundle}
        
        BuildDeps_  ${pkgsrc_tar} --program-prefix=gnu --disable-nls
        BuildDeps_  ${pkgsrc_coreutils} --program-prefix=g --enable-threads=posix --disable-nls --without-gmp
        {
            cd ${gnuprefix}/bin
            ln -s {g,}readlink
            cd -
        }
        BuildDeps_  ${pkgsrc_m4} --program-prefix=g
        {
            cd ${gnuprefix}/bin
            ln -s {g,}m4
            cd -
        }
        BuildDeps_  ${pkgsrc_autoconf}
        BuildDeps_  ${pkgsrc_automake}
    fi
    trap "hdiutil detach ${gnuprefix}" EXIT
    
    # --------------------------------- begin build
    BuildGettext_ ()
    {
        BuildDeps_ ${pkgsrc_gettext}    --disable-{csharp,native-java,openmp} \
                                        --without-{emacs,git,cvs} \
                                        --with-included-{gettext,glib,libcroro,libunistring,libxml}
    }
    BuildGettext_
    BuildDeps_  ${pkgsrc_libtool} --program-prefix=g
    {
        cd ${deps_destroot}/bin
        ln -s {g,}libtool
        ln -s {g,}libtoolize
        cd -
    }
    BuildDevel_ pkg-config
    BuildDeps_  ${pkgsrc_ncurses}   --enable-{pc-files,sigwinch} \
                                    --disable-mixed-case \
                                    --with-shared \
                                    --without-{ada,debug,manpages,tests}
    BuildDeps_  ${pkgsrc_readline} --with-curses --enable-multibyte
    BuildDeps_  ${pkgsrc_zlib}
    BuildGettext_
    BuildDeps_  ${pkgsrc_libelf} --disable-compat
    BuildDeps_  ${pkgsrc_xz}
    BuildDevel_ python
    BuildDevel_ libxml2
    BuildDevel_ libxslt
} # end Bootstrap_

BuildStage1_ ()
{
    {
        $(which gnutar) xf ${srcroot}/${pkgsrc_gmp} -C ${workroot}
        cd ${workroot}/${pkgsrc_gmp%.tar.*}
        CC=$( xcrun -find gcc-4.2) \
        CXX=$(xcrun -find g++-4.2) \
        ABI=32 \
        ./configure --prefix=${deps_destroot} --build=${triple} --enable-cxx
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
    BuildDevel_ glib
#    BuildDeps_  ${pkgsrc_glib} --disable-{gtk-doc{,-html,-pdf},selinux,fam,xattr} --with-threads=posix --without-{html-dir,xml-catalog}
} # end BuildStage2_

BuildStage3_ ()
{
    BuildDevel_ orc
    BuildDeps_  ${pkgsrc_odbc}
    BuildDevel_ libpng
    BuildDevel_ freetype
    [ -f ${deps_destroot}/lib/libfreetype.6.dylib ] # freetype required libpng
    BuildDevel_ fontconfig
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
    $(which gnutar) -xf ${srcroot}/cabextract-1.4.tar.gz -C ${workroot}
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
                                LDFLAGS="${LDFLAGS} -L/opt/X11/lib" \
                                PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/opt/X11/share/pkgconfig
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
    m4 <<'__EOS__' | cat ${inf}.orig /dev/fd/3 3<&0 > ${inftmp}

;;; ----------- NXWine original section ----------- ;;;

; この行以降は NXWine 独自の初期値です。これらの初期化が不要であれば削除して下さい。
; この INF ファイルは BOM 付きの UTF-8 に変換されていますので編集の際はご注意下さい。

define(`G_FILE', `KonatuTohaba.ttf')dnl
define(`G_NAME', `Konatu Tohaba')dnl
define(`PG_FILE', `Konatu.ttf')dnl
define(`PG_NAME', `Konatu')dnl
define(`M_FILE', `ipam-mona.ttf')dnl
define(`M_NAME', `IPAMonaMincho')dnl
define(`PM_FILE', `ipamp-mona.ttf')dnl
define(`PM_NAME', `IPAMonaPMincho')dnl

;;; Japanese font settings ;;;

[Fonts]
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Microsoft Sans Serif",,"G_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Sans Serif",,"G_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Gothic",,"G_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS PGothic",,"PG_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Serif",,"M_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Mincho",,"M_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS PMincho",,"PM_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Tahoma",,"PG_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Verdana",,"PG_FILE"

HKCU,Software\Wine\Fonts\Replacements,"MS UI Gothic",,"PG_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ ゴシック",,"G_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐゴシック",,"PG_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ 明朝",,"M_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐ明朝",,"PM_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ｺﾞｼｯｸ",,"G_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ゴシック",,"G_NAME"
HKCU,Software\Wine\Fonts\Replacements,"標準ゴシック",,"G_NAME"
HKCU,Software\Wine\Fonts\Replacements,"明朝",,"M_NAME"
HKCU,Software\Wine\Fonts\Replacements,"標準明朝",,"M_NAME"


;;; Mouse ;;;

HKCU,Control Panel\Mouse,"DoubleClickHeight",,"8"
HKCU,Control Panel\Mouse,"DoubleClickWidth",,"8"

define(`_7z_class_regist', `dnl
HKCR,.$1,,2,"7-Zip.$1"
HKCR,7-Zip.$1,,2,"$1 Archive"
HKCR,7-Zip.$1\shell\open\command,,2,"""Z:\Applications\NXWine.app\Contents\Resources\lib\wine\programs\7-Zip\7zFM.exe"" ""%1"""
HKCR,7-Zip.$1\DefaultIcon,,2,"Z:\Applications\NXWine.app\Contents\Resources\lib\wine\programs\7-Zip\7z.dll,$2"')dnl

;;; 7-Zip classes ;;;

[Classes]
_7z_class_regist(7z, 0)
_7z_class_regist(lha, 6)
_7z_class_regist(lzh, 6)
_7z_class_regist(rar, 3)
_7z_class_regist(xz, 23)
_7z_class_regist(zip, 1)
__EOS__
    ${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${inf} ${inftmp}
    
    # -------------------------------------- wine loader
    install -d ${wine_destroot}/libexec
    mv ${wine_destroot}/{bin,libexec}/wine
    install -m 0755 ${proj_root}/wineloader.in ${wine_destroot}/bin/wine
    sed -i "" "s|@DATE@|$(date +%F)|g" ${wine_destroot}/bin/wine
    
    # ------------------------------------- native dlls
    install -d ${wine_destroot}/lib/wine/nativedlls
    cd $_
    install -m 0644 ${proj_root}/nativedlls/FL_gdiplus_dll_____X86.3643236F_FC70_11D3_A536_0090278A1BB8 gdiplus.dll
    ${sevenzip} x ${proj_root}/nativedlls/directx_feb2010_redist.exe dxnt.cab
    ${sevenzip} x dxnt.cab {devenum,dmband,dmcompos,dmime,dmloader,dmscript,dmstyle,dmsynth,dmusic,dplayx,dsound,dswave,quartz}.dll l3codecx.ax
    ${sevenzip} x ${proj_root}/nativedlls/directx_Jun2010_redist.exe Aug2009_d3dx9_42_x86.cab Jun2010_d3dx9_43_x86.cab
    ${sevenzip} x Aug2009_d3dx9_42_x86.cab d3dx9_42.dll
    ${sevenzip} x Jun2010_d3dx9_43_x86.cab d3dx9_43.dll
    rm *.cab
    cd -
    
    # ------------------------------------- core fonts
    for x in $(find ${proj_root}/corefonts/*.exe); do ${sevenzip} x -o${wine_destroot}/share/wine/fonts ${x} '*.TTF'; done; unset x
    
    # ------------------------------------- plist
    iconfile=droplet
    wine_version="$(${wine_destroot}/bin/wine --version)"
    test "${wine_version}"
    
    while read
    do
        /usr/libexec/PlistBuddy -c "${REPLY}" ${destroot}/Contents/Info.plist
    done <<__EOS__
Set :CFBundleIconFile ${iconfile}
Add :NSHumanReadableCopyright string ${wine_version}, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine
Add :CFBundleVersion string ${proj_version}
Add :CFBundleIdentifier string ${proj_domain}.${proj_name}
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
Add :CFBundleDocumentTypes:4:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:4:CFBundleTypeExtensions:0 string 7z
Add :CFBundleDocumentTypes:4:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:4:CFBundleTypeName string 7z Archive
Add :CFBundleDocumentTypes:4:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:5:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:5:CFBundleTypeExtensions:0 string lha
Add :CFBundleDocumentTypes:5:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:5:CFBundleTypeName string lha Archive
Add :CFBundleDocumentTypes:5:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:6:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:6:CFBundleTypeExtensions:0 string lzh
Add :CFBundleDocumentTypes:6:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:6:CFBundleTypeName string lzh Archive
Add :CFBundleDocumentTypes:6:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:7:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:7:CFBundleTypeExtensions:0 string rar
Add :CFBundleDocumentTypes:7:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:7:CFBundleTypeName string rar Archive
Add :CFBundleDocumentTypes:7:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:8:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:8:CFBundleTypeExtensions:0 string xz
Add :CFBundleDocumentTypes:8:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:8:CFBundleTypeName string xz Archive
Add :CFBundleDocumentTypes:8:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:9:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:9:CFBundleTypeExtensions:0 string zip
Add :CFBundleDocumentTypes:9:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:9:CFBundleTypeName string zip Archive
Add :CFBundleDocumentTypes:9:CFBundleTypeRole string Viewer
__EOS__

} # end BuildWine_

BuildDmg_ ()
{
    local dmg=${proj_root}/${proj_name}_${proj_version}_${wine_version/wine-}.dmg
    local srcdir=$(mktemp -dt XXXXXX)
    
    test ! -f ${dmg} || rm ${dmg}
    mv ${destroot} ${srcdir}
    ln -s /Applications ${srcdir}
    
    install -d ${srcdir}/sources
    cp ${srcroot}/opfc-ModuleHP-1.1.1_withIPAMonaFonts-1.0.8.tar.gz ${srcdir}/sources
    
    hdiutil create -format UDBZ -srcdir ${srcdir} -volname ${proj_name} ${dmg}
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
