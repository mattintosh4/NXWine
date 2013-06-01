#!/bin/sh -e
#
# NXWine extra package installer
#
# Created by mattintosh4 on @DATE@.
# Copyright (C) 2013 mattintosh4, https://github.com/mattintosh4/NXWine
#
LANG=${LANG:=ja_JP.UTF-8}

usage="Usage: $(cd "$(dirname "$0")" && pwd)/nxwinetricks [package]

package                 description
------------------------------------------------
rpg2000                 RPG TKOOL 2000 RTP
rpg2003                 RPG TKOOL 2003 RTP
rpgxp                   RPG TKOOL XP RTP v103
rpgvx                   RPG TKOOL VX RTP v202"

case $1 in
    rpg2000|rpg2003|rpgxp|rpgvx)
        name=$1
        cachefile=/tmp/$(uuidgen)
        touch ${cachefile}
        trap "rm ${cachefile}" EXIT
    ;;
    -h|--help|*)
        echo "${usage}"
        exit
    ;;
esac
printf "package... ${name}\n"

wine=/Applications/NXWine.app/Contents/Resources/bin/wine
printf "checking wine... "
[ -x "${wine}" ] && printf "${wine}\n" || { echo no; false; }

sevenzip=/Applications/NXWine.app/Contents/Resources/lib/wine/programs/7-Zip/7z.exe
printf "checking 7z.exe... "
[ -f "${sevenzip}" ] && printf "${sevenzip}\n" || { echo no; false; }

extract="${wine} ${sevenzip} e -y"

# ------------------------------------- begin functions
function install_rpg2000 {
    # f1ea2dd0610d005282f3840c349754cdece9f3ad
    curl -o $1 'http://ftp.vector.co.jp/pack/winnt/util/runtime/2000rtp.zip'
    ${extract} -o'c:\tkool\2000' $1
    ${wine} 'c:\tkool\2000\RPG2000RTP.exe'
    ${wine} 'c:\tkool\2000\使用規約.txt'
}
function install_rpg2003 {
    # 9a63d4e58d752d6ed5de79492a31ce43d0060564
    curl -o $1 'http://ftp.vector.co.jp/pack/winnt/util/runtime/2003rtp.zip'
    ${extract} -o'c:\tkool\2003' $1
    ${wine} 'c:\tkool\2003\RPG2003RTP.exe'
    ${wine} 'c:\tkool\2003\使用規約.txt'
}
function install_rpgxp {
    # 2079f38b692569c1fc734320862badb170bbd29d
    curl -o $1 'http://ftp.vector.co.jp/pack/winnt/util/runtime/xp_rtp103.zip'
    ${extract} -o'c:\tkool\XP103' $1
    ${wine} 'c:\tkool\XP103\Setup.exe'
    ${wine} 'c:\tkool\XP103\利用規約.txt'
}
function install_rpgvx {
    # 351b4e528dc6ed4ed9988f0a636da6b1df48d6f2
    curl -o $1 'http://ftp.vector.co.jp/pack/winnt/util/runtime/vx_rtp202.zip'
    ${extract} -o'c:\tkool\VX202' $1
    ${wine} 'c:\tkool\VX202\Setup.exe'
}

# ------------------------------------- begin processing
PS4=
set -x
install_${name} ${cachefile}
