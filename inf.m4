;;; ----------- NXWine original section ----------- ;;;

; この行以降は NXWine 独自の初期値です。これらの初期化が不要であれば削除して下さい。
; この INF ファイルは BOM 付きの UTF-8 に変換されていますので編集の際はご注意下さい。

define(`G_FILE',  `KonatuTohaba.ttf')dnl
define(`G_NAME',  `Konatu Tohaba')dnl
define(`PG_FILE', `Konatu.ttf')dnl
define(`PG_NAME', `Konatu')dnl
define(`M_FILE',  `ipam-mona.ttf')dnl
define(`M_NAME',  `IPAMonaMincho')dnl
define(`PM_FILE', `ipamp-mona.ttf')dnl
define(`PM_NAME', `IPAMonaPMincho')dnl

;;; Japanese font settings ;;;

[Fonts]
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Microsoft Sans Serif",,"G_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Sans Serif",,"G_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Gothic",,"G_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS PGothic",,"PG_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Serif",,"M_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS Mincho",,"M_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"MS PMincho",,"PM_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Tahoma",,"PG_FILE"
HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink,"Verdana",,"PG_FILE"

HKCU,Software\Wine\Fonts\Replacements,"MS UI Gothic",,"PG_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ ゴシック",,"G_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐゴシック",,"PG_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ 明朝",,"M_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐ明朝",,"PM_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ｺﾞｼｯｸ",,"G_NAME"
HKCU,Software\Wine\Fonts\Replacements,"ゴシック",,"G_NAME"
HKCU,Software\Wine\Fonts\Replacements,"標準ゴシック",,"G_NAME"
HKCU,Software\Wine\Fonts\Replacements,"明朝",,"M_NAME"
HKCU,Software\Wine\Fonts\Replacements,"標準明朝",,"M_NAME"


;;; Mouse ;;;

HKCU,Control Panel\Mouse,"DoubleClickHeight",,"8"
HKCU,Control Panel\Mouse,"DoubleClickWidth",,"8"

define(`_7z_class_regist', `dnl
HKCR,.$1,,2,"7-Zip.$1"
HKCR,7-Zip.$1,,2,"$1 Archive"
HKCR,7-Zip.$1\shell\open\command,,2,"""Z:\Applications\NXWine.app\Contents\Resources\lib\wine\programs\7-Zip\7zFM.exe"" ""%1"""
HKCR,7-Zip.$1\DefaultIcon,,2,"Z:\Applications\NXWine.app\Contents\Resources\lib\wine\programs\7-Zip\7z.dll,$2"')dnl

;;; 7-Zip classes ;;;

[Classes]
_7z_class_regist(7z, 0)
_7z_class_regist(lha, 6)
_7z_class_regist(lzh, 6)
_7z_class_regist(rar, 3)
_7z_class_regist(xz, 23)
_7z_class_regist(zip, 1)