${prefix}/libexec/wine wineboot.exe --init

install -v -m 0644 ${prefix}/lib/wine/nativedlls/* "${WINEPREFIX}"/drive_c/windows/system32

cat <<__REGEDIT4__ | wine regedit -
[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]

;;;  d3dx9 ;;;

"*d3dx9_42"="native"
"*d3dx9_43"="native"

;;; directmusic ;;;

"*devenum"="native"
"*dmband"="native"
"*dmcompos"="native"
"*dmime"="native"
"*dmloader"="native"
"*dmscript"="native"
"*dmstyle"="native"
"*dmsynth"="native"
"*dmusic"="native"
"*dsound"="native"
"*dswave"="native"
"*l3codecx"="native"

;;; dplayx ;;;

"*dplayx"="native"

"*gdiplus"="builtin,native"
"*quartz"="native"
__REGEDIT4__

${prefix}/libexec/wine regsvr32.exe \
    {devenum,dmband,dmcompos,dmime,dmloader,dmscript,dmstyle,dmsynth,dmusic,dswave}.dll l3codecx.ax \
    quartz.dll
