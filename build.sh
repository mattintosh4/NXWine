#!/usr/bin/env - SHELL=/bin/bash TERM=xterm COMMAND_MODE=unix2003 /bin/bash -ex
PS4="\[\e[31m\]+\[\e[m\] "
TMPDIR=$(getconf DARWIN_USER_TEMP_DIR); HOME=$TMPDIR; export TMPDIR HOME

readonly proj_name=NXWine
readonly proj_uuid=E43FF9C9-669C-4319-8351-FF99AFF3230C
readonly proj_root="$(cd "$(dirname "$0")"; pwd)"
readonly proj_version=$(date +%Y%m%d)
readonly proj_domain=com.github.mattintosh4.${proj_name}

readonly srcroot=${proj_root}/sources
readonly workroot=$TMPDIR/${proj_uuid}
readonly destroot=/Applications/${proj_name}.app
readonly wine_destroot=${destroot}/Contents/Resources
readonly deps_destroot=${destroot}/Contents/SharedSupport
readonly toolprefix=$deps_destroot/local
readonly toolbundle=$proj_root/tools.tar.bz2

# ------------------------------------- local tools
readonly ccache=/usr/local/bin/ccache
readonly git=/usr/local/git/bin/git
readonly hg=/usr/local/bin/hg
[ -x ${ccache} ]
[ -x ${git} ]
[ -x ${hg} ]

# ------------------------------------- extra tools
if [ -x ${FONTFORGE=/opt/local/bin/fontforge} ]; then export FONTFORGE; fi

# ------------------------------------- environment variables
set -a
MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion | cut -d. -f-2)
DEVELOPER_DIR=$(xcode-select -print-path)
SDKROOT=$(xcodebuild -version -sdk macosx${MACOSX_DEPLOYMENT_TARGET} | sed -n '/^Path: /s///p')
[ -n "${MACOSX_DEPLOYMENT_TARGET}" ]
[ -d "${DEVELOPER_DIR}" ]
[ -d "${SDKROOT}" ]

PATH=$(tr '\n' ':' <<@EOS
$deps_destroot/bin
$toolprefix/bin
$(dirname $git)
$(getconf PATH)
@EOS); PATH=${PATH%?}
CC="${ccache} $( xcrun -find gcc-4.2)"
CXX="${ccache} $(xcrun -find g++-4.2)"
CFLAGS="-pipe -O3 -m32 -arch i386 -ffast-math -march=core2 -mtune=core2 -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
CXXFLAGS="$CFLAGS"
CPPFLAGS="-isysroot ${SDKROOT} -I${deps_destroot}/include"
LDFLAGS="-arch i386 -Wl,-search_paths_first -Wl,-headerpad_max_install_names -Wl,-syslibroot,${SDKROOT} -L${deps_destroot}/lib"
ACLOCAL_PATH=$deps_destroot/share/aclocal:$toolprefix/share/aclocal
LANG=ja_JP.UTF-8; LC_ALL=$LANG; gt_cv_locale_ja=$LANG
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

# ------------------------------------- package sources
for pkg in \
  ${pkgsrc_7z=7z920.exe} \
  ${pkgsrc_autoconf=autoconf-2.69.tar.gz} \
  ${pkgsrc_automake=automake-1.13.2.tar.gz} \
  ${pkgsrc_cabextract=cabextract-1.4.tar.gz} \
  ${pkgsrc_coreutils=coreutils-8.21.tar.bz2} \
  ${pkgsrc_gecko=wine_gecko-2.21-x86.msi} \
  ${pkgsrc_gettext=gettext-0.18.2.tar.gz} \
  ${pkgsrc_help2man=help2man-1.41.2.tar.gz} \
  ${pkgsrc_jasper=jasper-1.900.1.tar.bz2} \
  ${pkgsrc_libelf=libelf-0.8.13.tar.gz} \
  ${pkgsrc_libtool=libtool-2.4.2.tar.gz} \
  ${pkgsrc_m4=m4-1.4.16.tar.bz2} \
  ${pkgsrc_mono=wine-mono-0.0.8.msi} \
  ${pkgsrc_odbc=unixODBC-2.3.1.tar.gz} \
  ${pkgsrc_p7zip=p7zip_9.20.1_src_all.tar.bz2} \
; do [ -f $srcroot/$pkg ]; done

