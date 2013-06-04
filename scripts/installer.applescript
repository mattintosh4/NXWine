set mySource to alias (POSIX file (POSIX path of (path to me) & "../.resources/NXWine.app"))
set myTitle to "アプリケーションフォルダに NXWine.app をインストールします"
set myMessage to "※使用許諾

本アプリケーションに関するいかなる損害において当方は一切責任を負いません。ご使用は自己責任でお願いします。\"OK\" ボタンを押すと使用許諾に同意したものとみなされます。

※注意

以前の NXWine.app は新しいものに置き換えられます。バックアップを行う場合は \"キャンセル\" ボタンを押して処理を中止して下さい。"

tell application "Finder"
    display alert myTitle message myMessage buttons {"キャンセル", "OK"} cancel button "キャンセル" as warning
    duplicate mySource to (path to applications folder) with replacing
end tell