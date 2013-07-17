--
-- NXWine - No X11 Wine for Mac OS X
--
-- Created by mattintosh4 on @DATE@.
-- Copyright (C) 2013 mattintosh4, https://github.com/mattintosh4/NXWine
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

property WINELOADER : "/Applications/NXWine.app/Contents/Resources/bin/wine"



script StartMenu_
  property control      : "コントロールパネル"
  property explorer     : "Wine エクスプローラ"
  property openfinder   : "ファイルを開く"
  property regedit      : "レジストリエディタ"
  property uninstaller  : "プログラムの追加と削除"
  property winecfg      : "環境設定"
  property winefile     : "Wine ファイルマネージャ"
  property wineprefix   : "WINEPREFIX を開く"
  property killwine     : "Wine に終了シグナルを送る"

  set menuList to { ¬
    openfinder, ¬
    explorer, ¬
    winefile, ¬
    winecfg, ¬
    regedit, ¬
    control, ¬
    uninstaller, ¬
    wineprefix, ¬
    killwine}

  set aRes to (choose from list menuList default items openfinder with title "NXWine Menu") as string

  if aRes is "false" then
    return
  else if aRes is control then
    main("control")
  else if aRes is explorer then
    main("explorer")
  else if aRes is openfinder then
    main({"start", "/Unix", quoted form of POSIX path of (choose file)})
  else if aRes is regedit then
    main("regedit")
  else if aRes is uninstaller then
    main("uninstaller")
  else if aRes is winefile then
    main("winefile")
  else if aRes is winecfg then
    main("winecfg")
  else if aRes is wineprefix then
    tell application "Finder" to activate (open POSIX file (do shell script WINELOADER & space & "winepath.exe c:") as alias)
  else if aRes is killwine then
    display alert "Wine に終了シグナルを送信します" message "OK ボタンを押すと全ての Wine アプリケーションを終了します。" buttons {"キャンセル", "OK"} as warning
    if button returned of result is "OK" then
      try
        do shell script "killall wine"
      end try
    end if
    reopen
  end if -- end of parent if
end script



on main(args)
  set args to {"WINEDEBUG=-all", WINELOADER, args, "&>/dev/null 2>&1 &"}
  set beginning of text item delimiters of AppleScript to space
  set cmd to args as string
  set text item delimiters of AppleScript to rest of text item delimiters of AppleScript
  try
    do shell script cmd
  end try
end main

on run
  main("explorer")
end run

on open argv
  repeat with aFile in argv
    main({"start", "/Unix", quoted form of POSIX path of aFile})
  end repeat
end open

on reopen
  run StartMenu_
end reopen

on quit
  try
    do shell script "kill $(ps ax | awk '/\\/Applications\\/NXWine.app\\/Contents\\/Resources\\/libexec\\/wine/ { print $1 }')"
  end try
  continue quit
end quit