# ------------------------------------- utilities functions
makeallins(){ make $make_args && make install; }
mkdircd(){ mkdir -p "${@:?}" && cd "$_"; }
scmcopy(){ cp -RHf $srcroot/${1:?} $workroot; cd $workroot/$1; }
DocCompress_ ()
{
  set -- "tar vcjf ${deps_destroot}/share/doc/doc_${1:?}.tar.bz2 -C ${workroot}" $(cd ${workroot} && find -E $1 -maxdepth 1 -type f -regex '.*/(ANNOUNCE|AUTHORS|CHANGES|ChangeLog|COPYING(.LIB)?|LICENSE|NEWS|README|RELEASE|TODO|VERSION)(\.txt)?')
  [ $# = 1 ] && return || $@
} # end DocCompress_

# ------------------------------------- build processing functions
BuildDeps_ ()
{
  7z x -y -so $srcroot/${1:?} | tar x - -C $workroot
  cd $workroot/${1%%-*}*
  case $1 in
    cabextract-*)
      ./configure ${configure_args/${deps_destroot}/${wine_destroot}}
    ;;
    *)
      shift
      ./configure ${configure_args} "$@"
    ;;
  esac
  $"makeallins"
} # end BuildDeps_

BuildDevel_ ()
{
  $"scmcopy" $1
  case $1 in
    flac)
      ./autogen.sh
      ./configure ${configure_args} \
                  --disable-{asm-optimizations,xmms-plugin}
    ;;
    freetype)
      git checkout -f master
      ./autogen.sh
      ./configure ${configure_args}
      $"makeallins"
      [ -f ${deps_destroot}/lib/libfreetype.6.dylib ]
      DocCompress_ freetype
      return
    ;;
    glib)
      git checkout -f glib-2-36
      ./autogen.sh  ${configure_args} \
                    --disable-{selinux,fam,xattr} \
                    --with-threads=posix \
                    --without-{html-dir,xml-catalog}
    ;;
    gmp-5.1)
      ./.bootstrap
      autoreconf -i
      $"mkdircd" build
      ../configure  ${configure_pre_args} \
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
      ./autogen.sh
      ./configure $configure_args
    ;;
    icu) # rev 33743, release-51-2
      cd source
      ./configure ${configure_args} --enable-rpath --with-library-bits=32
      $"makeallins"
      tar vcjf $deps_destroot/share/doc/icu.tar.bz2 -C $workroot icu/{license,readme}.html
      return
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
      sed -i .orig '/$(datadir)\/doc/s/$/\/libjpeg-turbo/' Makefile.am
      autoreconf -i
      ./configure ${configure_args} --with-jpeg8
      $"makeallins"
      return
    ;;
    libmodplug)
      autoreconf -i
      ./configure $configure_args
    ;;
    libpng)
      git checkout -f libpng16
      autoreconf -i
      ./configure ${configure_args}
    ;;
    libtasn1)
      git checkout -f master
      git log --date=short --pretty=format:"%ad %an <%ae>%n%n"$'\t'"%s%n%b" > ChangeLog
      autoreconf -i
      ./configure $configure_args --disable-silent-rules
      # note: libtasn1-devel will fail with parallel build.
      make
      make install
      return
    ;;
    libtiff)
      ./configure ${configure_args}
      $"makeallins"
      return
    ;;
    libusb|libusb-compat-0.1)
      ./autogen.sh ${configure_args}
    ;;
    libxml2)
      git checkout -f master
      ./autogen.sh ${configure_args} --with-icu --with-python=$deps_destroot
    ;;
    libxslt)
      git checkout -f master
      ./autogen.sh ${configure_args}
    ;;
    mpg123)
      autoreconf -i
      ./configure ${configure_args}
    ;;
    nettle)
      git checkout -f nettle-2.7-fixes
      ./.bootstrap
      ./configure ${configure_args}
    ;;
    ogg)
      sed -i '' 's/--enable-maintainer-mode //' autogen.sh
      sed -i '' 's/-O4 //' configure.in
      ./autogen.sh $configure_args
    ;;
    orc)
      git checkout -f master
      ./autogen.sh  ${configure_args} \
                    --disable-gtk-doc{,-html,-pdf} \
                    --without-html-dir
    ;;
    pkg-config)
      git checkout -f master
      ./autogen.sh  ${configure_args} \
                    --disable-host-tool \
                    --with-internal-glib \
                    --with-pc-path=${deps_destroot}/lib/pkgconfig:${deps_destroot}/share/pkgconfig:/usr/lib/pkgconfig
    ;;
    python) # python 2.7
      ${hg} checkout -C v2.7.5
      $"mkdircd" build
      ../configure ${configure_args}
    ;;
    readline)
      git checkout -f master
      $"patch_readline"
      ./configure ${configure_args} --enable-multibyte --with-curses
    ;;
    SDL)
      $hg checkout -C SDL-1.2
      ./autogen.sh
      # note: mercurial repository must be separated a build directory.
      $"mkdircd" build
      ../configure ${configure_args}
    ;;
    SDL_sound)
      ./bootstrap
      # note: mercurial repository must be separated a build directory.
      $"mkdircd" build
      ../configure ${configure_args}
    ;;
    theora)
      ./autogen.sh ${configure_args} --disable-{oggtest,vorbistest,examples,asm}
    ;;
    vorbis)
      sed -i '' 's/--enable-maintainer-mode //' autogen.sh
      sed -i '' 's/-O4 //' configure.ac
      ./autogen.sh $configure_args
    ;;
    xz)
      ./autogen.sh
      ./configure ${configure_args}
      $"makeallins"
      return
    ;;
    zlib)
      git checkout -f master
      ./configure --prefix=${deps_destroot}
    ;;
    libcroco|cairo|gobject-introspection|harfbuzz|pango|gdk-pixbuf|librsvg)
      ./autogen.sh $configure_args
    ;;
  esac
  $"makeallins"
  DocCompress_ $1
} # end BuildDevel_

