#!/usr/bin/env - SHELL=/bin/bash TERM=xterm COMMAND_MODE=unix2003 /bin/bash -ex
PS4="\[\e[31m\]+\[\e[m\] "
TMPDIR=$(getconf DARWIN_USER_TEMP_DIR); HOME=$TMPDIR; export TMPDIR HOME

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

PATH=$(tr '\n' ':' <<@EOS
${deps_destroot}/bin
${toolprefix}/bin
$(dirname ${git})
$(getconf PATH)
@EOS); PATH=${PATH%?}
CC="${ccache} $( xcrun -find gcc-4.2)"
CXX="${ccache} $(xcrun -find g++-4.2)"
CFLAGS="-m32 -arch i386 -pipe -O3 -march=core2 -mtune=core2 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
CXXFLAGS="${CFLAGS} -ffast-math -fomit-frame-pointer"
CPPFLAGS="-isysroot ${SDKROOT} -I${deps_destroot}/include"
LDFLAGS="-Wl,-arch,i386 -Wl,-search_paths_first -Wl,-headerpad_max_install_names -Wl,-syslibroot,${SDKROOT} -L${deps_destroot}/lib"
ACLOCAL_PATH=$deps_destroot/share/aclocal:$toolprefix/share/aclocal
LANG=ja_JP.UTF-8
LC_ALL=$LANG
gt_cv_local_ja=$LANG
set +a

triple=i686-apple-darwin$(uname -r)
configure_pre_args="--prefix=${deps_destroot} --build=$triple --disable-dependency-tracking"
configure_args="\
${configure_pre_args} \
--enable-shared \
--enable-static \
--disable-debug \
--disable-documentation \
--disable-maintainer-mode \
--disable-gtk-doc \
--disable-gtk-doc-html \
--disable-gtk-doc-pdf \
--without-x"
make_args="-j $(($(sysctl -n hw.ncpu) + 1))"

readonly wine_version=$(GIT_DIR=${srcroot}/wine/.git git describe HEAD 2>/dev/null)
: ${wine_version:?}

# -------------------------------------- package source
for pkg in \
  ${pkgsrc_7z=7z920.exe} \
  ${pkgsrc_autoconf=autoconf-2.69.tar.gz} \
  ${pkgsrc_automake=automake-1.13.2.tar.gz} \
  ${pkgsrc_cabextract=cabextract-1.4.tar.gz} \
  ${pkgsrc_coreutils=coreutils-8.21.tar.bz2} \
  ${pkgsrc_gettext=gettext-0.18.2.tar.gz} \
  ${pkgsrc_help2man=help2man-1.41.2.tar.gz} \
  ${pkgsrc_jasper=jasper-1.900.1.tar.bz2} \
  ${pkgsrc_libelf=libelf-0.8.13.tar.gz} \
  ${pkgsrc_libtool=libtool-2.4.2.tar.gz} \
  ${pkgsrc_m4=m4-1.4.16.tar.bz2} \
  ${pkgsrc_odbc=unixODBC-2.3.1.tar.gz} \
  ${pkgsrc_p7zip=p7zip_9.20.1_src_all.tar.bz2} \
  ${pkgsrc_libtasn1=libtasn1-3.3.tar.gz} \
; do [ -f $srcroot/$pkg ]; done

# -------------------------------------- begin utilities functions
mkdircd (){ install -d ${1:?} && cd $1; }
makeallin (){ make ${make_args} && make install; }
DocCompress_ ()
{
    set -- "tar vcjf ${deps_destroot}/share/doc/doc_${1:?}.tar.bz2 -C ${workroot}" $(cd ${workroot} && find -E $1 -maxdepth 1 -type f -regex '.*/(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING(.LIB)?|LICENSE|NEWS|README|RELEASE|TODO|VERSION)(\.txt)?')
    [ $# == 1 ] && return || $@
} # end DocCompress_

# -------------------------------------- begin build processing functions
BuildDeps_ ()
{
    : ${1:?}
    7z x -y -so $srcroot/$1 | tar x - -C ${workroot}
    cd ${workroot}/$(echo $1 | sed -E 's#\.(zip|tbz2?|tgz|tar\..*)$##')
    case $1 in
        cabextract-*)
            ./configure ${configure_args/${deps_destroot}/${wine_destroot}}
        ;;
        gettext-*)
            ./configure ${configure_pre_args} \
                        --disable-{csharp,native-java,openmp} \
                        --without-{cvs,emacs,git} \
                        --with-included-{gettext,glib,libcroro,libunistring,libxml}
        ;;
        *)
            shift
            ./configure ${configure_args} "$@"
        ;;
    esac
    $"makeallin"
} # end BuildDeps_

