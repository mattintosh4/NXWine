# NXWine is No X11 Wine for Mac OS X

## Information and application bundle download page

http://mattintosh.hatenablog.com/entry/nxwine (Japanese)


## System requirements

- Mac OS X 10.6+


## Command-line usage

### Wine

```sh
$ /Applications/NXWine.app/Contents/Resources/bin/wine [args]
```

### NXWinetricks

NXWinetricks is plugin installation supoprt script.

#### packages

- RPG TKOOL 2000 RTP
- RPG TKOOL 2003 RTP
- RPG TKOOL XP RTP v103
- RPG TKOOL VX RTP v202

and some Windows free games. See more info, `nxwinetricks --help`.

```sh
$ /Applications/NXWine.app/Contents/Resources/bin/nxwinetricks [package]
```

### How to use Winetricks

```sh
$ /Applications/NXWine.app/Contents/Resources/bin/winetricks [args]
```

See more info, `winetricks -h`.

## How to customize AppleScript

```sh
$ open /Applications/NXWine.app/Contents/Resources/Scripts/main.scpt
```

_Do not open NXWine.app by AppleScript Editor._
