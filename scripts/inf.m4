


;;; ----------- NXWine original section ----------- ;;;

; この行以降は NXWine 独自の初期値です。これらの初期化が不要であれば削除して下さい。
; この INF ファイルは BOM 付きの UTF-8 に変換されていますので編集の際はご注意下さい。

[DefaultInstall.NT]
AddReg=\
  Classes,\
  Control Panel,\
  Drivers,\
  Environment,\
  Favorites,\
  Fonts,\
  Time Zones,\
  TimeZoneInformation


[Strings]
GothicMonoFile  = ヒラギノ角ゴ Pro W3.otf
GothicMonoName  = ヒラギノ角ゴ Pro W3
GothicPropFile  = ヒラギノ角ゴ Pro W3.otf
GothicPropName  = ヒラギノ角ゴ Pro W3
GothicUIFile    = ヒラギノ角ゴ Pro W3.otf
GothicUIName    = ヒラギノ角ゴ Pro W3
MinchoMonoFile  = sazanami-mincho.ttf
MinchoMonoName  = さざなみ明朝
MinchoPropFile  = sazanami-mincho.ttf
MinchoPropName  = さざなみ明朝

ExternalAppRoot = Z:\Applications\NXWine.app\Contents\Resources\share\nxwine\programs


[Control Panel]
;HKCU,Control Panel\Desktop ,"FontSmoothing"     ,,"0"
HKCU,Control Panel\Mouse    ,"DoubleClickHeight",,"8"
HKCU,Control Panel\Mouse    ,"DoubleClickWidth" ,,"8"


[Drivers]
HKCU,Software\Wine\Drivers,"Graphics",,"mac"


[Environment]
HKCU,Environment,"PATH",0x00020000,"%ExternalAppRoot%\7-Zip"


[Fonts]
HKCU,Software\Wine\Fonts\Replacements,"Lucida Sans Unicode" ,,"Lucida Grande"
HKCU,Software\Wine\Fonts\Replacements,"MS Gothic"           ,,"%GothicMonoName%"
HKCU,Software\Wine\Fonts\Replacements,"MS Mincho"           ,,"%MinchoMonoName%"
HKCU,Software\Wine\Fonts\Replacements,"MS PGothic"          ,,"%GothicPropName%"
HKCU,Software\Wine\Fonts\Replacements,"MS PMincho"          ,,"%MinchoPropName%"
HKCU,Software\Wine\Fonts\Replacements,"MS UI Gothic"        ,,"%GothicUIName%"
HKCU,Software\Wine\Fonts\Replacements,"Meiryo UI"           ,,"%GothicUIName%"
HKCU,Software\Wine\Fonts\Replacements,"Meiryo"              ,,"%GothicPropName%"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ 明朝"           ,,"%MinchoMonoName%"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐ明朝"         ,,"%MinchoPropName%"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ ゴシック"       ,,"%GothicMonoName%"
HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐゴシック"     ,,"%GothicPropName%"
HKCU,Software\Wine\Fonts\Replacements,"メイリオ"            ,,"%GothicPropName%"

HKLM,%CurrentVersionNT%\FontSubstitutes,"@MS Shell Dlg",,"@MS UI Gothic"
HKLM,%CurrentVersionNT%\FontSubstitutes,"@標準ゴシック",,"@ＭＳ ゴシック"
HKLM,%CurrentVersionNT%\FontSubstitutes,"@標準明朝"    ,,"@ＭＳ 明朝"
HKLM,%CurrentVersionNT%\FontSubstitutes,"ｺﾞｼｯｸ"        ,,"ＭＳ ゴシック"
HKLM,%CurrentVersionNT%\FontSubstitutes,"ゴシック"     ,,"ＭＳ ゴシック"
HKLM,%CurrentVersionNT%\FontSubstitutes,"標準ゴシック" ,,"ＭＳ ゴシック"
HKLM,%CurrentVersionNT%\FontSubstitutes,"標準明朝"     ,,"ＭＳ 明朝"