BuildDevel_ ()
{
  cp -RHf ${srcroot}/${1:?} ${workroot}
  cd ${workroot}/$1
  case $1 in
    flac)
      sh autogen.sh
      sh configure  ${configure_args} \
                    --disable-{asm-optimizations,xmms-plugin}
    ;;
    freetype)
      git checkout -f master
      sh autogen.sh
      sh configure ${configure_args}
      $"makeallin"
      [ -f ${deps_destroot}/lib/libfreetype.6.dylib ]
      DocCompress_ freetype
      return
    ;;
    glib)
      git checkout -f glib-2-36
      sh autogen.sh ${configure_args} \
                    --disable-{selinux,fam,xattr} \
                    --with-threads=posix \
                    --without-{html-dir,xml-catalog}
    ;;
    gmp-5.1)
      sh .bootstrap
      autoreconf -i
      $"mkdircd" build
      sh ../configure ${configure_pre_args} \
                      CC=$( xcrun -find gcc-4.2) \
                      CXX=$(xcrun -find g++-4.2) \
                      ABI=32
      make ${make_args}
      make check
      make install
    ;;
    gnutls)
      git checkout -f master
      git log | grep -v "^commit" > ChangeLog
      make CFGFLAGS="$configure_args --disable-guile --without-p11-kit" bootstrap
    ;;
    guile)
      git checkout -f stable-2.0
      sh autogen.sh
      sh configure $configure_args
    ;;
    icu)
      cd source
      $"patch_icu"
      sh configure ${configure_args} --with-library-bits=32
    ;;
    libffi)
      git checkout -f master
      sh configure ${configure_args}
    ;;
    libicns)
      autoreconf -i
      sh configure ${configure_args}
    ;;
    libjpeg-turbo)
      git checkout -f master
      $"patch_libjpeg-turbo"
      autoreconf -i
      sh configure ${configure_args} --with-jpeg8
    ;;
    libpng)
      git checkout -f libpng16
      autoreconf -i
      sh configure ${configure_args}
    ;;
    libtasn1)
      git checkout -f master
      git log --date=short --pretty=format:"%ad %an <%ae>%n%n"$'\t'"%s%n%b" > ChangeLog
      autoreconf -i
      sh configure ${configure_args} --disable-silent-rules
    ;;
    libtiff)
      sh configure ${configure_args}
      $"makeallin"
      return
    ;;
    libusb|libusb-compat-0.1)
      sh autogen.sh ${configure_args}
    ;;
    libxml2)
      git checkout -f master
      sh autogen.sh ${configure_args} --with-icu
    ;;
    libxslt)
      git checkout -f master
      sh autogen.sh ${configure_args}
    ;;
    nasm)
      git checkout -f master
      $"patch_nasm"
      sh autogen.sh
      sh configure ${configure_args}
    ;;
    nettle)
      git checkout -f nettle-2.7-fixes
      sh .bootstrap
      sh configure ${configure_args}
    ;;
    ogg)
      sh autogen.sh ${configure_args}
    ;;
    orc)
      git checkout -f master
      sh autogen.sh ${configure_args} \
                    --disable-gtk-doc{,-html,-pdf} \
                    --without-html-dir
    ;;
    pkg-config)
      git checkout -f master
      sh autogen.sh ${configure_args} \
                    --disable-host-tool \
                    --with-internal-glib \
                    --with-pc-path=${deps_destroot}/lib/pkgconfig:${deps_destroot}/share/pkgconfig:/usr/lib/pkgconfig
    ;;
    python) # python 2.7
      ${hg} checkout -C 2.7
      $"mkdircd" build
      sh ../configure ${configure_args}
    ;;
    readline)
      git checkout -f master
      $"patch_readline"
      sh configure ${configure_args} --with-curses --enable-multibyte
    ;;
    SDL)
      # note: mercurial repository must be separated a build directory.
      $"mkdircd" build
      sh ../configure ${configure_args}
      $"makeallin"
      # note: theora will not find sdl2.pc.
      cd ${deps_destroot}/lib/pkgconfig
      ln -s sdl{2,}.pc
      cd -
      DocCompress_ SDL
      return
    ;;
    SDL_sound)
      sh bootstrap
      # note: mercurial repository must be separated a build directory.
      $"mkdircd" build
      sh ../configure ${configure_args}
    ;;
    theora)
      sh autogen.sh ${configure_args} \
                    --disable-{oggtest,vorbistest,examples,asm}
    ;;
    vorbis)
      sh autogen.sh ${configure_args}
    ;;
    xz)
      sh autogen.sh
      sh configure ${configure_args}
      $"makeallin"
      return
    ;;
    zlib)
      git checkout -f master
      sh configure --prefix=${deps_destroot}
    ;;
  esac
  $"makeallin"
  DocCompress_ $1
} # end BuildDevel_

