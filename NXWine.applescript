--
-- NXWine.app - No X11 Wine
-- Created by mattintosh4 on @DATE@.
-- Copyright (c) 2013 mattintosh4, mattintosh4@gmx.com
-- https://github.com/mattintosh4/NXWine
--

property wine : missing value
property wineserver : missing value

on NXWineGetPath_()
    set prefix to quoted form of POSIX path of (path to resource "bin")
    set wine to prefix & "wine" & space
    set wineserver to prefix & "wineserver -p0;"
end NXWineGetPath_

on main(input)
    NXWineGetPath_()
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
    main("explorer")
end run
