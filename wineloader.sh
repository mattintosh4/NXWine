#!/bin/bash
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
export PATH=${prefix}/libexec:${prefix}/bin:/usr/bin:/bin:/usr/sbin:/sbin
export LANG=${LANG:=ja_JP.UTF-8}

# glu32.dll still needs Mesa libraries.
export DYLD_FALLBACK_LIBRARY_PATH=/opt/X11/lib:/usr/X11/lib

# special Windows application path
export WINEPATH=${prefix}/lib/wine/programs/7-Zip

if [ ! -n "${WINEPREFIX}" ]; then
    export WINEPREFIX=${HOME}/.wine
fi

if [ ! -d "${WINEPREFIX}" ]; then
    . createwineprefix
fi

exec ${prefix}/libexec/wine "$@"
