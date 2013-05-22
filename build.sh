#!/usr/bin/env - LC_ALL=C SHELL=/bin/bash TERM=xterm-color HOME=/tmp /bin/bash -x

readonly build_version=$(date +%Y%m%d)
readonly domain=com.github.mattintosh4

readonly origin="$(cd "$(dirname "$0")"; pwd)"/
readonly srcroot=${origin}source/
readonly workroot=/tmp/E43FF9C9-669C-4319-8351-FF99AFF3230C/
readonly destroot=/tmp/${domain}/
readonly wine_destroot=${destroot}NXWine.app/Contents/Resources/
readonly deps_destroot=${destroot}NXWine.app/Contents/SharedSupport/

# -------------------------------------- local tools
readonly ccache=/usr/local/bin/ccache
readonly clang=/usr/local/bin/clang
readonly uconv=/usr/local/bin/uconv
readonly git_dir=/usr/local/git/bin
readonly py_dir=/Library/Frameworks/Python.framework/Versions/2.7/bin
[ -x ${ccache} ] &&
[ -x ${clang} ] &&
[ -x ${uconv} ] &&
[ -d ${git_dir} ] &&
[ -d ${py_dir} ] &&
: || exit

# -------------------------------------- Xcode
export MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f-2) &&
export DEVELOPER_DIR=$(xcode-select -print-path) &&
export SDKROOT=$(xcodebuild -version -sdk macosx${MACOSX_DEPLOYMENT_TARGET} | sed -n '/^Path/{;s/^Path: //;p;}')
[ -n "${MACOSX_DEPLOYMENT_TARGET}" ] &&
[ -d "${DEVELOPER_DIR}" ] &&
[ -d "${SDKROOT}" ] &&
: || exit

PATH=/usr/bin:/bin:/usr/sbin:/sbin:${DEVELOPER_DIR}/bin:${DEVELOPER_DIR}/sbin
PATH=${git_dir}:${py_dir}:$PATH
PATH=${deps_destroot}bin:$PATH
export PATH
export CC="${ccache} $( xcrun -find i686-apple-darwin10-gcc-4.2.1)"
export CXX="${ccache} $(xcrun -find i686-apple-darwin10-g++-4.2.1)"
export CFLAGS="-pipe -m32 -mtune=generic -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-isysroot ${SDKROOT} -I${deps_destroot}include"
export LDFLAGS="-Wl,-syslibroot,${SDKROOT} -L${deps_destroot}lib"

configure_args="\
--prefix=${deps_destroot} \
--build=i386-apple-darwin$(uname -r) \
--enable-shared \
--disable-debug \
--disable-maintainer-mode \
--disable-dependency-tracking \
--without-x"
make_args="-j $(($(sysctl -n hw.ncpu) + 2))"

# -------------------------------------- package source
## bootstrap
pkgsrc_autoconf=autoconf-2.69.tar.gz
pkgsrc_automake=automake-1.13.1.tar.gz
pkgsrc_gettext=gettext-0.18.2.tar.gz
pkgsrc_libtool=libtool-2.4.2.tar.gz
pkgsrc_m4=m4-1.4.16.tar.bz2
pkgsrc_pkgconfig=pkg-config-0.28.tar.gz
pkgsrc_readline=readline-master.tar.gz
pkgsrc_xz=xz-5.0.4.tar.bz2
## stage 1
pkgsrc_gmp=gmp-5.1.1.tar.bz2
pkgsrc_gnutls=gnutls-3.1.8.tar.xz
pkgsrc_libtasn1=libtasn1-3.3.tar.gz
pkgsrc_nettle=nettle-2.7.tar.gz
pkgsrc_usb=libusb-1.0.9.tar.bz2
pkgsrc_usbcompat=libusb-compat-0.1.4.tar.bz2
## stage 2
## stage 3
pkgsrc_icns=libicns-0.8.1.tar.gz
pkgsrc_jasper=jasper-1.900.1.zip
pkgsrc_jpeg=jpeg-8d.tar.bz2
pkgsrc_odbc=unixODBC-2.3.1.tar.gz
pkgsrc_orc=orc-0.4.17.tar.gz
pkgsrc_tiff=tiff-4.0.3.tar.gz
## stage 4
pkgsrc_flac=flac-1.2.1.tar.gz
pkgsrc_ogg=libogg-1.3.0.tar.gz
pkgsrc_sdl=SDL-1.2.15.tar.gz
pkgsrc_sdlsound=SDL_sound-1.0.3.tar.gz
pkgsrc_theora=libtheora-1.1.1.tar.bz2
pkgsrc_vorbis=libvorbis-1.3.3.tar.gz