BuildTools_ ()
{
  set -- \
    gettext     \
    m4          \
    autoconf    \
    automake    \
    libtool     \
    coreutils   \
    help2man    \
    texinfo     \
    pkg-config  \
    nasm        \
    yasm        \
    p7zip
  
  local CPPFLAGS="${CPPFLAGS/$deps_destroot/$toolprefix}"
  local LDFLAGS="${LDFLAGS/$deps_destroot/$toolprefix}"
  local configure_args="${configure_pre_args/$deps_destroot/$toolprefix}"
  
  set -- dummy "$@"
  while shift && [ "$1" ]
  do
    case $1 in
      # ------------------------------------- scm sources
      nasm)
        $"scmcopy" $1
        git checkout -f master
        $"patch_nasm"
        ./autogen.sh
        ./configure $configure_args
      ;;
      texinfo) # texinfo required from libtasn1-devel
        $"scmcopy" $1
        ./autogen.sh
        ./configure $configure_args
      ;;
      pkg-config)
        $"scmcopy" $1
        git checkout -f master
        ./autogen.sh  $configure_args \
                      --disable-host-tool \
                      --with-internal-glib \
                      --with-pc-path=$(set -- {$deps_destroot/{lib,share},/usr/lib}/pkgconfig; IFS=:; echo "$*")
      ;;
      yasm) # yasm required from mpg123
        $"scmcopy" $1
        git checkout -f master
        sed -i '' 's/--enable-maintainer-mode //' autogen.sh
        ./autogen.sh $configure_args
      ;;
      
      # ------------------------------------- tarball sources
      *)
        eval tar xf $srcroot/\$pkgsrc_$1 -C $workroot
        cd $workroot/$1*
        
        case $1 in
          coreutils)
            ./configure $configure_args \
                        --program-prefix=g \
                        --enable-threads=posix \
                        --without-gmp
            $"makeallins"
            cd $toolprefix/bin
            ln -fs {g,}readlink
            continue
          ;;
          gettext)
            $"mkdircd" prebuild
            ../configure $configure_args
          ;;
          help2man) # help2man required from texinfo
            ./configure $configure_args
          ;;
          libtool)
            ./configure $configure_args --program-prefix=g
            $"makeallins"
            cd $toolprefix/bin
            ln -fs {g,}libtool
            ln -fs {g,}libtoolize
            continue
          ;;
          m4)
            ./configure $configure_args --program-prefix=g
            $"makeallins"
            cd $toolprefix/bin
            ln -fs {g,}m4
            continue
          ;;
          p7zip)
            sed "
              s#^CXX=c++#CXX=$CXX#
              s#^CC=cc#CC=$CC#
            " makefile.macosx_32bits > makefile.machine
            sed -i "" "
              s#444#644#g
              s#555#755#g
              s#777#755#g
            " install.sh
            make $make_args all3
            make DEST_HOME=$toolprefix install
            continue
          ;;
          *)
            ./configure $configure_args
          ;;
        esac
      ;;
    esac
    $"makeallins"
  done
  tar cjf $toolbundle -C $(dirname $toolprefix) $(basename $toolprefix)
}