HKLM,%CurrentVersionNT%\FontLink            ,"FontLinkControl"      ,0x00010001,0x00000000
HKLM,%CurrentVersionNT%\FontLink            ,"FontLinkDefaultChar"  ,0x00010001,0x000030fb

HKLM,%CurrentVersionNT%\FontLink\SystemLink ,"Lucida Sans Unicode"  ,0x00010000,"MSGOTHIC.TTC,MS UI Gothic"
HKLM,%CurrentVersionNT%\FontLink\SystemLink ,"Microsoft Sans Serif" ,0x00010000,"MSGOTHIC.TTC,MS UI Gothic"
HKLM,%CurrentVersionNT%\FontLink\SystemLink ,"MS PGothic"           ,0x00010000,"LucidaGrande.ttc,Lucida Grande"
HKLM,%CurrentVersionNT%\FontLink\SystemLink ,"MS UI Gothic"         ,0x00010000,"LucidaGrande.ttc,Lucida Grande"
HKLM,%CurrentVersionNT%\FontLink\SystemLink ,"Tahoma"               ,0x00010000,"MSGOTHIC.TTC,MS UI Gothic"

HKLM,%CurrentVersionNT%\FontMapper,"ARIAL"          ,0x00010001,0x00000000
HKLM,%CurrentVersionNT%\FontMapper,"COURIER NEW"    ,0x00010001,0x00008000
HKLM,%CurrentVersionNT%\FontMapper,"COURIER"        ,0x00010001,0x00008800
HKLM,%CurrentVersionNT%\FontMapper,"DEFAULT"        ,0x00010001,0x00000080
HKLM,%CurrentVersionNT%\FontMapper,"FIXEDSYS"       ,0x00010001,0x00009000
HKLM,%CurrentVersionNT%\FontMapper,"MS SANS SERIF"  ,0x00010001,0x00001000
HKLM,%CurrentVersionNT%\FontMapper,"MS SERIF"       ,0x00010001,0x00005000
HKLM,%CurrentVersionNT%\FontMapper,"SMALL FONTS"    ,0x00010001,0x00000800
HKLM,%CurrentVersionNT%\FontMapper,"SYMBOL"         ,0x00010001,0x00004002
HKLM,%CurrentVersionNT%\FontMapper,"SYMBOL1"        ,0x00010001,0x0000a002
HKLM,%CurrentVersionNT%\FontMapper,"TIMES NEW ROMAN",0x00010001,0x00004000
HKLM,%CurrentVersionNT%\FontMapper,"WINGDINGS"      ,0x00010001,0x00000002
HKLM,%CurrentVersionNT%\FontMapper,"WINGDINGS2"     ,0x00010001,0x00008002
HKLM,%CurrentVersionNT%\FontMapper,"ＭＳ 明朝"      ,0x00010001,0x0000c080
HKLM,%CurrentVersionNT%\FontMapper,"ＭＳ Ｐ明朝"    ,0x00010001,0x00004080
HKLM,%CurrentVersionNT%\FontMapper,"ＭＳ ゴシック"  ,0x00010001,0x00008080
HKLM,%CurrentVersionNT%\FontMapper,"ＭＳ Ｐゴシック",0x00010001,0x00000080