# -------------------------------------- begin utilities functions

function DocCopy_ {
  test -n "$1" || exit
  local d=${deps_destroot}share/doc/$1
  install -d ${d} &&
  find -E ${workroot}$1 -depth 1 -type f -regex '.*/(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING(.LIB)?|LICENSE|NEWS|README|RELEASE|TODO|VERSION)' | while read
  do
    cp "${REPLY}" ${d}
  done || exit
} # end DocCopy_

function Compress_ {
  test -n "$1" &&
  # !!! to compress with absolute path
  tar -cP ${destroot} | bzip2 > $1 || exit
} # end Compress_

function Extract_ {
  test -n "$1" &&
  # !!! to extract with absolute path
  tar -xvPf $1 || exit
} # end Extract_

# -------------------------------------- begin build processing functions

function BuildDeps_ {
    (($# != 0)) || { echo "Invalid argment."; exit 1; }
    local n=$1
    shift
    case ${n} in
        *.xz)
            xzcat ${srcroot}${n} | tar x - -C ${workroot}
        ;;
        *)
            tar xf ${srcroot}${n} -C ${workroot}
        ;;
    esac &&
    cd ${workroot}$(echo ${n} | sed -E 's#\.(zip|tbz2?|tgz|tar\..*)$##') &&
    ./configure ${configure_args} "$@" &&
    make ${make_args} &&
    make install &&
    : || exit
} # end BuildDeps_

BuildDevel_ ()
{
    if [ -d ${srcroot}$1 ] ; then :
    else
        echo "${srcroot}$1 is not found, or Invalid argment."
        exit 1
    fi
    ditto {${srcroot},${workroot}}$1 &&
    cd $_ &&
    case $1 in
        freetype)
            git checkout -f master &&
            ./autogen.sh &&
            ./configure ${configure_args}
        ;;
        glib)
            git checkout -f 2.37.0 &&
            ./autogen.sh ${configure_args} --disable-gtk-doc
        ;;
        libffi)
            git checkout -f master &&
            ./configure ${configure_args}
        ;;
        libpng)
            git checkout -f master &&
            autoreconf -i &&
            ./configure ${configure_args}
        ;;
    esac &&
    make ${make_args} &&
    make install &&
    DocCopy_ $1 &&
    : || exit
} # end BuildDevel_

Bootstrap_ ()
{
    # -------------------------------------- begin preparing
    ### source check ###
    for x in ${!pkgsrc_*}
    do
        echo -n "checking ${!x} ... "
        [ -f ${srcroot}${!x} ] && echo "yes" || { echo "no"; exit 1; }
    done
    ### clean up ###
    rm -rf ${workroot} ${destroot}
    ### directory installation ###
    install -d  ${deps_destroot}{bin,include,share/man} \
                ${wine_destroot}lib \
                ${workroot} &&
    (cd ${deps_destroot} && ln -s ../Resources/lib lib && ln -s share/man man) || exit
    
    # -------------------------------------- begin build
    BuildDeps_ ${pkgsrc_pkgconfig}  --disable-host-tool \
                                    --with-internal-glib \
                                    --with-pc-path=${deps_destroot}lib/pkgconfig:${deps_destroot}share/pkgconfig:/usr/lib/pkgconfig
    BuildDeps_ ${pkgsrc_readline}   --with-curses --enable-multibyte
    BuildDeps_ ${pkgsrc_m4}         --program-prefix=g
    ln ${deps_destroot}bin/{g,}m4 && $_ --version >/dev/null || exit
    BuildDeps_ ${pkgsrc_autoconf}
    for x in auto{conf,header,m4te,reconf,scan,update} ifnames ; do ln ${deps_destroot}bin/${x}{,-2.69} || exit ; done
    BuildDeps_ ${pkgsrc_automake}
    BuildDeps_ ${pkgsrc_libtool} --program-prefix=g
    ln ${deps_destroot}bin/{g,}libtool     && $_ --version >/dev/null &&
    ln ${deps_destroot}bin/{g,}libtoolize  && $_ --version >/dev/null || exit
    BuildDeps_ ${pkgsrc_gettext}
    BuildDeps_ ${pkgsrc_xz}
} # end Bootstrap_

