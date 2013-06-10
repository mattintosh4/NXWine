#!/usr/bin/env - LC_ALL=C SHELL=/bin/bash TERM=xterm-color /bin/bash -eux
PS4='\[\e[31m\]+\[\e[m\] '

export TMPDIR=$(getconf DARWIN_USER_TEMP_DIR)
export HOME=${TMPDIR:?}

readonly proj_name=NXWine
readonly proj_uuid=E43FF9C9-669C-4319-8351-FF99AFF3230C
readonly proj_root="$(cd "$(dirname "$0")"; pwd)"
readonly proj_version=$(date +%Y%m%d)
readonly proj_domain=com.github.mattintosh4.${proj_name}

readonly toolbundle=${proj_root}/tool.sparsebundle
readonly toolprefix=/Volumes/${proj_uuid}

readonly srcroot=${proj_root}/sources
readonly workroot=$TMPDIR/${proj_uuid}
readonly destroot=/Applications/${proj_name}.app
readonly wine_destroot=${destroot}/Contents/Resources
readonly deps_destroot=${destroot}/Contents/SharedSupport

# -------------------------------------- local tools
readonly ccache=/usr/local/bin/ccache
readonly uconv=/usr/local/bin/uconv
readonly git=/usr/local/git/bin/git
readonly hg=/usr/local/bin/hg
[ -x ${ccache} ]
[ -x ${uconv} ]
[ -x ${git} ]
[ -x ${hg} ]

if [ -x ${FONTFORGE=/opt/local/bin/fontforge} ]; then export FONTFORGE; fi

# -------------------------------------- environment variables
set -a
MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f-2)
DEVELOPER_DIR=$(xcode-select -print-path)
SDKROOT=$(xcodebuild -version -sdk macosx${MACOSX_DEPLOYMENT_TARGET} | sed -n '/^Path: /s///p')
[ -n "${MACOSX_DEPLOYMENT_TARGET}" ]
[ -d "${DEVELOPER_DIR}" ]
[ -d "${SDKROOT}" ]

PATH=$(getconf PATH)
PATH=$(dirname ${git}):$PATH
PATH=${deps_destroot}/bin:${toolprefix}/bin:$PATH
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
--disable-dependency-tracking \
--disable-documentation \
--disable-maintainer-mode \
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
## stage 1
pkgsrc_gmp=gmp-5.1.2.tar.xz
pkgsrc_gnutls=gnutls-3.1.8.tar.xz
pkgsrc_libtasn1=libtasn1-3.3.tar.gz
## stage 2
## stage 3
pkgsrc_jasper=jasper-1.900.1.tar.bz2
pkgsrc_odbc=unixODBC-2.3.1.tar.gz
## stage 4
## stage 5
pkgsrc_7z=7z920.exe
pkgsrc_cabextract=cabextract-1.4.tar.gz

# -------------------------------------- begin utilities functions
DocCopy_ ()
{
    set ${1:?} ${deps_destroot}/share/doc/${1:?}
    install -d $2
    find -E ${workroot}/$2 \
        -maxdepth 1 \
        -type f \
        -regex '.*/(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING(.LIB)?|LICENSE|NEWS|README|RELEASE|TODO|VERSION)(\.txt)?' \
        | xargs -J % cp % $2
} # end DocCopy_

# -------------------------------------- begin build processing functions
BuildDeps_ ()
{
    local n=${1:?}
    shift
    7z x -y -so ${srcroot}/${n} | tar x - -C ${workroot}
    cd ${workroot}/$(echo ${n} | sed -E 's#\.(zip|tbz2?|tgz|tar\..*)$##')
    case ${n} in
        coreutils-*)
            ./configure --prefix=${toolprefix} --build=${triple} --program-prefix=g --enable-threads=posix --disable-nls --without-gmp
            make ${make_args}
            make install
            cd ${toolprefix}/bin
            ln -s {g,}readlink
            cd -
            return
        ;;
        m4-*)
            ./configure --prefix=${toolprefix} --build=${triple} --program-prefix=g
            make ${make_args}
            make install
            cd ${toolprefix}/bin
            ln -s {g,}m4
            cd -
            return
        ;;
        autoconf-*|automake-*)
            ./configure --prefix=${toolprefix} --build=${triple}
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
} # end BuildDeps_

