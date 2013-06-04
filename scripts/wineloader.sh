#!/bin/sh
#
# NXWine - No X11 Wine for Mac OS X
#
# Created by mattintosh4 on @DATE@.
# Copyright (C) 2013 mattintosh4, https://github.com/mattintosh4/NXWine
#

# note: some debug options is enabled because this script is incomplete yet.
case ${WINEDEBUG-X} in X) export PS4="\[\e[33m\]DEBUG:\[\e[m\] " ; set -x ; export WINEDEBUG=+loaddll ;; esac

# ------------------------------------ begin preparing
prefix=/Applications/NXWine.app/Contents/Resources
wine=${prefix}/libexec/wine

export PATH=${prefix}/libexec:${prefix}/bin:$(dirname ${prefix})/SharedSupport/bin:/usr/bin:/bin:/usr/sbin:/sbin
export LANG=${LANG:=ja_JP.UTF-8}

# note: WINEPREFIX variable should be set for initializing.
export WINEPREFIX="${WINEPREFIX:=${HOME}/.wine}"

# note: glu32.dll still needs Mesa libraries.
export DYLD_FALLBACK_LIBRARY_PATH=/opt/X11/lib:/usr/X11/lib

# special Windows applications path
#export WINEPATH=

# note: usage options and non-arguments have to be processed before standard run.
case $1 in (--help|--version|"") exec ${wine} $1 ;; esac

CreateWineprefix_ ()
{
    set -e
    ${wine} wineboot.exe --init
    ${prefix}/share/nxwine/nativedlls/nativedlls.exe x -y -o"${WINEPREFIX}"/drive_c/windows
    cat <<__REGEDIT4__ | WINEDEBUG= ${wine} regedit -
[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
$(printf '"*D3DCompiler_%d"="native"\n' {37..43})
"*XAPOFX1_1"="native"
"*amstream"="native"
$(printf '"*d3dx9_%d"="native"\n' {24..43})
"*ddrawex"="native"
"*dinput"="native"
"*dinput8"="native"
"*dplayx"="native"
"*gdiplus"="builtin,native"
"*hhctrl.ocx"="native"
"*l3codecx"="native"
"*mciqtz32"="native"
"*quartz"="native"
__REGEDIT4__
    
    WINEDEBUG= ${wine} regsvr32.exe \
        hhctrl.ocx \
        l3codecx.ax \
{\
XAudio2_{0..7},\
amstream,\
ddrawex,\
dinput,\
dplayx,\
quartz}.dll
    
    set +e
} # end CreateWineprefix_

# ------------------------------------ begin standard run
if [ ! -d "${WINEPREFIX}" ]; then
    CreateWineprefix_
fi

set -x
exec ${wine} "$@"