BuildTools_ ()
{
  set -- \
    gettext \
    m4 \
    autoconf \
    automake \
    libtool  \
    coreutils \
    help2man \
    texinfo \
    p7zip
    
  local CPPFLAGS="$CPPFLAGS -I$toolprefix/include"
  local LDFLAGS="$LDFLAGS -L$toolprefix/lib"
  local configure_args="${configure_args/$deps_destroot/$toolprefix}"
    
  install -d $workroot/tools
  for x in $@
  do
    cd $workroot/tools
    case $x in
      texinfo) # texinfo required from libtasn1-devel
        cp -RHf ${srcroot}/texinfo .
        cd texinfo
        sh autogen.sh
        sh configure $configure_args
      ;;
      *)
        local pkg=pkgsrc_$x; pkg=${!pkg}
        tar xf $srcroot/$pkg
        case $x in
          p7zip)
            cd p7zip_9.20.1
          ;;
          *)
            cd ${pkg%.tar.*}
          ;;
        esac
      ;;
    esac
    
    case $x in
      autoconf|automake)
        sh configure  $configure_args
      ;;
      coreutils)
        sh configure  $configure_args \
                      --program-prefix=g \
                      --enable-threads=posix \
                      --without-gmp \
                      FORCE_UNSAFE_CONFIGURE=1
        $"makeallin"
        cd $toolprefix/bin
        ln -fs {g,}readlink
        continue
      ;;
      gettext)
        sh configure  $configure_args \
                      --disable-{csharp,native-java,openmp} \
                      --without-{cvs,emacs,git} \
                      --with-included-{gettext,glib,libcroro,libunistring,libxml}
      ;;
      help2man) # help2man required from texinfo
        sh configure  $configure_args
      ;;
      libtool)
        sh configure  $configure_args --program-prefix=g
        $"makeallin"
        cd $toolprefix/bin
        ln -sf {g,}libtool
        ln -sf {g,}libtoolize
        continue
      ;;
      m4)
        sh configure  $configure_args \
                      --enable-c++ \
                      --disable-gcc-warnings \
                      --with-syscmd-shell
        $"makeallin"
        cd $toolprefix/bin
        ln -sf {g,}m4
        continue
      ;;
      p7zip)
        sed "
          s#^OPTFLAGS=-O#OPTFLAGS=-O3 -mtune=native#
          s#^CXX=c++#CXX=$CXX#
          s#^CC=cc#CC=$CC#
        " makefile.macosx_64bits > makefile.machine
        make $make_args all3
        make DEST_HOME=$toolprefix install
        continue
      ;;
    esac
    $"makeallin"
    continue
  done
  unset x
}