BuildDevel_ ()
{
    if
        [ "$1" ] &&
        [ -d ${srcroot}/$1 ]
    then :
    else
        echo "Invalid argment or directory does not exist."
        exit 1
    fi
    cp -RHf ${srcroot}/$1 ${workroot}
    cd ${workroot}/$1
    case $1 in
        fontconfig)
            git checkout -f master
            ./autogen.sh ${configure_args}  --disable-docs \
                                            --sysconfdir=/System/Library \
                                            --with-add-fonts=/Library/Fonts,~/Library/Fonts
        ;;
        flac)
            ./autogen.sh
            ./configure ${configure_args}   --disable-{asm-optimizations,xmms-plugin}
        ;;
        freetype)
            git checkout -f master
            ./autogen.sh
            ./configure ${configure_args}
        ;;
        glib)
            git checkout -f glib-2-36
            ./autogen.sh ${configure_args}  --disable-{gtk-doc{,-html,-pdf},selinux,fam,xattr} \
                                            --with-threads=posix \
                                            --without-{html-dir,xml-catalog}
        ;;
        libffi)
            git checkout -f master
            ./configure ${configure_args}
        ;;
        libicns)
            autoreconf -i
            ./configure ${configure_args}
        ;;
        libjpeg-turbo)
            git checkout -f master
            autoreconf -i
            ./configure ${configure_args} --with-jpeg8
            make ${make_args}
            make install
            install -d ${deps_destroot}/share/doc/libjpeg-turbo
            mv -f ${deps_destroot}/share/doc/{{libjpeg,README-turbo,structure,usage,wizard}.txt,example.c,README} $_
            return
        ;;
        libpng)
            git checkout -f libpng15
            autoreconf -i
            ./configure ${configure_args}
        ;;
        libtiff)
            ./configure ${configure_args}
        ;;
        libusb|libusb-compat-0.1)
            ./autogen.sh ${configure_args}
        ;;
        libxml2)
            git checkout -f master
            ./autogen.sh ${configure_args}
        ;;
        libxslt)
            git checkout -f master
            ./autogen.sh ${configure_args}
        ;;
        nasm)
            git checkout -f master
            ./autogen.sh
            ./configure ${configure_args}
            # note: without asciidoc and xmlto
            make -i ${make_args}
            make -i install
            [ -x ${deps_destroot}/bin/nasm ]
            [ -x ${deps_destroot}/bin/ndisasm ]
            DocCopy_ nasm
            return
        ;;
        nettle)
            git checkout -f nettle-2.7-fixes
            ./.bootstrap
            ./configure ${configure_args}
        ;;
        ogg)
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
        python) # python 2.7
            ${hg} checkout -C v2.7.5
            install -d build
            cd $_
            ../configure ${configure_args}
        ;;
        readline)
            ./configure ${configure_args} --with-curses --enable-multibyte
        ;;
        SDL)
            # note: mercurial repository must be separated a build directory.
            install -d build
            cd $_
            ../configure ${configure_args}
            make ${make_args}
            make install
            DocCopy_ SDL
            # note: theora will not find sdl2.pc.
            cd ${deps_destroot}/lib/pkgconfig
            ln -s sdl{2,}.pc
            cd -
            return
        ;;
        SDL_sound)
            ./bootstrap
            # note: mercurial repository must be separated a build directory.
            install -d build
            cd $_
            ../configure ${configure_args}
        ;;
        theora)
            ./autogen.sh ${configure_args} --disable-{oggtest,vorbistest,examples,asm}
        ;;
        vorbis)
            ./autogen.sh ${configure_args}
        ;;
        xz)
            ./autogen.sh
            ./configure ${configure_args}
        ;;
        zlib)
            git checkout -f master
            ./configure --prefix=${deps_destroot}
        ;;
    esac
    make ${make_args}
    make install
    DocCopy_ $1
} # end BuildDevel_

# ------------------------------------- separate build
BuildGettext_ ()
{
    set ${1:?} ${pkgsrc_gettext%.tar.*} "$(echo \
--disable-{csharp,native-java,openmp} \
--without-{cvs,emacs,git} \
--with-included-{gettext,glib,libcroro,libunistring,libxml})"
    
    tar xf ${srcroot}/${pkgsrc_gettext} -C ${workroot}
    install -d ${workroot}/$2/build_$1
    cd $_
    case $1 in
        host)
            ../configure --prefix=${toolprefix} --build=${triple} $3
        ;;
        target)
            ../configure ${configure_args} $3
        ;;
    esac
    make ${make_args}
    make install
}

