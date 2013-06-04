set theSource to alias (POSIX file (POSIX path of (path to me) & "../.resources/NXWine.app"))
set theTitle to "アプリケーションフォルダに NXWine.app をインストールします"
set theMessage to "※使用許諾

本アプリケーションに関するいかなる損害において当方は一切責任を負いません。ご使用は自己責任でお願いします。\"OK\" ボタンを押すと使用許諾に同意したものとみなされます。

※注意

以前の NXWine.app は新しいものに置き換えられます。バックアップを行う場合は \"キャンセル\" を押して処理を中止して下さい。"

tell application "Finder"
    display alert theTitle message theMessage buttons {"キャンセル", "OK"} cancel button "キャンセル" as warning
    duplicate theSource to (path to applications folder) with replacing
end tell