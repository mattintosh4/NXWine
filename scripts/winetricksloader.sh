#!/bin/sh
export PATH=${prefix=/Applications/NXWine.app/Contents/Resources}/bin:/usr/bin:/bin:/usr/sbin:/sbin
type wine || exit
exec ${prefix}/libexec/winetricks "$@"