BuildSevenzip_ ()
{
    tar xf ${srcroot}/${pkgsrc_p7zip} -C ${workroot}
    cd ${workroot}/p7zip_9.20.1
    sed "
        s#^OPTFLAGS=-O#OPTFLAGS=-O3 -mtune=native#
        s#^CXX=c++#CXX=${CXX}#
        s#^CC=cc#CC=${CC}#
    " makefile.macosx_64bits > makefile.machine
    make ${make_args} all3
    make DEST_HOME=${toolprefix} install
}

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
    if [ -e ${toolbundle} ]
    then
        hdiutil attach ${toolbundle}
    else
        hdiutil create -type SPARSEBUNDLE -fs HFS+ -size 1g -volname ${proj_uuid} ${toolbundle}
        hdiutil attach ${toolbundle}
        trap "hdiutil detach ${toolprefix}; rm -rf ${toolbundle}" EXIT
        BuildGettext_ host
        BuildSevenzip_
        BuildDeps_  ${pkgsrc_coreutils}
        BuildDeps_  ${pkgsrc_m4}
        BuildDeps_  ${pkgsrc_autoconf}
        BuildDeps_  ${pkgsrc_automake}
        trap EXIT
    fi
    trap "hdiutil detach ${toolprefix}" EXIT
    
    # --------------------------------- begin build
    BuildGettext_ target
    BuildDeps_  ${pkgsrc_libelf}
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
    BuildDevel_ readline
    BuildDevel_ zlib
    BuildDeps_  ${pkgsrc_libelf} --disable-compat
    BuildDevel_ xz
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
    }
    BuildDeps_  ${pkgsrc_libtasn1} --disable-gtk-doc{,-{html,pdf}}
    BuildDevel_ nettle
    BuildDeps_  ${pkgsrc_gnutls} --disable-guile --without-p11-kit
    BuildDevel_ libusb
    BuildDevel_ libusb-compat-0.1
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
    BuildDevel_ freetype                # freetype required libpng
    [ -f ${deps_destroot}/lib/libfreetype.6.dylib ]
#    BuildDevel_ fontconfig
    BuildDevel_ nasm
    BuildDevel_ libjpeg-turbo
    BuildDevel_ libtiff
    BuildDeps_  ${pkgsrc_jasper} --disable-opengl --without-x
    BuildDevel_ libicns
} # end BuildStage3_

BuildStage4_ ()
{
    BuildDevel_ ogg
    BuildDevel_ vorbis
    BuildDevel_ flac
    BuildDevel_ SDL                     # SDL required nasm
    BuildDevel_ SDL_sound
    BuildDevel_ theora                  # libtheora required SDL
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
        
        install -d ${libexecdir}
        install -m 0755 ${srcroot}/winetricks/src/winetricks ${libexecdir}
        install -d ${docdir}
        install -m 0644 ${srcroot}/winetricks/src/COPYING ${docdir}
        # nxwinetricks
        install -d ${bindir}
        install -m 0755 ${proj_root}/scripts/winetricksloader.sh ${bindir}/winetricks
    } # end InstallWinetricks_
    InstallWinetricks_
    
    # ------------------------------------- 7-Zip
    7z x -y -o${wine_destroot}/share/nxwine/programs/7-Zip -x'!$*' ${srcroot}/${pkgsrc_7z}
} # end BuildStage5_

BuildWine_ ()
{
    set ${workroot}/wine
    install -d $1
    cd $1
    export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig:/opt/X11/share/pkgconfig
    ${srcroot}/wine/configure   --prefix=${wine_destroot} \
                                --build=${triple} \
                                --with-opengl \
                                --without-{capi,cms,gphoto,gsm,oss,sane,v4l} \
                                CPPFLAGS="${CPPFLAGS} -I/opt/X11/include" \
                                LDFLAGS="${LDFLAGS} -L/opt/X11/lib"
    make ${make_args}
    make install
} # end BuildWine_

