#!/bin/sh
export PATH=/Applications/NXWine.app/Contents/Resources/bin:/usr/bin:/bin:/usr/sbin:/sbin
type wine || exit
exec /Applications/NXWine.app/Contents/Resources/libexec/winetricks "$@"
