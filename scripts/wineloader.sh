#!/bin/sh
#
# NXWine - No X11 Wine for Mac OS X
#
# Created by mattintosh4 on @DATE@.
# Copyright (C) 2013 mattintosh4, https://github.com/mattintosh4/NXWine
#

# some debug options is enabled because this script is incomplete yet.
set -x
export WINEDEBUG=+loaddll

prefix=/Applications/NXWine.app/Contents/Resources
export PATH=${prefix}/libexec:${prefix}/bin:$(dirname ${prefix})/SharedSupport/bin:/usr/bin:/bin:/usr/sbin:/sbin
export LANG=${LANG:=ja_JP.UTF-8}

# glu32.dll still needs Mesa libraries.
export DYLD_FALLBACK_LIBRARY_PATH=/opt/X11/lib:/usr/X11/lib

# special Windows application path
export WINEPATH=${prefix}/lib/wine/programs/7-Zip

if [ ! -n "${WINEPREFIX}" ]; then
    export WINEPREFIX=${HOME}/.wine
fi

if [ ! -d "${WINEPREFIX}" ]; then
    set -e
    ${prefix}/libexec/wine wineboot.exe --init
    install -v -m 0644 ${prefix}/lib/wine/nativedlls/* "${WINEPREFIX}"/drive_c/windows/system32
    cat <<__REGEDIT4__ | wine regedit -
[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
"*d3dx9_42"="native"
"*d3dx9_43"="native"
"*devenum"="native"
"*dmband"="native"
"*dmcompos"="native"
"*dmime"="native"
"*dmloader"="native"
"*dmscript"="native"
"*dmstyle"="native"
"*dmsynth"="native"
"*dmusic"="native"
"*dplayx"="native"
"*dsound"="native"
"*dswave"="native"
"*gdiplus"="builtin,native"
"*l3codecx"="native"
"*quartz"="native"
__REGEDIT4__

    ${prefix}/libexec/wine regsvr32.exe \
        {devenum,dmband,dmcompos,dmime,dmloader,dmscript,dmstyle,dmsynth,dmusic,dswave}.dll \
        l3codecx.ax \
        quartz.dll
    set +e
fi

exec ${prefix}/libexec/wine "$@"
