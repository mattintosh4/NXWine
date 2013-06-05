#!/usr/bin/env - LC_ALL=C SHELL=/bin/bash TERM=xterm-color HOME=/tmp /bin/bash -ex
PS4='\[\e[31m\]+\[\e[m\] '

readonly proj_name=NXWine
readonly proj_uuid=E43FF9C9-669C-4319-8351-FF99AFF3230C
readonly proj_root="$(cd "$(dirname "$0")"; pwd)"
readonly proj_version=$(date +%Y%m%d)
readonly proj_domain=com.github.mattintosh4.${proj_name}

readonly buildtoolbundle=${proj_root}/buildtool.sparsebundle
readonly buildtoolprefix=/Volumes/${proj_uuid}

readonly srcroot=${proj_root}/sources
readonly workroot=/tmp/${proj_uuid}
readonly destroot=/Applications/${proj_name}.app
readonly wine_destroot=${destroot}/Contents/Resources
readonly deps_destroot=${destroot}/Contents/SharedSupport

# -------------------------------------- local tools
readonly ccache=/usr/local/bin/ccache
readonly uconv=/usr/local/bin/uconv
readonly git=/usr/local/git/bin/git
test -x ${ccache}
test -x ${uconv}
test -x ${git}

if [ -x ${FONTFORGE=/opt/local/bin/fontforge} ]; then export FONTFORGE; fi

# -------------------------------------- environment variables
set -a
MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f-2)
DEVELOPER_DIR=$(xcode-select -print-path)
SDKROOT=$(xcodebuild -version -sdk macosx${MACOSX_DEPLOYMENT_TARGET} | sed -n '/^Path: /{;s/^Path: //;p;}')
[ -n "${MACOSX_DEPLOYMENT_TARGET}" ]
[ -d "${DEVELOPER_DIR}" ]
[ -d "${SDKROOT}" ]

PATH=$(/usr/sbin/sysctl -n user.cs_path)
PATH=$(dirname ${git}):$PATH
PATH=${deps_destroot}/bin:${buildtoolprefix}/bin:$PATH
CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)"
CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)"
CFLAGS="-pipe -m32 -O3 -march=core2 -mtune=core2 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
CXXFLAGS="${CFLAGS}"
CPPFLAGS="-isysroot ${SDKROOT} -I${deps_destroot}/include"
LDFLAGS="-Wl,-syslibroot,${SDKROOT} -L${deps_destroot}/lib"
ACLOCAL_PATH=${deps_destroot}/share/aclocal
set +a

triple=i686-apple-darwin$(uname -r)
configure_args="\
--prefix=${deps_destroot} \
--build=${triple} \
--enable-shared \
--enable-static \
--disable-debug \
--disable-maintainer-mode \
--disable-dependency-tracking \
--without-x"
make_args="-j $(($(sysctl -n hw.ncpu) + 1))"

