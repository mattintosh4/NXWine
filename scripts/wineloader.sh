#!/bin/sh
#
# NXWine - No X11 Wine for Mac OS X
#
# Created by mattintosh4 on @DATE@.
# Copyright (C) 2013 mattintosh4, https://github.com/mattintosh4/NXWine
#

# note: some debug options is enabled because this script is incomplete yet.
case ${WINEDEBUG-X} in X) PS4="\[\e[33m\]DEBUG:\[\e[m\] "; set -x; export WINEDEBUG=+loaddll;; esac

# ------------------------------------ begin preparing
prefix=/Applications/NXWine.app/Contents/Resources
export PATH=${prefix}/libexec:${prefix}/bin:$(dirname ${prefix})/SharedSupport/bin:/usr/bin:/bin:/usr/sbin:/sbin
export LANG=${LANG:=ja_JP.UTF-8}

# note: usage options and non-arguments have to be processed before standard run.
case $1 in (--help|--version|"") exec ${prefix}/libexec/wine $1 ;; esac

# note: WINEPREFIX variable should be set for initializing.
export WINEPREFIX="${WINEPREFIX:=${HOME}/.wine}"

# note: glu32.dll still needs Mesa libraries.
export DYLD_FALLBACK_LIBRARY_PATH=/opt/X11/lib:/usr/X11/lib

# special Windows applications path
export WINEPATH=${prefix}/lib/wine/programs/7-Zip

CreateWineprefix_ ()
{
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
} # end CreateWineprefix_

# ------------------------------------ begin standard run
if [ ! -d "${WINEPREFIX}" ]; then
    CreateWineprefix_
fi

set -x
exec ${prefix}/libexec/wine "$@"