Bootstrap_ ()
{
  # -------------------------------------- begin preparing
  rm -rf ${workroot} ${destroot}
  sed "s|@DATE@|$(date +%F)|g" ${proj_root}/scripts/main.applescript | osacompile -o ${destroot}
  install -m 0644 ${proj_root}/nxwine.icns ${destroot}/Contents/Resources/droplet.icns
  install -d  ${deps_destroot}/{bin,include,share/{man,doc}} \
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
    hdiutil create -attach -type SPARSEBUNDLE -fs HFS+ -size 1g -volname ${proj_uuid} ${toolbundle}
    trap "hdiutil detach ${toolprefix}; rm -rf ${toolbundle}" EXIT
    BuildTools_
    trap EXIT
  fi
  trap "hdiutil detach ${toolprefix}" EXIT
  
  # --------------------------------- begin build
  BuildDevel_ icu
  BuildDeps_  ${pkgsrc_gettext}
  BuildDeps_  ${pkgsrc_libelf} --disable-compat
  BuildDeps_  ${pkgsrc_libtool}
  BuildDevel_ pkg-config
  BuildDevel_ readline
  BuildDevel_ zlib
  BuildDevel_ xz
  BuildDevel_ python
  BuildDevel_ libxml2
  BuildDevel_ libxslt
} # end Bootstrap_

BuildStage1_ ()
{
  BuildDevel_ gmp-5.1
  BuildDevel_ libffi
  BuildDevel_ glib
} # end BuildStage1_

BuildStage2_ ()
{
#  BuildDevel_ guile
  BuildDeps_  ${pkgsrc_libtasn1}
  BuildDevel_ nettle
  BuildDevel_ gnutls
  BuildDevel_ libusb
  BuildDevel_ libusb-compat-0.1
} # end BuildStage2_

