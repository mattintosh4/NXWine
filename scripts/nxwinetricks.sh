#!/bin/sh -e
#
# NXWinetricks - Plugin installation support script
#
# Created by mattintosh4 on @DATE@.
# Copyright (C) 2013 mattintosh4, https://github.com/mattintosh4/NXWine
#
LANG=${LANG:=ja_JP.UTF-8}

usage="\
Usage:
    $(cd "$(dirname "$0")" && pwd)/nxwinetricks [package]
    
Cache directory:
    /Users/$(whoami)/com.github.mattintosh4.NXWine/<package>

package             description
------------------------------------------------
rpg2000             RPG TKOOL 2000 RTP
rpg2003             RPG TKOOL 2003 RTP
rpgxp               RPG TKOOL XP RTP v103
rpgvx               RPG TKOOL VX RTP v202

?????               Aooni (Japanese version)
??                  Ib v1.05
?????????           Yumenikki v0.10 (with patch)"

case $1 in
    aooni|ib|yumenikki|rpg200[03]|rpgxp|rpgvx)
        # nothing to do
    ;;
    *)
        exec echo "${usage}"
    ;;
esac

cachedir=/Users/$(whoami)/Library/Caches/com.github.mattintosh4.NXWine/$1
printf "package... $1\n"

wine=/Applications/NXWine.app/Contents/Resources/bin/wine
printf "checking wine... "
[ -x "${wine}" ] && printf "${wine}\n" || { echo no; exit 1; }

sevenzip=/Applications/NXWine.app/Contents/Resources/share/nxwine/programs/7-Zip/7z.exe
printf "checking 7z.exe... "
[ -f "${sevenzip}" ] && printf "${sevenzip}\n" || { echo no; exit 1; }

# ------------------------------------- processing variables
FlatExtract="${wine} 7z.exe e -y"
PathExtract="${wine} 7z.exe x -y"
notepad="${wine} notepad"
winepath="${wine} winepath --unix"
function ConvLess_ {
    iconv -f CP932 -t UTF-8 "$@" | less -e
}

# ------------------------------------- plugins
function install_rpg2000 {
    # f1ea2dd0610d005282f3840c349754cdece9f3ad
    f=2000rtp.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/2000rtp.zip'
    ${FlatExtract} $f
    ${wine} RPG2000RTP.exe
    ConvLess_ "使用規約.txt"
}
function install_rpg2003 {
    # 9a63d4e58d752d6ed5de79492a31ce43d0060564
    f=2003rtp.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/2003rtp.zip'
    ${FlatExtract} $f
    ${wine} RPG2003RTP.exe
    ConvLess_ "使用規約.txt"
}
function install_rpgxp {
    # 2079f38b692569c1fc734320862badb170bbd29d
    f=xp_rtp103.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/xp_rtp103.zip'
    ${FlatExtract} $f
    ${wine} Setup.exe
    ConvLess_ "利用規約.txt"
}
function install_rpgvx {
    # 351b4e528dc6ed4ed9988f0a636da6b1df48d6f2
    f=vx_rtp202.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/winnt/util/runtime/vx_rtp202.zip'
    ${FlatExtract} $f
    ${wine} setup.exe
    ConvLess_ "利用規約.txt"
}

# ------------------------------------- applications
function install_aooni {
    f=aooni.zip
    [ -f $f ] || curl -O 'http://mygames888.info/zip/aooni.zip'
    unzip -o $f
    ${PathExtract} -o'c:\Program Files\aooni' $(basename $f .zip).exe
    less -e "$(${winepath} 'c:\Program Files\aooni\README.txt')"
}
function install_ib {
    f=Ib_1.05.zip
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/win95/game/avg/horror/Ib_1.05.zip'
    ${PathExtract} -o'c:\Program Files' $f
    ConvLess_ "$(${winepath} 'c:\Program Files\Ib_1.05\Ib_説明書.txt')"
}
function install_yumenikki {
    f=yumenikki0.10.lzh
    p=yumesyuusei.lzh
    [ -f $f ] || curl -O 'http://ftp.vector.co.jp/pack/win95/game/avg/yumenikki0.10.lzh'
    [ -f $p ] || curl -O 'http://www3.nns.ne.jp/pri/tk-mto/yumesyuusei.lzh'
    ${PathExtract} -o'c:\Program Files' $f
    ${FlatExtract} -o'c:\Program Files\ゆめにっき\ゆめにっき0.10' $p
    ConvLess_   "$(${winepath} 'c:\Program Files\ゆめにっき\初めに読んで下さい。0.10.txt')" \
                "$(${winepath} 'c:\Program Files\ゆめにっき\ゆめにっき0.10\ゆめにっき修正ファイルについて.txt')"
}

# ------------------------------------- begin processing
# note: suppress wine debug messages.
export WINEDEBUG=
PS4=
set -x
install -d ${cachedir}
cd ${cachedir}
install_$1