# -------------------------------------- package source
## buildtools
pkgsrc_autoconf=autoconf-2.69.tar.gz
pkgsrc_automake=automake-1.13.2.tar.gz
pkgsrc_coreutils=coreutils-8.21.tar.bz2
pkgsrc_libtool=libtool-2.4.2.tar.gz
pkgsrc_m4=m4-1.4.16.tar.bz2
pkgsrc_p7zip=p7zip_9.20.1_src_all.tar.bz2
## bootstrap
pkgsrc_gettext=gettext-0.18.2.tar.gz
pkgsrc_libelf=libelf-0.8.13.tar.gz
pkgsrc_ncurses=ncurses-5.9.tar.gz
pkgsrc_readline=readline-master.tar.gz
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
pkgsrc_theora=libtheora-1.1.1.tar.bz2
pkgsrc_vorbis=libvorbis-1.3.3.tar.gz
## stage 5
pkgsrc_7z=7z920.exe
pkgsrc_cabextract=cabextract-1.4.tar.gz

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
    7z x -so ${srcroot}/${n} | tar x - -C ${workroot}
    cd ${workroot}/$(echo ${n} | sed -E 's#\.(zip|tbz2?|tgz|tar\..*)$##')
    case ${n} in
        coreutils-*|\
        m4-*|\
        autoconf-*|\
        automake-*)
            ./configure ${configure_args/${deps_destroot}/${buildtoolprefix}} "$@"
        ;;
        zlib-*)
            ./configure --prefix=${deps_destroot}
        ;;
        cabextract-*)
            ./configure ${configure_args/${deps_destroot}/${wine_destroot}}
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
    cp -RH ${srcroot}/$1 ${workroot}
    cd ${workroot}/$1
    case $1 in
        fontconfig)
            git checkout -f master
            ./autogen.sh ${configure_args}  --disable-docs \
                                            --sysconfdir=/System/Library \
                                            --with-add-fonts=/Library/Fonts,~/Library/Fonts
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
        libxml2)
            git checkout -f master
            ./autogen.sh ${configure_args}
        ;;
        libxslt)
            git checkout -f master
            ./autogen.sh ${configure_args}
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
        SDL)
            ./configure ${configure_args}
        ;;
        SDL_sound)
            ./bootstrap
            ./configure ${configure_args}
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
    
    sed "s|@DATE@|$(date +%F)|g" ${proj_root}/scripts/main.applescript | osacompile -o ${destroot}
    install -m 0644 ${proj_root}/nxwine.icns ${destroot}/Contents/Resources/droplet.icns
    
    ### directory installation ###
    install -d  ${deps_destroot}/{bin,include,share/man} \
                ${wine_destroot}/lib \
                ${workroot}
    (
        cd ${deps_destroot}
        ln -fhs ../Resources/lib lib
        ln -fhs share/man man
    )
    
    # -------------------------------------- begin tools build
    if [ -e ${buildtoolbundle} ]
    then
        hdiutil attach ${buildtoolbundle}
    else
        hdiutil create -type SPARSEBUNDLE -fs HFS+ -size 1g -volname ${proj_uuid} ${buildtoolbundle}
        hdiutil attach ${buildtoolbundle}
        
        {
            tar xf ${srcroot}/${pkgsrc_p7zip} -C ${workroot}
            cd ${workroot}/p7zip_9.20.1
            sed "
                s|^OPTFLAGS=-O|OPTFLAGS=-O2 -mtune=native|;
                s|^CXX=c++|CXX=${CXX}|;
                s|^CC=cc|CC=${CC}|;
                " makefile.macosx_64bits > makefile.machine
            make ${make_args} all3
            make DEST_HOME=${buildtoolprefix} install
            cd -
        }
        
        BuildDeps_  ${pkgsrc_coreutils} --program-prefix=g --enable-threads=posix --disable-nls --without-gmp
        {
            cd ${buildtoolprefix}/bin
            ln -s {g,}readlink
            cd -
        }
        BuildDeps_  ${pkgsrc_m4} --program-prefix=g
        {
            cd ${buildtoolprefix}/bin
            ln -s {g,}m4
            cd -
        }
        BuildDeps_  ${pkgsrc_autoconf}
        BuildDeps_  ${pkgsrc_automake}
    fi
    trap "hdiutil detach ${buildtoolprefix}" EXIT
    
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
        7z x -so ${srcroot}/${pkgsrc_gmp} | tar x - -C ${workroot}
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
} # end BuildStage2_

BuildStage3_ ()
{
    BuildDevel_ orc
    BuildDeps_  ${pkgsrc_odbc}
    BuildDevel_ libpng
    BuildDevel_ freetype
    [ -f ${deps_destroot}/lib/libfreetype.6.dylib ] # freetype required libpng
#    BuildDevel_ fontconfig
    BuildDeps_  ${pkgsrc_nasm}
    BuildDevel_ libjpeg-turbo
    {
        cd ${deps_destroot}/share/doc
        install -d libjpeg-turbo
        mv -f {libjpeg,README-turbo,structure,usage,wizard}.txt example.c README libjpeg-turbo
        cd -
    }
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
    BuildDevel_ SDL
    BuildDevel_ SDL_sound
    ## libtheora required SDL
    BuildDeps_  ${pkgsrc_theora} --disable-{oggtest,vorbistest,examples,asm}
} # end BuildStage4_

