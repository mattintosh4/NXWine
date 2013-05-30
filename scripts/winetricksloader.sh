#!/bin/sh
prefix=/Applications/NXWine.app/Contents/Resources
export PATH=${prefix}/bin:/usr/bin:/bin:/usr/sbin:/sbin
which wine || { echo "wine not found."; exit 1; }
exec ${prefix}/libexec/winetricks "$@"
