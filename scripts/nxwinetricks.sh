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
rpg2000                 RPG ツクール 2000 RTP
rpg2003                 RPG ツクール 2003 RTP
rpgxp                   RPG ツクール XP RTP v103
rpgvx                   RPG ツクール VX RTP v202

?????                   青鬼 (Japanese)
??                      Ib v1.05
?????????               ゆめにっき v0.10"

case $1 in
    aooni|ib|yumenikki|rpg2000|rpg2003|rpgxp|rpgvx)
        name=$1
        cachedir=$HOME/Library/Caches/com.github.mattintosh4.NXWine/$1
    ;;
    *)
        exec echo "${usage}"
    ;;
esac
printf "package... ${name}\n"

wine=/Applications/NXWine.app/Contents/Resources/bin/wine
printf "checking wine... "
[ -x "${wine}" ] && printf "${wine}\n" || { echo no; exit 1; }

sevenzip=/Applications/NXWine.app/Contents/Resources/lib/wine/programs/7-Zip/7z.exe
printf "checking 7z.exe... "
[ -f "${sevenzip}" ] && printf "${sevenzip}\n" || { echo no; exit 1; }

export WINEDEBUG=

flat_extract="${wine} ${sevenzip} e -y"
path_extract="${wine} ${sevenzip} x -y"
notepad="${wine} notepad"
winepath="${wine} winepath"

# ------------------------------------- tool functions
function docview_ {
    iconv -f CP932 -t UTF-8 "$@" | less -e
}
docview="docview_"

# ------------------------------------- plugins
function install_rpg2000 {
    # f1ea2dd0610d005282f3840c349754cdece9f3ad
    f=2000rtp.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/2000rtp.zip'
    ${flat_extract} $f
    ${wine} RPG2000RTP.exe
    ${docview} "使用規約.txt"
}
function install_rpg2003 {
    # 9a63d4e58d752d6ed5de79492a31ce43d0060564
    f=2003rtp.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/2003rtp.zip'
    ${flat_extract} $f
    ${wine} RPG2003RTP.exe
    ${docview} "使用規約.txt"
}
function install_rpgxp {
    # 2079f38b692569c1fc734320862badb170bbd29d
    f=xp_rtp103.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/xp_rtp103.zip'
    ${flat_extract} $f
    ${wine} Setup.exe
    ${docview} "利用規約.txt"
}
function install_rpgvx {
    # 351b4e528dc6ed4ed9988f0a636da6b1df48d6f2
    f=vx_rtp202.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/vx_rtp202.zip'
    ${flat_extract} $f
    ${wine} setup.exe
    ${docview} "利用規約.txt"
}

# ------------------------------------- applications
function install_aooni {
    f=aooni.zip
    [ -f $f ] || curl -O 'http://mygames888.info/zip/aooni.zip'
    unzip -o $f
    ${path_extract} -o'c:\Program Files\aooni' $(basename $f .zip).exe
    less -e "$(${wine}path 'c:\Program Files\aooni\README.txt')"
}
function install_ib {
    f=Ib_1.05.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/win95/game/avg/horror/Ib_1.05.zip'
    ${path_extract} -o'c:\Program Files' $f
    ${docview} "$(${wine} winepath 'c:\Program Files\Ib_1.05\Ib_説明書.txt')"
}
function install_yumenikki {
    f=yumenikki0.10.lzh
    p=yumesyuusei.lzh
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/win95/game/avg/yumenikki0.10.lzh'
    [ -f $p ] || curl -O 'http://www3.nns.ne.jp/pri/tk-mto/yumesyuusei.lzh'
    ${path_extract} -o'c:\Program Files' $f
    ${flat_extract} -o'c:\Program Files\ゆめにっき\ゆめにっき0.10' $p
    ${docview}  "$(${winepath} 'c:\Program Files\ゆめにっき\初めに読んで下さい。0.10.txt')" \
                "$(${winepath} 'c:\Program Files\ゆめにっき\ゆめにっき0.10\ゆめにっき修正ファイルについて.txt')"
}

# ------------------------------------- begin processing
PS4=
set -x
install -d ${cachedir}
cd ${cachedir}
install_${name}
