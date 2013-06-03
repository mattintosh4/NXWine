define(`_PROG_PREFIX', `Z:\Applications\NXWine.app\Contents\Resources\lib\wine\programs')dnl



;;; ----------- NXWine original section ----------- ;;;

; この行以降は NXWine 独自の初期値です。これらの初期化が不要であれば削除して下さい。
; この INF ファイルは BOM 付きの UTF-8 に変換されていますので編集の際はご注意下さい。

[DefaultInstall.NT]
AddReg=\
  Classes,\
  Control Panel,\
  Environment,\
  Favorites,\
  Fonts

[Strings]
Favorites="Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites"
FontReplace="Software\Wine\Fonts\Replacements"
FontSubStr="Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes"
FontSysLink="Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink"

[Environment]
HKCU,Environment,"PATH",,"_PROG_PREFIX\7-Zip"

[Fonts]
dnl
define(`MG_FILE', `KonatuTohaba.ttf')dnl
define(`MG_NAME', `小夏 等幅')dnl
define(`PG_FILE', `Konatu.ttf')dnl
define(`PG_NAME', `小夏')dnl
define(`MM_FILE', `sazanami-mincho.ttf')dnl
define(`MM_NAME', `さざなみ明朝')dnl
define(`PM_FILE', `sazanami-mincho.ttf')dnl
define(`PM_NAME', `さざなみ明朝')dnl
dnl
HKCU,%FontReplace%,"@MS UI Gothic",,"@PG_NAME"
HKCU,%FontReplace%,"@ＭＳ ゴシック",,"@PG_NAME"
HKCU,%FontReplace%,"@ＭＳ Ｐゴシック",,"@PG_NAME"
HKCU,%FontReplace%,"@ＭＳ 明朝",,"@ヒラギノ明朝 Pro W3"
HKCU,%FontReplace%,"@ＭＳ Ｐ明朝",,"@ヒラギノ明朝 Pro W3"
HKCU,%FontReplace%,"MS UI Gothic",,"PG_NAME"
HKCU,%FontReplace%,"ＭＳ ゴシック",,"MG_NAME"
HKCU,%FontReplace%,"MS Gothic",,"MG_NAME"
HKCU,%FontReplace%,"ＭＳ Ｐゴシック",,"PG_NAME"
HKCU,%FontReplace%,"MS PGothic",,"PG_NAME"
HKCU,%FontReplace%,"ＭＳ 明朝",,"MM_NAME"
HKCU,%FontReplace%,"MS Mincho",,"MM_NAME"
HKCU,%FontReplace%,"ＭＳ Ｐ明朝",,"PM_NAME"
HKCU,%FontReplace%,"MS PMincho",,"PM_NAME"

HKLM,%FontSubStr%,"@MS Shell Dlg",,"@MS UI Gothic"
HKLM,%FontSubStr%,"@標準ゴシック",,"@ＭＳ ゴシック"
HKLM,%FontSubStr%,"@標準明朝",,"@ＭＳ 明朝"
HKLM,%FontSubStr%,"Helvetica",,"Helvetica"
HKLM,%FontSubStr%,"Lucida Console",,"Lucida Grande"
HKLM,%FontSubStr%,"Lucida Sans Unicode",,"Lucida Grande"
HKLM,%FontSubStr%,"MS Sans Serif",,"ＭＳ ゴシック"
HKLM,%FontSubStr%,"MS Serif",,"ＭＳ 明朝"
HKLM,%FontSubStr%,"ｺﾞｼｯｸ",,"ＭＳ ゴシック"
HKLM,%FontSubStr%,"ゴシック",,"ＭＳ ゴシック"
HKLM,%FontSubStr%,"標準ゴシック",,"ＭＳ ゴシック"
HKLM,%FontSubStr%,"標準明朝",,"ＭＳ 明朝"

HKLM,%FontSysLink%,"Helvetica",,"PG_FILE"
HKLM,%FontSysLink%,"Lucida Grande",,"PG_FILE"
HKLM,%FontSysLink%,"Microsoft Sans Serif",,"PG_FILE"
HKLM,%FontSysLink%,"Tahoma",,"PG_FILE"
HKLM,%FontSysLink%,"Verdana",,"PG_FILE"

[Control Panel]
HKCU,Control Panel\Desktop,"FontSmoothing",,"0"
HKCU,Control Panel\Mouse,"DoubleClickHeight",,"8"
HKCU,Control Panel\Mouse,"DoubleClickWidth",,"8"

[Favorites]
HKCU,%Favorites%,"デスクトップ",,"HKEY_CURRENT_USER\Control Panel\Desktop"
HKCU,%Favorites%,"フォント (FontSubstitutes)",,"HKEY_LOCAL_MACHINE\%FontSubStr%"
HKCU,%Favorites%,"フォント (Replacements)",,"HKEY_CURRENT_USER\%FontReplace%"
HKCU,%Favorites%,"フォント (SystemLink)",,"HKEY_LOCAL_MACHINE\%FontSysLink%"
HKCU,%Favorites%,"マウス",,"HKEY_CURRENT_USER\Control Panel\Mouse"
HKCU,%Favorites%,"ユーザー環境変数",,"HKEY_CURRENT_USER\Environment"
HKCU,%Favorites%,"ライブラリオーバーライド",,"HKEY_CURRENT_USER\Software\Wine\DllOverrides"

[Classes]
dnl
define(`_7z_class_regist', `dnl
HKCR,.$1,,2,"7-Zip.$1"
HKCR,7-Zip.$1,,2,"$1 Archive"
HKCR,7-Zip.$1\shell\open\command,,2,"""_PROG_PREFIX\7-Zip\7zFM.exe"" ""%1"""
HKCR,7-Zip.$1\DefaultIcon,,2,"_PROG_PREFIX\7-Zip\7z.dll,$2"')dnl
dnl
_7z_class_regist(7z,    0)
_7z_class_regist(cab,   7)
_7z_class_regist(lha,   6)
_7z_class_regist(lzh,   6)
_7z_class_regist(lzma, 16)
_7z_class_regist(rar,   3)
_7z_class_regist(xz,   23)
_7z_class_regist(zip,   1)
