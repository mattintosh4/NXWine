#!/bin/sh

export PATH=/Applications/NXWine.app/Contents/Resources/bin:/usr/bin:/bin:/usr/sbin:/sbin

## WINEPREFIX
if [ "${WINEPREFIX+set}" != set ]; then
    export WINEPREFIX="$(osascript -e 'POSIX path of (path to library folder from user domain) & "NXWine/prefixies/default"')"
fi

## Wine
type wine || exit

## Zenity
if [ -x "$ZENITY" ]; then
    PATH+=:"$(dirname "$ZENITY")"
elif [ -x /opt/local/bin/zenity ]; then
    PATH+=:/opt/local/bin
elif [ -x /usr/local/bin/zenity ]; then
    PATH+=:/usr/local/bin
fi

exec /Applications/NXWine.app/Contents/Resources/libexec/winetricks "$@"