Bootstrap_ ()
{
# ------------------------------------- begin preparing
  rm -rf ${workroot} ${destroot}
  sed "s|@DATE@|$(date +%F)|g" ${proj_root}/scripts/main.applescript | osacompile -s -o ${destroot}
  install -m 0644 ${proj_root}/nxwine.icns ${destroot}/Contents/Resources/droplet.icns
  install -d  ${deps_destroot}/{bin,include,share/{man,doc}} \
              ${wine_destroot}/lib \
              ${workroot}
  (
    cd ${deps_destroot}
    ln -fhs ../Resources/lib lib
    ln -fhs share/man man
  )
  
  # ------------------------------------- begin tools build
  if [ -f $toolbundle ]
  then
    tar xf $toolbundle -C $deps_destroot
  else
    BuildTools_
  fi
  
  # ------------------------------------- begin build
  BuildDevel_ icu
  BuildDeps_  ${pkgsrc_gettext}
  BuildDeps_  ${pkgsrc_libelf} --disable-compat
  BuildDeps_  ${pkgsrc_libtool}
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
  BuildDevel_ libtasn1
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
  BuildDevel_ libjpeg-turbo
  BuildDevel_ libtiff
  BuildDeps_  ${pkgsrc_jasper} --disable-opengl --without-x
  BuildDevel_ libicns
} # end BuildStage3_

BuildStage3a_ ()
{
  BuildDevel_ libcroco
  BuildDevel_ cairo
  BuildDevel_ gobject-introspection
  BuildDevel_ harfbuzz
  BuildDevel_ pango
  BuildDevel_ gdk-pixbuf
  BuildDevel_ librsvg
}

BuildStage4_ ()
{
  BuildDevel_ libmodplug
  BuildDevel_ ogg
  BuildDevel_ vorbis
  BuildDevel_ flac
  BuildDevel_ SDL                     # SDL required nasm
  BuildDevel_ mpg123                  # mpg123 required SDL
  BuildDevel_ SDL_sound
  BuildDevel_ theora                  # libtheora required SDL
} # end BuildStage4_

BuildStage5_ ()
{
  set -- $wine_destroot
  # ------------------------------------- cabextract
  BuildDeps_ $pkgsrc_cabextract
  (set -- $1/share/doc/cabextract-1.4 && mkdir -p $1 && install -m 0644 $workroot/cabextract-1.4/{AUTHORS,ChangeLog,COPYING,NEWS,README,TODO} $1) || false
  # ------------------------------------- winetricks
  (set -- $1/libexec                  && mkdir -p $1 && install -m 0755 $srcroot/winetricks/src/winetricks      $1) || false
  (set -- $1/share/man/man1           && mkdir -p $1 && install -m 0644 $srcroot/winetricks/src/winetricks.1    $1) || false
  (set -- $1/share/doc/winetricks     && mkdir -p $1 && install -m 0644 $srcroot/winetricks/src/COPYING         $1) || false
  # ------------------------------------- nxwinetricks
  (set -- $1/bin                      && mkdir -p $1 && install -m 0755 $proj_root/scripts/winetricksloader.sh  $1/winetricks) || false
  # ------------------------------------- 7-Zip
  7z x -y -o$1/share/nxwine/programs/7-Zip -x\!\$\* $srcroot/$pkgsrc_7z
} # end BuildStage5_

BuildWine_ ()
{
  $"mkdircd" $workroot/wine
  $srcroot/wine/configure --prefix=$wine_destroot \
                          --build=$triple \
                          --with-opengl \
                          --without-{capi,cms,gphoto,gsm,oss,sane,v4l} \
                          --x-includes=/opt/X11/include \
                          --x-libraries=/opt/X11/lib
  $"makeallins"
  
  set -- install_name_tool -add_rpath /usr/lib $wine_destroot
  $@/bin/wine
  $@/bin/wineserver
  $@/lib/libwine.1.0.dylib
  
  (set -- $wine_destroot/libexec && mkdir -p $1 && mv $wine_destroot/bin/wine $1) || false
} # end BuildWine_

