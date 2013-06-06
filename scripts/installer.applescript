set theSource to alias (POSIX file (POSIX path of (path to me) & "../.resources/NXWine.app"))

tell application "Finder"
    display alert   "アプリケーションフォルダに NXWine.app をインストールします" ¬
            message "＊＊＊ 使用許諾 ＊＊＊\n\n本アプリケーションに関するいかなる損害において当方は一切責任を負いません。自己責任でご利用下さい。\"OK\" ボタンを押すと使用許諾に同意したものとみなされます。" ¬
            buttons {"キャンセル", "OK"} cancel button "キャンセル" as warning
    
    if exists POSIX file "/Applications/NXWine.app" then
        display alert   "アプリケーションフォルダにインストール済みの NXWine.app が存在します" ¬
                message "以前の NXWine.app は破棄され新しいものに置き換えられます。処理を続行する場合は \"OK\" ボタンを押して下さい。" ¬
                buttons {"キャンセル", "OK"} cancel button "キャンセル" as warning
    end if
    
    with timeout of 600 seconds
        duplicate theSource to (path to applications folder) with replacing
    end timeout
end tell