[Favorites]
HKCU,%CurrentVersion%\Applets\Regedit\Favorites,"マウス"                    ,,"HKEY_CURRENT_USER\Control Panel\Mouse"
HKCU,%CurrentVersion%\Applets\Regedit\Favorites,"フォント (FontSubstitutes)",,"HKEY_LOCAL_MACHINE\%CurrentVersionNT%\FontSubstitutes"
HKCU,%CurrentVersion%\Applets\Regedit\Favorites,"フォント (Replacements)"   ,,"HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements"
HKCU,%CurrentVersion%\Applets\Regedit\Favorites,"フォント (SystemLink)"     ,,"HKEY_LOCAL_MACHINE\%CurrentVersionNT%\FontLink\SystemLink"
HKCU,%CurrentVersion%\Applets\Regedit\Favorites,"ドライバ"                  ,,"HKEY_CURRENT_USER\Software\Wine\Drivers"
HKCU,%CurrentVersion%\Applets\Regedit\Favorites,"デスクトップ"              ,,"HKEY_CURRENT_USER\Control Panel\Desktop"
HKCU,%CurrentVersion%\Applets\Regedit\Favorites,"ユーザー環境変数"          ,,"HKEY_CURRENT_USER\Environment"
HKCU,%CurrentVersion%\Applets\Regedit\Favorites,"ライブラリのオーバーライド",,"HKEY_CURRENT_USER\Software\Wine\DllOverrides"


[Classes]
dnl
define(`_7z_class_regist', `dnl
HKCR,.$1,,2,"7-Zip.$1"
HKCR,7-Zip.$1,,2,"$1 Archive"
HKCR,7-Zip.$1\shell\open\command,,2,"""%ExternalAppRoot%\7-Zip\7zFM.exe"" ""%1"""
HKCR,7-Zip.$1\DefaultIcon,,2,"%ExternalAppRoot%\7-Zip\7z.dll,$2"')dnl
dnl
_7z_class_regist(7z,    0)
_7z_class_regist(cab,   7)
_7z_class_regist(lha,   6)
_7z_class_regist(lzh,   6)
_7z_class_regist(lzma, 16)
_7z_class_regist(rar,   3)
_7z_class_regist(xz,   23)
_7z_class_regist(zip,   1)


[Time Zones]
HKCU,%CurrentVersionNT%\Time Zones                        ,"TimeZoneKeyName",           ,"Tokyo Standard Time"

HKLM,%CurrentVersionNT%\Time Zones\Tokyo Standard Time    ,"Display"        ,           ,"(GMT+09:00) 大阪、札幌、東京"
HKLM,%CurrentVersionNT%\Time Zones\Tokyo Standard Time    ,"Dlt"            ,           ,"東京 (夏時間)"
HKLM,%CurrentVersionNT%\Time Zones\Tokyo Standard Time    ,"Std"            ,           ,"東京 (標準時)"
HKLM,%CurrentVersionNT%\Time Zones\Tokyo Standard Time    ,"MapID"          ,           ,"18,19"
HKLM,%CurrentVersionNT%\Time Zones\Tokyo Standard Time    ,"Index"          ,0x00010001 ,0x000000eb
HKLM,%CurrentVersionNT%\Time Zones\Tokyo Standard Time    ,"TZI"            ,0x00000001 ,e4,fd,ff,ff,00,00,00,00,c4,ff,ff,ff,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00

[TimeZoneInformation]
HKLM,System\CurrentControlSet\Control\TimeZoneInformation ,"Bias"           ,0x00010001 ,0xfffffde4
HKLM,System\CurrentControlSet\Control\TimeZoneInformation ,"StandardName"   ,           ,"東京 (標準時)"
HKLM,System\CurrentControlSet\Control\TimeZoneInformation ,"StandardBias"   ,0x00010001 ,0x00000000
HKLM,System\CurrentControlSet\Control\TimeZoneInformation ,"StandardStart"  ,0x00000001 ,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
HKLM,System\CurrentControlSet\Control\TimeZoneInformation ,"DaylightName"   ,           ,"東京 (標準時)"
HKLM,System\CurrentControlSet\Control\TimeZoneInformation ,"DaylightBias"   ,0x00010001 ,0x00000000
HKLM,System\CurrentControlSet\Control\TimeZoneInformation ,"DaylightStart"  ,0x00000001 ,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
HKLM,System\CurrentControlSet\Control\TimeZoneInformation ,"ActiveTimeBias" ,0x00010001 ,0xfffffde4
