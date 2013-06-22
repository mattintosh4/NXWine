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

on main(input)
  try
    do shell script "WINEDEBUG=-all /Applications/NXWine.app/Contents/Resources/bin/wine" & space & input & space & "&>/dev/null &"
  end try
end main

on run
  main("explorer")
end run

on open argv
  repeat with aFile in argv
    main("start /Unix" & space & quoted form of (POSIX path of aFile))
  end repeat
end open

on reopen
  run
end reopen

on quit
  try
    do shell script "kill $(ps ax | awk '/\\/Applications\\/NXWine.app\\/Contents\\/Resources\\/libexec\\/wine/ { print $1 }')"
  end try
  continue quit   
end quit
