#!/bin/sh
#
# NXWine - No X11 Wine for Mac OS X
#
# Created by mattintosh4 on @DATE@.
# Copyright (C) 2013 mattintosh4, https://github.com/mattintosh4/NXWine
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
prefix=/Applications/NXWine.app/Contents/Resources
wine=${prefix}/libexec/wine
set -- ${wine} "$@"

# note: usage options and non-arguments have to be processed before standard run.
case $2 in (--help|--version|"") exec "$@";; esac

# -------------------------------------
SetEnv_ ()
{
  
  dataprefix="$(osascript -e 'POSIX path of (path to library folder from user domain) & "NXWine"')"
  
  # WINEPREFIX
  if [ "${WINEPREFIX+set}" != set ]; then
    export WINEPREFIX="${dataprefix}"/prefixies/default
  fi
  
  export PATH=${prefix}/libexec:${prefix}/bin:/usr/bin:/bin:/usr/sbin:/sbin
  export LANG=${LANG:=ja_JP.UTF-8}
  
  # note: glu32.dll still needs Mesa libraries.
  export DYLD_FALLBACK_LIBRARY_PATH=/opt/X11/lib:/usr/lib
  
  # special Windows applications path
  #export WINEPATH=
  
} # end SetEnv_

SetDebug_ ()
{
  export PS4="\[\e[33m\]DEBUG:\[\e[m\] "
  set -x
  export WINEDEBUG=+loaddll
  
} # end SetDebug_

CreateWP_ ()
{
  save_WINEDEBUG="${WINEDEBUG}"
  WINEDEBUG=
  
  # initialize
  mkdir -p "${WINEPREFIX}"
  ${wine} wineboot.exe --init
  
  # symlink to NXWinetricks cache directory
  ln -hfs "${dataprefix}"/caches "${WINEPREFIX}"/drive_c/nxwinetricks
  
  # extract native dlls pack
  ${wine} 7z.exe x -y -o'C:\windows' ${prefix}/share/nxwine/nativedlls/nativedlls.exe
  
  # register override settings
  cat <<@EOS | ${wine} regedit.exe -
[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
$(
  set -- \
    advpack               \
    amstream              \
    atl100                \
    comcat                \
    d3dcompiler_{33..43}  \
    d3dim                 \
    d3drm                 \
    d3dx9_{24..43}        \
    d3dxof                \
    ddrawex               \
    devenum               \
    dinput{,8}            \
    dplayx                \
    dpwsockx              \
    dxdiag.exe            \
    dxdiagn               \
    mciqtz32              \
    msvcp100              \
    msvcr100              \
    oleaut32              \
    olepro32              \
    qcap                  \
    qedit                 \
    quartz                \
    vcomp100              \
    xapofx1_1             \
    xinput1_{1..3}        \
    xinput9_1_0
  
  printf '"*%s"="native"\n' "$@"
  
  set -- \
    gdiplus
  
  printf '"*%s"="builtin,native"\n' "$@"
)
@EOS
  
  # register inf and dlls
  (
    # inf
    set -- \
      c:\\windows\\system32\\rsrc_dinput\\dimaps \
      diactfrm  \
      dinput    \
      ks        \
      kscaptur  \
      ksfilter  \
      ksreg
    
    for f; do ${wine} rundll32.exe setupapi.dll,InstallHinfSection DefaultInstall 128 ${f}.inf; done
    
    # remove dinput resources
    rm -rf "$(WINEDEBUG= ${wine} winepath.exe --unix c:\\windows\\system32\\rsrc_dinput)"
    
    # dlls
    set -- \
      amstream.dll        \
      comcat.dll          \
      ddrawex.dll         \
      devenum.dll         \
      diactfrm.dll        \
      dinput.dll          \
      dplayx.dll          \
      dpnhupnp.dll        \
      dpvacm.dll          \
      dpvoice.dll         \
      dpvvox.dll          \
      dsdmo{,prp}.dll     \
      dxdiagn.dll         \
      dx{7,8}vb.dll       \
      encapi.dll          \
      ksolay.ax           \
      ksproxy.ax          \
      l3codecx.ax         \
      mpg2splt.ax         \
      msvbvm60.dll        \
      mswebdvd.dll        \
      oleaut32.dll        \
      olepro32.dll        \
      qasf.dll            \
      qcap.dll            \
      qdv.dll             \
      qdvd.dll            \
      qedit.dll           \
      xaudio2_{0..7}.dll  \
      quartz.dll
    
    ${wine} regsvr32.exe "$@"
  )
  
  
  
  if [ "$2" = --force-init ]; then
    exit
  fi
  
  WINEDEBUG="${save_WINEDEBUG}"
} # end CreateWP_



# -------------------------------------
SetEnv_

# note: some debug options is enabled because this script is incomplete yet.
if [ "${WINEDEBUG+set}" != set ]; then
  SetDebug_
fi

if [ ! -d "${WINEPREFIX}" ] || [ "$2" = --force-init ]; then
  CreateWP_ "$@"
fi

exec "$@"
