NXWine is No X11 Wine for Mac OS X 10.6+. However, if you play game that needs glu32.dll, have to install XQuartz. NXWine does not have Mesa libraries.

Other information and application bundle download page: http://mattintosh.hatenablog.com/entry/nxwine (Japanese)

## Installation

- New version: Run "NXWine Installer.app" from disk image.
- Old version: Install "NXWine.app" to `/Applications` folder.

Note: This application's startup location has been fixed to `/Applications/NXWine.app`.

### Uninstall

Delete following directories.

- `/Applications/NXWine.app`
- `~/Library/Caches/com.github.mattintosh4.NXWine`

Wine and Winetricks use some directory. Refer to official guide about them.

- Wine: http://wiki.winehq.org/FAQ#head-ddc6f242056eb1a4fe566c9434d15fd8b64606aa
- Wientricks: http://code.google.com/p/winetricks/wiki/FAQ

## Command-line usage

### Wine

```sh
$ /Applications/NXWine.app/Contents/Resources/bin/wine [args]
```

Note: `Resources/bin/wine` is customized script. Original binary is `Resources/libexec/wine`.

### NXWinetricks

NXWinetricks is plugin installation support script. (You need to connect to network)

#### packages

- RPG TKOOL 2000 RTP
- RPG TKOOL 2003 RTP
- RPG TKOOL XP RTP v103
- RPG TKOOL VX RTP v202

and some Windows free games. Cache files are saved into `/Users/yourname/Library/Caches/com.github.mattintosh4.NXWine/[package]`. See more info, `nxwinetricks --help`.

```sh
$ /Applications/NXWine.app/Contents/Resources/bin/nxwinetricks [package]
```

### Winetricks

```sh
$ /Applications/NXWine.app/Contents/Resources/bin/winetricks [args]
```

See more info, `winetricks -h` and [ Winetricks official page](http://winetricks.org).

### 7-Zip

```sh
$ /Applications/NXWine.app/Contents/Resources/bin/wine 7z.exe [args]
$ /Applications/NXWine.app/Contents/Resources/bin/wine 7zFM.exe file
```

## How to customize AppleScript

```sh
$ open /Applications/NXWine.app/Contents/Resources/Scripts/main.scpt
```

_Do not open NXWine.app by AppleScript Editor._