BuildStage1_ ()
{
    tar -xf ${srcroot}${pkgsrc_gmp} -C ${workroot} && (
        cd ${workroot}gmp-5.1.1 &&
        ./configure ${configure_args} ABI=32 CC=$(xcrun -find gcc-4.2) CXX=$(xcrun -find g++-4.2) &&
        make ${make_args} &&
        make check &&
        make install
    ) || exit
    BuildDeps_  ${pkgsrc_libtasn1}
    BuildDeps_  ${pkgsrc_nettle}
    BuildDeps_  ${pkgsrc_gnutls}
    BuildDeps_  ${pkgsrc_usb}
    BuildDeps_  ${pkgsrc_usbcompat} 
} # end BuildStage1_

BuildStage2_ ()
{
    BuildDevel_ libffi
    BuildDevel_ glib
    BuildDevel_ freetype
    [ -f ${deps_destroot}lib/libfreetype.6.dylib ] || exit
} # end BuildStage2_

BuildStage3_ ()
{
    BuildDeps_  ${pkgsrc_orc}   CC="${ccache} ${clang}" \
                                CXX="${ccache} ${clang}++" \
                                CFLAGS="-arch i386 ${CFLAGS}" \
                                CXXFLAGS="-arch i386 ${CFLAGS}"
    BuildDeps_  ${pkgsrc_odbc}
    BuildDevel_ libpng
    BuildDeps_  ${pkgsrc_jpeg}
    BuildDeps_  ${pkgsrc_tiff}
    BuildDeps_  ${pkgsrc_jasper} --disable-opengl --without-x
    BuildDeps_  ${pkgsrc_icns}
} # end BuildStage3_

BuildStage4_ ()
{
    BuildDeps_  ${pkgsrc_ogg}
    BuildDeps_  ${pkgsrc_vorbis}
    BuildDeps_  ${pkgsrc_flac}      --disable-asm-optimizations --disable-xmms-plugin
    BuildDeps_  ${pkgsrc_sdl}
    BuildDeps_  ${pkgsrc_sdlsound}
    ## libtheora required SDL
    BuildDeps_  ${pkgsrc_theora}    --disable-oggtest \
                                    --disable-vorbistest \
                                    --disable-examples \
                                    --disable-asm
} # end BuildStage4_

BuildStage5_ ()
{
    ### cabextract ###
    tar -xf ${srcroot}cabextract-1.4.tar.gz -C ${workroot} && (
        cd ${workroot}cabextract-1.4 &&
        ./configure ${configure_args/${deps_destroot}/${wine_destroot}} &&
        make ${make_args} &&
        make install &&
        install -d ${wine_destroot}share/doc/cabextract-1.4 &&
        cp AUTHORS ChangeLog COPYING NEWS README TODO $_
    ) || exit
    
    ### winetricks ###
    ditto {${srcroot}winetricks/src,${wine_destroot}share/doc/winetricks}/COPYING &&
    install -m 0755 ${srcroot}winetricks/src/winetricks ${wine_destroot}bin/winetricks.bin &&
    cat <<'__EOF__' > ${wine_destroot}/bin/winetricks && chmod +x ${wine_destroot}bin/winetricks || exit
#!/bin/bash
export PATH="$(cd "$(dirname "$0")"; pwd)":/usr/bin:/bin:/usr/sbin:/sbin
which wine || { echo "wine not found."; exit 1; }
exec winetricks.bin "$@"
__EOF__
} # end BuildStage5_