BuildStage3_ ()
{
  BuildDevel_ orc
  BuildDeps_  ${pkgsrc_odbc}
  BuildDevel_ libpng
  BuildDevel_ freetype                # freetype required libpng
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
  local bindir=${wine_destroot}/bin
  local docdir=${wine_destroot}/share/doc/winetricks
  local libexecdir=${wine_destroot}/libexec

  # -------------------------------------- cabextract
  BuildDeps_ ${pkgsrc_cabextract}
  install -d ${docdir}/cabextract-1.4
  cp ${workroot}/cabextract-1.4/{AUTHORS,ChangeLog,COPYING,NEWS,README,TODO} $_
  
  # -------------------------------------- winetricks
  InstallWinetricks_ ()
  {
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
  7z x -y -o${datadir}/nxwine/programs/7-Zip -x'!$*' ${srcroot}/${pkgsrc_7z}
} # end BuildStage5_

BuildWine_ ()
{
  $"mkdircd" ${workroot}/wine
  ${srcroot}/wine/configure --prefix=${wine_destroot} \
                            --build=${triple} \
                            --with-opengl \
                            --without-{capi,cms,gphoto,gsm,oss,sane,v4l} \
                            --x-includes=/opt/X11/include \
                            --x-libraries=/opt/X11/lib
  $"makeallin"
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
        set -- ${datadir}/wine/fonts
        
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
        set -- $TMPDIR/$$$LINENO.\$\$
        
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
        set -- ${workroot}/system32
        $"mkdircd" $1
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
    m4  -D_PLIST=${destroot}/Contents/Info.plist \
        -D_WINE_VERSION=${wine_version} \
        -D_PROJ_VERSION=${proj_version} \
        -D_PROJ_DOMAIN=${proj_domain} \
<<\@EOS | sh -x
changequote([, ])dnl
define([_PB], [/usr/libexec/PlistBuddy -c "$1" _PLIST])dnl
define([_DT], [dnl
_PB(Add :CFBundleDocumentTypes:$1:CFBundleTypeExtensions array)
_PB(Add :CFBundleDocumentTypes:$1:CFBundleTypeExtensions:0 string $2)
_PB(Add :CFBundleDocumentTypes:$1:CFBundleTypeIconFile string droplet)
_PB(Add :CFBundleDocumentTypes:$1:CFBundleTypeName string $3)
_PB(Add :CFBundleDocumentTypes:$1:CFBundleTypeRole string Viewer)])dnl
dnl
dnl
_PB([Set :CFBundleIconFile droplet])
_PB([Add :NSHumanReadableCopyright string _WINE_VERSION, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine])
_PB([Add :CFBundleVersion string _PROJ_VERSION])
_PB([Add :CFBundleIdentifier string _PROJ_DOMAIN])
_DT(1,  exe,    Windows Executable File)
_DT(2,  msi,    Microsoft Windows Installer)
_DT(3,  lnk,    Windows Shortcut File)
_DT(4,  7z,     7z Archive)
_DT(5,  cab,    cab Archive)
_DT(6,  lha,    lha Archive)
_DT(7,  lzh,    lzh Archive)
_DT(8,  lzma,   lzma Archive)
_DT(9,  rar,    rar Archive)
_DT(10, xz,     xz Archive)
_DT(11, zip,    zip Archive)
@EOS
    
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
    set -- $TMPDIR/$$$LINENO.\$\$ ${proj_root}/${proj_name}_${proj_version}_${wine_version/wine-}.dmg
    
    install -d $1/.resources
    mv ${destroot} $_
    osacompile -xo $1/"NXWine Installer".app ${proj_root}/scripts/installer.applescript
    install -m 0644 ${proj_root}/nxwine.icns $1/"NXWine Installer".app/Contents/Resources/applet.icns
    hdiutil create -ov -format UDBZ -srcdir $1 -volname ${proj_name} $2
    rm -rf $1
} # end BuildDmg_

# -------------------------------------- patch
patch_icu (){ m4 -D_PREFIX=${deps_destroot} <<\@EOS | patch -Np1
--- a/config/mh-darwin
+++ a/config/mh-darwin
@@ -31,7 +31,7 @@
 ifeq ($(ENABLE_RPATH),YES)
 LD_SONAME = -Wl,-compatibility_version -Wl,$(SO_TARGET_VERSION_MAJOR) -Wl,-current_version -Wl,$(SO_TARGET_VERSION) -install_name $(libdir)/$(notdir $(MIDDLE_SO_TARGET))
 else
-LD_SONAME = -Wl,-compatibility_version -Wl,$(SO_TARGET_VERSION_MAJOR) -Wl,-current_version -Wl,$(SO_TARGET_VERSION) -install_name $(notdir $(MIDDLE_SO_TARGET))
+LD_SONAME = -Wl,-compatibility_version -Wl,$(SO_TARGET_VERSION_MAJOR) -Wl,-current_version -Wl,$(SO_TARGET_VERSION) -install_name _PREFIX/lib/$(notdir $(MIDDLE_SO_TARGET))
 endif
 
 ## Compiler switch to embed a runtime search path
@EOS
}

patch_readline (){ patch -Np1 <<\@EOS
--- a/support/shobj-conf
+++ b/support/shobj-conf
@@ -157,19 +157,19 @@ freebsd[4-9]*|freebsdelf*|dragonfly*)
 	;;
 
 # Darwin/MacOS X
-darwin[89]*|darwin1[012]*)
+darwin[89]*|darwin1[0-9]*)
 	SHOBJ_STATUS=supported
 	SHLIB_STATUS=supported
 	
 	SHOBJ_CFLAGS='-fno-common'
 
-	SHOBJ_LD='MACOSX_DEPLOYMENT_TARGET=10.3 ${CC}'
+	SHOBJ_LD='${CC}'
 
 	SHLIB_LIBVERSION='$(SHLIB_MAJOR)$(SHLIB_MINOR).$(SHLIB_LIBSUFF)'
 	SHLIB_LIBSUFF='dylib'
 
-	SHOBJ_LDFLAGS='-dynamiclib -dynamic -undefined dynamic_lookup -arch_only `/usr/bin/arch`'
-	SHLIB_XLDFLAGS='-dynamiclib -arch_only `/usr/bin/arch` -install_name $(libdir)/$@ -current_version $(SHLIB_MAJOR)$(SHLIB_MINOR) -compatibility_version $(SHLIB_MAJOR) -v'
+	SHOBJ_LDFLAGS='-dynamiclib -dynamic -undefined dynamic_lookup'
+	SHLIB_XLDFLAGS='-dynamiclib -install_name $(libdir)/$@ -current_version $(SHLIB_MAJOR)$(SHLIB_MINOR) -compatibility_version $(SHLIB_MAJOR) -v'
 
 	SHLIB_LIBS='-lncurses'	# see if -lcurses works on MacOS X 10.1 
 	;;
