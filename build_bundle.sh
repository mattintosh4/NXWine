#!/bin/bash -x

srcroot="$(cd "$(dirname "$0")"; pwd)"

test ! -e NXWine.app || rm -rf NXWine.app

hdiutil attach ${srcroot}/NXWine.dmg -mountpoint ${mountpoint=/tmp/local} || exit

osacompile -o NXWine.app <<__APPLESCRIPT__ || exit
--
-- NXWine.app - No X11 Wine
-- Created by mattintosh4 on $(date +%F).
-- Copyright (c) 2013 mattintosh4, mattintosh4@gmx.com
-- https://github.com/mattintosh4/NXWine
--

on main(input)
    try
        do shell script quoted form of (POSIX path of (path to resource "wine" in directory "bin/")) & space & input
    end try
end main

on open argv
    repeat with aFile in argv
        main("start /Unix" & space & quoted form of (POSIX path of aFile))
    end repeat
end open

on run
    main("explorer")
end run
__APPLESCRIPT__

rm NXWine.app/Contents/Resources/droplet.icns
cp -R ${mountpoint}/* NXWine.app/Contents/Resources &&
hdiutil detach ${mountpoint}

wine_version=$(NXWine.app/Contents/Resources/bin/wine --version)

while read
do
    /usr/libexec/PlistBuddy -c "${REPLY}" NXWine.app/Contents/Info.plist
done <<__CMD__
Add :NSHumanReadableCopyright string ${wine_version}, Copyright © 2013 mattintosh4, https://github.com/mattintosh4/NXWine
Add :CFBundleVersion string $(date +%F)
Add :CFBundleIdentifier string com.github.mattintosh4.NXWine
Add :CFBundleDocumentTypes:1:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:1:CFBundleTypeExtensions:0 string exe
Add :CFBundleDocumentTypes:1:CFBundleTypeName string Windows Executable File
Add :CFBundleDocumentTypes:1:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:2:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:2:CFBundleTypeExtensions:0 string msi
Add :CFBundleDocumentTypes:2:CFBundleTypeName string Microsoft Windows Installer
Add :CFBundleDocumentTypes:2:CFBundleTypeRole string Viewer
Add :CFBundleDocumentTypes:3:CFBundleTypeExtensions array
Add :CFBundleDocumentTypes:3:CFBundleTypeExtensions:0 string lnk
Add :CFBundleDocumentTypes:3:CFBundleTypeName string Windows Shortcut File
Add :CFBundleDocumentTypes:3:CFBundleTypeRole string Viewer
__CMD__

test ! -f ${dmg=NXWineApp_$(date +%F)_${wine_version#*-}.dmg} || rm ${dmg}
hdiutil create -srcdir NXWine.app ${dmg}

:
afplay /System/Library/Sounds/Hero.aiff
