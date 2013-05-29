wine wineboot --init

install -v -m 0644 ${prefix}/lib/wine/nativedlls/* "${WINEPREFIX}"/drive_c/windows/system32

cat <<__REGEDIT4__ | wine regedit -
[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
"*d3dx9_42"="native"
"*d3dx9_43"="native"
"*devenum"="native"
"*dmband"="native"
"*dmcompos"="native"
"*dmime"="native"
"*dmloader"="native"
"*dmscript"="native"
"*dmstyle"="native"
"*dmsynth"="native"
"*dmusic"="native"
"*dplayx"="native"
"*dsound"="native"
"*dswave"="native"
"*gdiplus"="builtin,native"
"*l3codecx"="native"
"*quartz"="native"
__REGEDIT4__

wine regsvr32   {devenum,dmband,dmcompos,dmime,dmloader,dmscript,dmstyle,dmsynth,dmusic,dswave}.dll l3codecx.ax \
                quartz.dll
