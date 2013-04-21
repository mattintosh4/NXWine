#!/bin/bash

srcroot="$(cd "$(dirname "$0")"; pwd)"

osacompile -o NXWine.app <<__APPLESCRIPT__ || exit
--
-- NXWine.app - No X11 Wine Launcher
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

hdiutil attach ${srcroot}/NXWine.dmg -mountpoint ${mountpoint=/tmp/local} &&
cp -R ${mountpoint}/* NXWine.app/Contents/Resources &&
hdiutil detach ${mountpoint}

:
afplay /System/Library/Sounds/Hero.aiff
