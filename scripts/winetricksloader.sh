#!/bin/sh
prefix=/Applications/NXWine.app/Contents/Resources
export PATH=${prefix}/bin:/usr/bin:/bin:/usr/sbin:/sbin
type wine || exit
exec ${prefix}/libexec/winetricks "$@"