BuildWine_ ()
{
    ## wine is always built at new directory
    cd $(mktemp -dt XXXXXX) &&
    ${srcroot}wine/configure    --prefix=${wine_destroot} \
                                --without-sane \
                                --without-v4l \
                                --without-gphoto \
                                --without-oss \
                                --without-capi \
                                --without-gsm \
                                --without-cms \
                                --without-x \
    &&
    make ${make_args} &&
    make install || exit
    
    ### install name ###
    for x in bin/{wine,wineserver} lib/libwine.1.0.dylib
    do
        install_name_tool -add_rpath /usr/lib ${wine_destroot}${x} || exit
    done
    
    ### docs ###
    install -d ${wine_destroot}share/doc/wine &&
    cp ${srcroot}wine/{ANNOUNCE,AUTHORS,COPYING.LIB,LICENSE,README,VERSION} $_ || exit
    
    ### custom inf ###
    local inf=${wine_destroot}share/wine/wine.inf
    mv ${inf}{,.orig} &&
    ${uconv} -f UTF-8 -t UTF-8 --add-signature -o ${inf} ${inf}.orig &&
    patch ${inf} ${origin}patch/nxwine.patch || exit
    
    ### WINELOADER ###
    install -d ${wine_destroot}libexec &&
    mv ${wine_destroot}{bin,libexec}/wine &&
    cat <<__EOF__ > ${wine_destroot}bin/wine && chmod +x ${wine_destroot}bin/wine || exit
#!/bin/bash
install -d ${destroot}
ln -sf "\$(cd "\$(dirname "\$0")/../../.." && pwd)" ${destroot} || exit
exec ${wine_destroot}/libexec/wine "\$@"
__EOF__

    ### archive ###
    tar cP ${destroot} | bzip2 > ${origin}wine.tar.bz2
} # end BuildWine_

CreateBundle_ ()
{
    CreateDmg_ ()
    {
        dmg=${origin}NXWine_${build_version}_${wine_version/wine-}.dmg
        [ ! -f ${dmg} ] || rm ${dmg}
        ln -s /Applications ${destroot} &&
        hdiutil create -format UDBZ -srcdir ${destroot} -volname NXWine ${dmg} &&
        rm -rf ${destroot} || exit
    }
    
    app=${destroot}NXWine.app
    app_resources=${app}/Contents/Resources/
    
    rm -rf ${destroot} &&
    install -d ${destroot} &&
    sed "s|@DATE@|$(date +%F)|g" ${origin}NXWine.applescript | osacompile -o ${app} &&
    rm ${app_resources}droplet.icns &&
    install -m 0644 ${origin}nxwine.icns ${app_resources} || exit
    
    tar xPf ${origin}wine.tar.bz2 &&
    wine_version=$(${app_resources}libexec/wine --version) &&
    [ "${wine_version}" ] || exit
    
    while read
    do
        /usr/libexec/PlistBuddy -c "${REPLY}" ${app}/Contents/Info.plist || exit
    done <<__CMD__
Set :CFBundleIconFile nxwine
Add :NSHumanReadableCopyright string ${wine_version}, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine
Add :CFBundleVersion string ${build_version}
Add :CFBundleIdentifier string ${domain}.NXWine
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

    CreateDmg_
} # end BuildBundle_

# -------------------------------------- begin processing section
Bootstrap_
BuildStage1_
BuildStage2_
BuildStage3_
BuildStage4_
BuildStage5_
BuildWine_
CreateBundle_

# -------------------------------------- end processing section

:
afplay /System/Library/Sounds/Hero.aiff