BuildStage6_ ()
{
  local bindir=$wine_destroot/bin
  local libdir=$wine_destroot/lib
  local datadir=$wine_destroot/share
  local docdir=$datadir/doc
  
  (set -- $datadir/wine/gecko && mkdir -p $1 && install -m 0644 $srcroot/$pkgsrc_gecko  $1) || false
  (set -- $datadir/wine/mono  && mkdir -p $1 && install -m 0644 $srcroot/$pkgsrc_mono   $1) || false
  (set -- $docdir/wine        && mkdir -p $1 && install -m 0644 $srcroot/wine/{ANNOUNCE,AUTHORS,COPYING.LIB,LICENSE,README,VERSION} $1) || false
  
  # ------------------------------------- fonts
  # note: some fonts are duplicated with system fonts. using 'rm' command only is not useful.
  find $datadir/wine/fonts -name "*.ttf" | egrep "(symbol|tahoma(bd)?|wingding).ttf" | xargs rm
  tar xf $srcroot/fonts/Konatu_ver_20121218.zip   -C $docdir
  tar xf $srcroot/fonts/sazanami-20040629.tar.bz2 -C $docdir
  mv $docdir/*/*.ttf $datadir/wine/fonts
  
  # ------------------------------------- inf
  (set -- $datadir/wine/wine.inf && mv $1 $1.orig && m4 $proj_root/scripts/inf.m4 | cat $1.orig /dev/fd/3 3<&0 | uconv -f UTF-8 -t UTF-8 --add-signature -o $1) || false
  
  # ------------------------------------- executables
  install -m 0755 $proj_root/scripts/wineloader.sh    $bindir/wine
  install -m 0755 $proj_root/scripts/nxwinetricks.sh  $bindir/nxwinetricks
  sed -i "" "s|@DATE@|$(date +%F)|g" $bindir/{wine,nxwinetricks}
  
  # ------------------------------------- native dlls
  InstallNativedlls_ ()
  {
    set -- $workroot/system32
    $"mkdircd" $1
    install -m 0644 $srcroot/nativedlls/FL_gdiplus_dll_____X86.3643236F_FC70_11D3_A536_0090278A1BB8 gdiplus.dll
    7z x -y $srcroot/nativedlls/directx_feb2010_redist.exe dxnt.cab
    7z x -y dxnt.cab l3codecx.ax {\
amstream,\
ddrawex,\
dinput,\
dinput8,\
dplayx,\
mciqtz32,\
quartz}.dll
    
    7z x -y $srcroot/nativedlls/directx_Jun2010_redist.exe \*_x86.cab
    find ./*_x86.cab | while read
    do
      7z x -y $REPLY {\
D3DCompiler,\
XAPOFX1,\
XAudio2,\
d3dx9}_\*.dll
    done
    # note: XAPOFX1_3.dll in Mar2009_XAudio_x86.cab is old
    7z x -y Aug2009_XAudio_x86.cab XAPOFX1_3.dll
    rm *.cab
    
    7z a -sfx $datadir/nxwine/nativedlls/nativedlls.exe $1
  }
  InstallNativedlls_
    
  # ------------------------------------- plist
  wine_version=$(GIT_DIR=${srcroot}/wine/.git git describe HEAD 2>/dev/null)
  : ${wine_version:?}
  
  m4  -D_PLIST=$destroot/Contents/Info.plist \
      -D_PROJ_DOMAIN=$proj_domain \
      -D_PROJ_VERSION=$proj_version \
      -D_WINE_VERSION=$wine_version \
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
_DT(1,  exe,  Windows Executable File)
_DT(2,  msi,  Microsoft Windows Installer)
_DT(3,  lnk,  Windows Shortcut File)
_DT(4,  7z,   7z Archive)
_DT(5,  cab,  cab Archive)
_DT(6,  lha,  lha Archive)
_DT(7,  lzh,  lzh Archive)
_DT(8,  lzma, lzma Archive)
_DT(9,  rar,  rar Archive)
_DT(10, xz,   xz Archive)
_DT(11, zip,  zip Archive)
@EOS
  
  # faenza icon theme
  (set -- faenza-icon-theme_1.3 && unzip -od $docdir/$1 $srcroot/$1.zip AUTHORS ChangeLog COPYING README) || false
  (set -- $docdir/nxwine && mkdir -p $1 && install -m 0644 $proj_root/COPYING $1) || false
  
  # remove unnecessary files
  rm -f ${libdir:?}/*.{a,la}
  rm -rf ${datadir:?}/applications
} # end BuildStage6_

BuildDmg_ ()
{
  set -- $TMPDIR/$$$LINENO.\$\$
  rm -rf $toolprefix ${deps_destroot:?}/{include,share/aclocal}
  (set -- $1/.resources && mkdir -p $1 && mv $destroot $1) || false
  (set -- $1/NXWineInstaller.app && osacompile -xo $1 $proj_root/scripts/installer.applescript && install -m 0644 $proj_root/nxwine.icns $1/Contents/Resources/applet.icns) || false
  hdiutil create  -ov \
                  -format UDBZ \
                  -srcdir $1 \
                  -volname $proj_name \
                  $proj_root/${proj_name}_${proj_version}_${wine_version/wine-}.dmg
  rm -rf $1
} # end BuildDmg_

# -------------------------------------- patch
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

# -------------------------------------- begin processing section
Bootstrap_
BuildStage1_
BuildStage2_
BuildStage3_
BuildStage3a_
exit
BuildStage4_
BuildStage5_
BuildWine_
BuildStage6_
BuildDmg_

# -------------------------------------- end processing section

:
afplay /System/Library/Sounds/Hero.aiff