@@ -186,11 +186,11 @@ darwin*|macosx*)
 	SHLIB_LIBSUFF='dylib'
 
 	case "${host_os}" in
-	darwin[789]*|darwin1[012]*)	SHOBJ_LDFLAGS=''
-			SHLIB_XLDFLAGS='-dynamiclib -arch_only `/usr/bin/arch` -install_name $(libdir)/$@ -current_version $(SHLIB_MAJOR)$(SHLIB_MINOR) -compatibility_version $(SHLIB_MAJOR) -v'
+	darwin[789]*|darwin1[0-9]*)	SHOBJ_LDFLAGS=''
+			SHLIB_XLDFLAGS='-dynamiclib -install_name $(libdir)/$@ -current_version $(SHLIB_MAJOR)$(SHLIB_MINOR) -compatibility_version $(SHLIB_MAJOR) -v'
 			;;
 	*)		SHOBJ_LDFLAGS='-dynamic'
-			SHLIB_XLDFLAGS='-arch_only `/usr/bin/arch` -install_name $(libdir)/$@ -current_version $(SHLIB_MAJOR)$(SHLIB_MINOR) -compatibility_version $(SHLIB_MAJOR) -v'
+			SHLIB_XLDFLAGS='-install_name $(libdir)/$@ -current_version $(SHLIB_MAJOR)$(SHLIB_MINOR) -compatibility_version $(SHLIB_MAJOR) -v'
 			;;
 	esac
 
@EOS
}

patch_nasm (){ patch -Np1 <<\@EOS
--- a/Makefile.in
+++ b/Makefile.in
@@ -64,10 +64,10 @@ endif
 	$(CC) -E $(ALL_CFLAGS) -o $@ $<
 
 .txt.xml:
-	$(ASCIIDOC) -b docbook -d manpage -o $@ $<
+	: -b docbook -d manpage -o $@ $<
 
 .xml.1:
-	$(XMLTO) man --skip-validation $< 2>/dev/null
+	: man --skip-validation $< 2>/dev/null
 
 
 #-- Begin File Lists --#
@@ -191,9 +191,6 @@ install: nasm$(X) ndisasm$(X)
 	$(MKDIR) -p $(INSTALLROOT)$(bindir)
 	$(INSTALL_PROGRAM) nasm$(X) $(INSTALLROOT)$(bindir)/nasm$(X)
 	$(INSTALL_PROGRAM) ndisasm$(X) $(INSTALLROOT)$(bindir)/ndisasm$(X)
-	$(MKDIR) -p $(INSTALLROOT)$(mandir)/man1
-	$(INSTALL_DATA) $(srcdir)/nasm.1 $(INSTALLROOT)$(mandir)/man1/nasm.1
-	$(INSTALL_DATA) $(srcdir)/ndisasm.1 $(INSTALLROOT)$(mandir)/man1/ndisasm.1
 
 clean:
 	$(RM) -f *.$(O) *.s *.i
@EOS
}

patch_libjpeg-turbo (){ patch -Np1 <<\@EOS
diff --git a/Makefile.am b/Makefile.am
index 67ac7c1..2a8efdc 100644
--- a/Makefile.am
+++ b/Makefile.am
@@ -144,11 +144,11 @@ dist_man1_MANS = cjpeg.1 djpeg.1 jpegtran.1 rdjpgcom.1 wrjpgcom.1
 DOCS= coderules.txt jconfig.txt change.log rdrle.c wrrle.c BUILDING.txt \
 	ChangeLog.txt
 
-docdir = $(datadir)/doc
+docdir = $(datadir)/doc/libjpeg-turbo
 dist_doc_DATA = README README-turbo.txt libjpeg.txt structure.txt usage.txt \
 	wizard.txt 
 
-exampledir = $(datadir)/doc
+exampledir = $(datadir)/doc/libjpeg-turbo
 dist_example_DATA = example.c
 
 
@EOS
}

# -------------------------------------- begin processing section
#Bootstrap_
#BuildStage1_
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
