#!/bin/sh
export PATH=${prefix=/Applications/NXWine.app/Contents/Resources}/bin:/usr/bin:/bin:/usr/sbin:/sbin
which ${prefix}/bin/wine || { echo "wine not found."; exit 1; }
exec ${prefix}/libexec/winetricks "$@"