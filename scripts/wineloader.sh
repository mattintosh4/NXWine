#!/bin/sh
#
# NXWine - No X11 Wine for Mac OS X
#
# Created by mattintosh4 on @DATE@.
# Copyright (C) 2013 mattintosh4, https://github.com/mattintosh4/NXWine
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
PREFIX=/Applications/NXWine.app/Contents/Resources
WINE=${PREFIX}/libexec/wine

case $1 in
  --help|--version|"")
    exec ${WINE} "$@"
  ;;
esac

export PATH=${PREFIX}/bin:${PATH}

if [ "${LANG+set}" != set ]; then
  export LANG=ja_JP.UTF-8
fi

if [ "${WINEPREFIX+set}" != set ]; then
  export WINEPREFIX=$(osascript -e 'POSIX path of (path to library folder from user domain)')NXWine/prefixies/default
fi

if [ ! -d "${WINEPREFIX}" ] || [ "$2" = --force-init ]; then
  ${WINE} wineboot.exe -i
  ${PREFIX}/share/wine/init.py
fi

printf '\033[4;32m%s\033[m\n' "$*" >&2
exec ${WINE} "$@"
