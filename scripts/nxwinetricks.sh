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
export LANG=${LANG:=ja_JP.UTF-8}

# note: suppress wine debug messages if WINEDEBUG does not set.
if ! [ "${WINEDEBUG+set}" ] ; then export WINEDEBUG=; fi

usage="\
Usage:
    $0 <package>

Cache directory:
    ~/Library/NXWine/caches/<package>

package             description
------------------------------------------------
rpg2000             RPG TKOOL 2000 RTP
rpg2003             RPG TKOOL 2003 RTP
rpgxp               RPG TKOOL XP RTP v103
rpgvx               RPG TKOOL VX RTP v202

?????               Aooni (Japanese version)
??                  Ib v1.05
?????????           Yumenikki v0.10 (with patch)"

# ------------------------------------- GUI event
function Dialog_ {
    set -- $(
        osascript -e '
            property rpg2000 : "RPG TKOOL 2000"
            property rpg2003 : "RPG TKOOL 2003"
            property rpgxp   : "RPG TKOOL XP"
            property rpgvx   : "RPG TKOOL VX"
            
            tell application "AppleScript Runner"
                activate
                set aRes to (choose from list {rpg2000, rpg2003, rpgxp, rpgvx} with title "NXWinetricks") as text
                if aRes is "false"  then quit
                if aRes is rpg2000  then return "rpg2000"
                if aRes is rpg2003  then return "rpg2003"
                if aRes is rpgxp    then return "rpgxp"
                if aRes is rpgvx    then return "rpgvx"
            end tell
        '
    )
    
    if [ "$1" ]; then
        exec "$0" "$1"
    else
        exit 0
    fi
}

# -------------------------------------
function ConvLess_ {
    iconv -f CP932 -t UTF-8 "$@" | less
}

# -------------------------------------
function install_rpg2000 {
    # f1ea2dd0610d005282f3840c349754cdece9f3ad
    set -- 2000rtp.zip
    [ -f $1 ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/2000rtp.zip'
    ${wine} 7z.exe e -y $1
    ${wine} RPG2000RTP.exe
    ConvLess_ "使用規約.txt"
}
function install_rpg2003 {
    # 9a63d4e58d752d6ed5de79492a31ce43d0060564
    set -- 2003rtp.zip
    [ -f $1 ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/2003rtp.zip'
    ${wine} 7z.exe e -y $1
    ${wine} RPG2003RTP.exe
    ConvLess_ "使用規約.txt"
}
function install_rpgxp {
    # 2079f38b692569c1fc734320862badb170bbd29d
    set -- xp_rtp103.zip
    [ -f $1 ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/xp_rtp103.zip'
    ${wine} 7z.exe e -y $1
    ${wine} Setup.exe
    ConvLess_ "利用規約.txt"
}
function install_rpgvx {
    # 351b4e528dc6ed4ed9988f0a636da6b1df48d6f2
    set -- vx_rtp202.zip
    [ -f $1 ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/vx_rtp202.zip'
    ${wine} 7z.exe e -y $1
    ${wine} setup.exe
    ConvLess_ "利用規約.txt"
}

# -------------------------------------
function install_aooni {
    set -- aooni.zip
    [ -f $1 ] || curl -O 'http://mygames888.info/zip/aooni.zip'
    unzip -o $1
    ${wine} 7z.exe x -y -o'c:\Program Files\aooni' $(basename $1 .zip).exe
    less "$(${wine} winepath.exe --unix 'c:\Program Files\aooni\README.txt')"
}
function install_ib {
    set -- Ib_1.05.zip
    [ -f $1 ] || curl -O 'http://ftp.vector.co.jp/pack/win95/game/avg/horror/Ib_1.05.zip'
    ${wine} 7z.exe x -y -o'c:\Program Files' $1
    ConvLess_ "$(${wine} winepath.exe --unix 'c:\Program Files\Ib_1.05\Ib_説明書.txt')"
}
function install_yumenikki {
    set -- yumenikki0.10.lzh yumesyuusei.lzh
    [ -f $1 ] || curl -O 'http://ftp.vector.co.jp/pack/win95/game/avg/yumenikki0.10.lzh'
    [ -f $2 ] || curl -O 'http://www3.nns.ne.jp/pri/tk-mto/yumesyuusei.lzh'
    ${wine} 7z.exe x -y -o'c:\Program Files' $1
    ${wine} 7z.exe e -y -o'c:\Program Files\ゆめにっき\ゆめにっき0.10' $2
    ConvLess_   "$(${wine} winepath.exe --unix 'c:\Program Files\ゆめにっき\初めに読んで下さい。0.10.txt')" \
                "$(${wine} winepath.exe --unix 'c:\Program Files\ゆめにっき\ゆめにっき0.10\ゆめにっき修正ファイルについて.txt')"
}

# ------------------------------------- begin processing
case $1 in
    aooni|ib|yumenikki|rpg200[03]|rpgxp|rpgvx)
    ;;
    "")
        Dialog_
    ;;
    *)
        exec echo "${usage}"
    ;;
esac

wine=/Applications/NXWine.app/Contents/Resources/bin/wine
sevenzip=/Applications/NXWine.app/Contents/Resources/share/nxwine/programs/7-Zip/7z.exe
cachedir=$(osascript -e 'POSIX path of (path to library folder from user domain) & "NXWine/caches/"')$1

printf "package ... $1\n"
printf "checking wine ... "; [ -x "${wine}" ] && printf "${wine}\n" || { echo no; exit 1; }
printf "checking 7z.exe ... "; [ -f "${sevenzip}" ] && printf "${sevenzip}\n" || { echo no; exit 1; }

PS4=
set -x
mkdir -p ${cachedir}
cd ${cachedir}
install_$1
