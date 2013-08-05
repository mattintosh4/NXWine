#!/bin/sh
if [ "${WINEPREFIX+set}" != set ]; then
    export WINEPREFIX="$(osascript -e 'POSIX path of (path to library folder from user domain) & "NXWine/prefixies/default"')"
fi
export PATH=/Applications/NXWine.app/Contents/Resources/bin:/usr/bin:/bin:/usr/sbin:/sbin
type wine || exit
exec /Applications/NXWine.app/Contents/Resources/libexec/winetricks "$@"
