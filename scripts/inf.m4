



;;; ----------- NXWine original section ----------- ;;;

; この行以降は NXWine 独自の初期値です。これらの初期化が不要であれば削除して下さい。
; この INF ファイルは BOM 付きの UTF-8 に変換されていますので編集の際はご注意下さい。


;;; Japanese font settings ;;;
dnl
define(`_KEY_systemlink',       `HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink')dnl
define(`_KEY_fontsubstitutes',  `HKLM,Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes')dnl
define(`_KEY_replacements',     `HKCU,Software\Wine\Fonts\Replacements')dnl
define(`G_FILE',  `KonatuTohaba.ttf')dnl
define(`G_NAME',  `小夏 等幅')dnl
define(`PG_FILE', `Konatu.ttf')dnl
define(`PG_NAME', `小夏')dnl
define(`M_FILE',  `sazanami-mincho.ttf')dnl
define(`M_NAME',  `さざなみ明朝')dnl
define(`PM_FILE', `sazanami-mincho.ttf')dnl
define(`PM_NAME', `さざなみ明朝')dnl

[Fonts]
_KEY_systemlink,"Lucida Sans Unicode",,"PG_FILE"
_KEY_systemlink,"Microsoft Sans Serif",,"PG_FILE"
_KEY_systemlink,"MS Sans Serif",,"PG_FILE"
_KEY_systemlink,"MS Gothic",,"G_FILE"
_KEY_systemlink,"MS PGothic",,"PG_FILE"
_KEY_systemlink,"MS Serif",,"PM_FILE"
_KEY_systemlink,"MS Mincho",,"M_FILE"
_KEY_systemlink,"MS PMincho",,"PM_FILE"
_KEY_systemlink,"Tahoma",,"PG_FILE"
_KEY_systemlink,"Verdana",,"PG_FILE"

_KEY_fontsubstitutes,"@MS Shell Dlg",,"@MS UI Gothic"
_KEY_fontsubstitutes,"@標準ゴシック",,"@ＭＳ ゴシック"
_KEY_fontsubstitutes,"@標準明朝",,"@ＭＳ 明朝"
_KEY_fontsubstitutes,"ｺﾞｼｯｸ",,"ＭＳ ゴシック"
_KEY_fontsubstitutes,"ゴシック",,"ＭＳ ゴシック"
_KEY_fontsubstitutes,"標準ゴシック",,"ＭＳ ゴシック"
_KEY_fontsubstitutes,"標準明朝",,"ＭＳ 明朝"

_KEY_replacements,"@MS UI Gothic",,"@PG_NAME"
_KEY_replacements,"@ＭＳ ゴシック",,"@PG_NAME"
_KEY_replacements,"@ＭＳ 明朝",,"@ヒラギノ明朝 Pro W3"
_KEY_replacements,"MS UI Gothic",,"PG_NAME"
_KEY_replacements,"ＭＳ ゴシック",,"G_NAME"
_KEY_replacements,"ＭＳ Ｐゴシック",,"PG_NAME"
_KEY_replacements,"ＭＳ 明朝",,"M_NAME"
_KEY_replacements,"ＭＳ Ｐ明朝",,"PM_NAME"


;;; Control Panel ;;;

HKCU,Control Panel\Desktop,"FontSmoothing",,"0"
HKCU,Control Panel\Mouse,"DoubleClickHeight",,"8"
HKCU,Control Panel\Mouse,"DoubleClickWidth",,"8"


;;; Favorites ;;;
dnl
define(`_KEY_favorites',`HKCU,Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites')dnl

_KEY_favorites,"フォント (FontSubstitutes)",,"HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes"
_KEY_favorites,"フォント (SystemLink)",,"HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink"
_KEY_favorites,"フォント (Replacements)",,"HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements"
_KEY_favorites,"デスクトップ",,"HKEY_CURRENT_USER\Control Panel\Desktop"
_KEY_favorites,"マウス",,"HKEY_CURRENT_USER\Control Panel\Mouse"
_KEY_favorites,"ライブラリオーバーライド",,"HKEY_CURRENT_USER\Software\Wine\DllOverrides"


;;; 7-Zip classes ;;;
dnl
define(`_7z_class_regist', `dnl
HKCR,.$1,,2,"7-Zip.$1"
HKCR,7-Zip.$1,,2,"$1 Archive"
HKCR,7-Zip.$1\shell\open\command,,2,"""Z:\Applications\NXWine.app\Contents\Resources\lib\wine\programs\7-Zip\7zFM.exe"" ""%1"""
HKCR,7-Zip.$1\DefaultIcon,,2,"Z:\Applications\NXWine.app\Contents\Resources\lib\wine\programs\7-Zip\7z.dll,$2"')dnl

[Classes]
_7z_class_regist(7z, 0)
_7z_class_regist(cab, 7)
_7z_class_regist(lha, 6)
_7z_class_regist(lzh, 6)
_7z_class_regist(lzma, 16)
_7z_class_regist(rar, 3)
_7z_class_regist(xz, 23)
_7z_class_regist(zip, 1)