BuildStage6_ ()
{
    local bindir=${wine_destroot}/bin
    local libdir=${wine_destroot}/lib
    local datadir=${wine_destroot}/share
    local docdir=${wine_destroot}/share/doc
    
    # install name
    install_name_tool -add_rpath /usr/lib ${bindir}/wine
    install_name_tool -add_rpath /usr/lib ${bindir}/wineserver
    install_name_tool -add_rpath /usr/lib ${libdir}/libwine.1.0.dylib
    # gecko
    install -d ${datadir}/wine/gecko
    cp ${srcroot}/wine_gecko-2.21-x86.msi $_
    # mono
    install -d ${datadir}/wine/mono
    cp ${srcroot}/wine-mono-0.0.8.msi $_
    # docs
    install -d ${docdir}/wine
    cp ${srcroot}/wine/{ANNOUNCE,AUTHORS,COPYING.LIB,LICENSE,README,VERSION} $_
    
    # -------------------------------------- fonts
    InstallFonts_ ()
    {
        set ${datadir}/wine/fonts
        
        # remove duplicate fonts
        rm ${1:?}/{symbol,tahoma,tahomabd,wingding}.ttf
        # Konatu
        7z x -y -o${docdir} ${srcroot}/fonts/Konatu_ver_20121218.zip
        mv ${docdir}/Konatu_ver_20121218/*.ttf $1
        # Sazanami
        7z x -so ${srcroot}/fonts/sazanami-20040629.tar.bz2 | tar x - -C ${docdir}
        mv ${docdir}/sazanami-20040629/*.ttf $1
    }
    InstallFonts_
    
    # -------------------------------------- inf
    ModifyInf_ ()
    {
        set $TMPDIR/$$$LINENO.\$\$
        
        m4 ${proj_root}/scripts/inf.m4 >> ${datadir}/wine/wine.inf
        ${uconv} -f UTF-8 -t UTF-8 --add-signature -o $1 ${datadir}/wine/wine.inf
        mv -f $1 ${datadir}/wine/wine.inf
    }
    ModifyInf_
    
    # -------------------------------------- executables
    install -d ${wine_destroot}/libexec
    mv ${wine_destroot}/{bin,libexec}/wine
    install -m 0755 ${proj_root}/scripts/wineloader.sh ${wine_destroot}/bin/wine
    install -m 0755 ${proj_root}/scripts/nxwinetricks.sh ${wine_destroot}/bin/nxwinetricks
    sed -i "" "s|@DATE@|$(date +%F)|g" ${wine_destroot}/bin/{wine,nxwinetricks}
    
    # ------------------------------------- native dlls
    InstallNativedlls_ ()
    {
        set ${workroot}/system32
        install -d $1
        cd $1
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
        
        7z a -sfx ${datadir}/nxwine/nativedlls/nativedlls.exe $1
    }
    InstallNativedlls_
    
    # ------------------------------------- plist
    wine_version=$(GIT_DIR=${srcroot}/wine/.git git describe HEAD 2>/dev/null)
    : ${wine_version:?}
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
    
    # faenza icon theme
    7z x -o${docdir}/faenza-icon-theme_1.3 ${srcroot}/faenza-icon-theme_1.3.zip AUTHORS ChangeLog COPYING README
    
    install -d ${docdir}/nxwine
    install -m 0644 ${proj_root}/COPYING $_
    
    # remove unnecessary files
    rm -rf  ${libdir:?}/*.{a,la} \
            ${datadir:?}/applications
} # end BuildStage6_

BuildDmg_ ()
{
    set $TMPDIR/$$$LINENO.\$\$ ${proj_root}/${proj_name}_${proj_version}_${wine_version/wine-}.dmg
    
    install -d $1/.resources
    mv ${destroot} $_
    osacompile -xo $1/"NXWine Installer".app ${proj_root}/scripts/installer.applescript
    install -m 0644 ${proj_root}/nxwine.icns $1/"NXWine Installer".app/Contents/Resources/applet.icns
    [ ! -f $2 ] || rm $2
    hdiutil create -format UDBZ -srcdir $1 -volname ${proj_name} $2
    rm -rf $1
} # end BuildDmg_

# -------------------------------------- begin processing section
Bootstrap_
BuildStage1_
BuildStage2_
BuildStage3_
BuildStage4_
BuildStage5_
BuildWine_
BuildStage6_
BuildDmg_

# -------------------------------------- end processing section

:
afplay /System/Library/Sounds/Hero.aiff