BuildStage5_ ()
{
    # -------------------------------------- cabextract
    BuildDeps_ ${pkgsrc_cabextract}
    install -d ${wine_destroot}/share/doc/cabextract-1.4
    cp ${workroot}/cabextract-1.4/{AUTHORS,ChangeLog,COPYING,NEWS,README,TODO} $_
    
    # -------------------------------------- winetricks
    InstallWinetricks_ ()
    {
        local bindir=${wine_destroot}/bin
        local docdir=${wine_destroot}/share/doc/winetricks
        local libexecdir=${wine_destroot}/libexec
        
        install -d ${bindir}
        install -m 0755 ${proj_root}/scripts/winetricksloader.sh ${bindir}/winetricks
        install -d ${libexecdir}
        install -m 0755 ${srcroot}/winetricks/src/winetricks ${libexecdir}
        install -d ${docdir}
        install -m 0644 ${srcroot}/winetricks/src/COPYING ${docdir}
    } # end InstallWinetricks_
    InstallWinetricks_
    
    # ------------------------------------- 7-Zip
    7z x -o${wine_destroot}/share/nxwine/programs/7-Zip -x'!$*' ${srcroot}/${pkgsrc_7z}
} # end BuildStage5_

BuildWine_ ()
{
    install -d ${workroot}/wine
    cd $_
    export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/opt/X11/share/pkgconfig
    ${srcroot}/wine/configure   --prefix=${wine_destroot} \
                                --build=${triple} \
                                --with-opengl \
                                --without-{capi,cms,gphoto,gsm,oss,sane,v4l} \
                                CPPFLAGS="${CPPFLAGS} -I/opt/X11/include" \
                                LDFLAGS="${LDFLAGS} -L/opt/X11/lib"
    make ${make_args}
    make install
    
#    wine_version=$(GIT_DIR=${srcroot}/wine/.git git describe HEAD 2>/dev/null || echo "wine-$(cat ${srcroot}/wine/VERSION | cut -d' ' -f3)")
    wine_version=$(${wine_destroot}/bin/wine --version)
    [ "${wine_version}" ]
    
    ### remove unnecessary files ###
    rm -r ${wine_destroot}/share/applications
    find ${wine_destroot}/lib -maxdepth 1 -name "*.a" -o -name "*.la" | xargs rm
    
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
    
    InstallFonts_ ()
    {
        local docdir=${wine_destroot}/share/doc
        local fontdir=${wine_destroot}/share/wine/fonts
        
        # Konatu
        7z x -o${docdir} ${srcroot}/Konatu_ver_20121218.zip
        mv ${docdir}/Konatu_ver_20121218/*.ttf ${fontdir}
        # Sazanami
        7z x -so ${srcroot}/sazanami-20040629.tar.bz2 | tar x - -C ${docdir}
        mv ${docdir}/sazanami-20040629/*.ttf ${fontdir}
        
        # remove duplicate fonts
        rm ${fontdir}/{symbol,tahoma,tahomabd,wingding}.ttf
        
    } # end InstallJPFonts_
    InstallFonts_
    
    ### inf ###
    local inf=${wine_destroot}/share/wine/wine.inf
    local inftmp=$(mktemp -t XXXXXX)
    mv ${inf}{,.orig}
    m4 ${proj_root}/scripts/inf.m4 | cat ${inf}.orig /dev/fd/3 3<&0 > ${inftmp}
    ${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${inf} ${inftmp}
    rm ${inftmp}
    
    # -------------------------------------- executables
    install -d ${wine_destroot}/libexec
    mv ${wine_destroot}/{bin,libexec}/wine
    
    install -m 0755 ${proj_root}/scripts/wineloader.sh ${wine_destroot}/bin/wine
    install -m 0755 ${proj_root}/scripts/nxwinetricks.sh ${wine_destroot}/bin/nxwinetricks
    sed -i "" "s|@DATE@|$(date +%F)|g" ${wine_destroot}/bin/{wine,nxwinetricks}
    
    # ------------------------------------- native dlls
    InstallNativedlls_ ()
    {
        local D=${workroot}/system32
        
        install -d ${D}
        cd ${D}
        install -m 0644 ${srcroot}/nativedlls/FL_gdiplus_dll_____X86.3643236F_FC70_11D3_A536_0090278A1BB8 gdiplus.dll
        7z x ${srcroot}/nativedlls/directx_feb2010_redist.exe dxnt.cab
        7z x dxnt.cab l3codecx.ax {\
amstream,\
ddrawex,\
dinput,\
dinput8,\
dplayx,\
mciqtz32,\
quartz}.dll
        
        7z x ${srcroot}/nativedlls/directx_Jun2010_redist.exe "*_x86.cab"
        find ./*_x86.cab | while read
        do
            7z x -y ${REPLY} {\
D3DCompiler,\
XAPOFX1,\
XAudio2,\
d3dx9}_\*.dll
        done
        # note: XAPOFX1_3.dll in Mar2009_XAudio_x86.cab is old
        7z x -y Aug2009_XAudio_x86.cab XAPOFX1_3.dll
        rm *.cab
        
        # hhctrl.ocx
        7z x ${proj_root}/sources/nativedlls/htmlhelp.exe hhupd.exe
        7z x hhupd.exe hhctrl.ocx
        rm hhupd.exe
        
        7z a -sfx ${wine_destroot}/share/nxwine/nativedlls/nativedlls.exe ${D}
        cd -
    }
    InstallNativedlls_
    
    # ------------------------------------- plist
    iconfile=droplet
    
    while read
    do
        /usr/libexec/PlistBuddy -c "${REPLY}" ${destroot}/Contents/Info.plist
    done <<__EOS__
Set :CFBundleIconFile ${iconfile}
Add :NSHumanReadableCopyright string ${wine_version}, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine
Add :CFBundleVersion string ${proj_version}
Add :CFBundleIdentifier string ${proj_domain}
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
$(
    i=4
    for x in \
        7z \
        cab \
        lha \
        lzh \
        lzma \
        rar \
        xz \
        zip
    do
        cat <<__EOS1__
Add :CFBundleDocumentTypes:${i}:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:${i}:CFBundleTypeExtensions:0 string ${x}
Add :CFBundleDocumentTypes:${i}:CFBundleTypeIconFile string ${iconfile}
Add :CFBundleDocumentTypes:${i}:CFBundleTypeName string ${x} Archive
Add :CFBundleDocumentTypes:${i}:CFBundleTypeRole string Viewer
__EOS1__
        ((i++))
    done
)
__EOS__

} # end BuildWine_

BuildDmg_ ()
{
    local dmg=${proj_root}/${proj_name}_${proj_version}_${wine_version/wine-}.dmg
    local srcdir=$(mktemp -dt XXXXXX)
    
    unzip -o -d ${wine_destroot}/share/doc/Faenza ${srcroot}/faenza-icon-theme_1.3.zip AUTHORS ChangeLog COPYING README
    
    install -d ${wine_destroot}/share/doc/nxwine
    install -m 0644 ${proj_root}/COPYING $_
    
    install -d ${srcdir}/.resources
    mv ${destroot} $_

    osacompile -xo ${srcdir}/"NXWine Installer".app ${proj_root}/scripts/installer.applescript
    install -m 0644 ${proj_root}/nxwine.icns ${srcdir}/"NXWine Installer".app/Contents/Resources/applet.icns
    
    [ ! -f ${dmg} ] || rm ${dmg}
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
