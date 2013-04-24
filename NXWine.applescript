--
-- NXWine.app - No X11 Wine
-- Created by mattintosh4 on @DATE@.
-- Copyright (c) 2013 mattintosh4, mattintosh4@gmx.com
-- https://github.com/mattintosh4/NXWine
--

property wine : missing value
property wineserver : missing value

on NXWineGetPath_(prefix)
    set wine to prefix & "bin/wine" & space
    set wineserver to prefix & "bin/wineserver -p0;"
end NXWineGetPath_

on main(input)
    NXWineGetPath_(quoted form of (POSIX path of (path to me) & "Contents/Resources/"))
    try
        do shell script wineserver & wine & input
    end try
end main

on open argv
    repeat with aFile in argv
        main("start /Unix" & space & quoted form of (POSIX path of aFile))
    end repeat
end open

on run
    activate
    set explorer to "Wine エクスプローラ"
    set winefile to "Wine ファイルマネージャ"
    set winecfg to "Wine 設定"
    set regedit to "レジストリエディタ"
    set control to "コントロールパネル"
    set uninstaller to "プログラムの追加と削除"
    set aRes to (choose from list {explorer, winefile, winecfg, regedit, control, uninstaller} with title "NXWine @DATE@" with prompt "@WINE_VERSION@") as text
    if aRes = "false" then
        error number -128
    else if aRes = explorer then
        main("explorer")
    else if aRes = winefile then
        main("winefile")
    else if aRes = winecfg then
        main("winecfg")
    else if aRes = regedit then
        main("regedit")
    else if aRes = control then
        main("control")
    else if aRes = uninstaller then
        main("uninstaller")
    end if
    run
end run
