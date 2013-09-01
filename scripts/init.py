#!/usr/bin/python
# -*- encoding: utf-8 -*-

from subprocess import call, Popen, PIPE
import fnmatch
import os
import re
import shutil
import tempfile


############
# VARIABLE #
############

prefix      = "/usr/local/wine/"
WINELOADER  = os.path.join(prefix, "bin/wine")
SPSRC       = "/usr/local/src/NXWine/sources/nativedlls/WINDOWSXP-KB936929-SP3-X86-JPN.EXE"

W_DRIVE_C   = Popen([WINELOADER, "winepath.exe", "-u", "c:"], stdout=PIPE).communicate()[0].rstrip()
W_SYSTEM32  = os.path.join(W_DRIVE_C, "windows/system32/")
W_TEMP      = os.path.join(W_DRIVE_C, "windows/temp", os.path.basename(tempfile.NamedTemporaryFile().name))

print W_DRIVE_C
print W_SYSTEM32
print W_TEMP


############
# FUNCTION #
############

def wine (*args):
    call((WINELOADER,) + args)

def p7ze (src, dst):
    call(['/opt/local/bin/7z', 'e', '-y', '-ssc-', '-o' + dst, src], stdout=open(os.devnull, 'w'))



wine("rundll32.exe", "setupapi.dll,InstallHinfSection", "DefaultInstall", "128", "/usr/local/src/NXWine/inf/init.inf")

as_dxnt = '''\
amstream.dl_
d3d8.dl_
d3d8thk.dl_
d3d9.dl_
d3dim700.dl_
ddraw.dl_
ddrawex.dl_
devenum.dl_
dinput.dl_
dinput8.dl_
dmband.dl_
dmcompos.dl_
dmime.dl_
dmloader.dl_
dmscript.dl_
dmstyle.dl_
dmsynth.dl_
dmusic.dl_
dmusic.sy_
dplaysvr.ex_
dplayx.dl_
dpmodemx.dl_
dpnaddr.dl_
dpnet.dl_
dpnhpast.dl_
dpnhupnp.dl_
dpnlobby.dl_
dpnsvr.ex_
dpvacm.dl_
dpvoice.dl_
dpvsetup.ex_
dpvvox.dl_
dpwsockx.dl_
dsdmo.dl_
dsdmoprp.dl_
dsound.dl_
dsound3d.dl_
dswave.dl_
dx7vb.dl_
dx8vb.dl_
dxdiag.ch_
dxdiag.ex_
dxdiagn.dl_
encapi.dl_
ip/ks.in_
ip/kscaptur.in_
ip/ksfilter.in_
joy.cp_
ks.sy_
ksproxy.ax_
ksuser.dl_
mciqtz32.dl_
mpg2splt.ax_
msdmo.dl_
mskssrv.sy_
mspclock.sy_
mspqm.sy_
mstee.sy_
mswebdvd.dl_
pid.dl_
qasf.dl_
qcap.dl_
qdv.dl_
qdvd.dl_
qedit.dl_
qedwipes.dl_
quartz.dl_
stream.sy_
swenum.sy_
'''.splitlines()

as_bdaxp = '''\
bdaplgin.ax_
bdasup.sy_
ccdecode.sy_
ip/bda.in_
ip/ccdecode.in_
ip/mpe.in_
ip/nabtsfec.in_
ip/ndisip.in_
ip/slip.in_
ip/streamip.in_
ip/wstcodec.in_
ipsink.ax_
kstvtune.ax_
kswdmcap.ax_
ksxbar.ax_
mpe.sy_
msdv.sy_
msdvbnp.ax_
msvidctl.dl_
msyuv.dl_
nabtsfec.sy_
ndisip.sy_
psisdecd.dl_
psisrndr.ax_
slip.sy_
streamip.sy_
vbisurf.ax_
wstcodec.sy_
wstdecod.dl_
'''.splitlines()

array = []
for f in as_dxnt + as_bdaxp:
    array.append(os.path.join("i386", f))
call(["/opt/local/bin/7z", "e", "-y", "-ssc-", "-o" + W_TEMP, SPSRC] + array)
del array

for f in as_dxnt + as_bdaxp:
    call(["/opt/local/bin/7z", "e", "-y", "-ssc-", "-o" + W_SYSTEM32, os.path.join(W_TEMP, f)])

additions = """\
d3dim.xpg
d3dpmesh.xpg
d3dramp.xpg
d3drm.xpg
d3dxof.xpg
diactfrm.xpg
dimap.xpg
dxapi.xpg
gcdef.xpg
dsound.vxd
""".splitlines()

for f in additions:
    
    call(["/opt/local/bin/7z", "e", "-y", "-o" + W_SYSTEM32, "/usr/local/wine/share/wine/directx9/feb2010/dxnt.cab", f], stdout=open(os.devnull, 'w'))
    
    print 'Extracted file', f, "from dxnt.cab"
    
    if fnmatch.fnmatch(f, "dsound.vxd"):
        continue
    
    src = os.path.join(W_SYSTEM32, f)
    dst = W_SYSTEM32
    
    if fnmatch.fnmatch(f, "dxapi.xpg"):
        dst += "drivers/dxapi.sys"
    else:
        dst += os.path.splitext(f)[0] + ".dll"
    
    shutil.move(src, dst)
    print "Renamed file", src, "->", dst

reg = '''\
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"amstream"="native"
"d3dim"="native"
"d3drm"="native"
"d3dxof"="native"
"ddrawex"="native"
"devenum"="native"
"dinput"="native"
"dinput8"="native"
"dmband"="native"
"dmcompos"="native"
"dmime"="native"
"dmloader"="native"
"dmscript"="native"
"dmstyle"="native"
"dmsynth"="native"
"dmusic"="native"
"dplayx"="native"
"dpnaddr"="native"
"dpnet"="native"
"dpnhpast"="native"
"dpnlobby"="native"
"dpwsockx"="native"
"dsound"="builtin,native"
"dsound.vxd"="native"
"dsound3d"="native"
"dswave"="native"
"dxdiag.exe"="native"
"dxdiagn"="native"
"joy.cpl"="native"
"mciqtz32"="native"
"msdmo"="native"
"qcap"="native"
"qedit"="native"
"quartz"="native"
'''

Popen([WINELOADER, 'regedit.exe', '-'], stdin=PIPE).communicate(reg)

# VisualBasic 6 sp 6
# VB6.0-KB290887-X86.exe/vbrun60sp6.exe
# asycfilt.dll
# comcat.dll
# msvbvm60.dll
# oleaut32.dll
# olepro32.dll
# stdole2.tlb

files_dll = '''\
aclua.dl_
aclui.dl_
activeds.dl_
actxprxy.dl_
adsldp.dl_
adsldpc.dl_
advapi32.dl_
advpack.dl_
apphelp.dl_
asms/10/msft/windows/gdiplus/gdiplus.dll
asms/52/msft/windows/net/dxmrtp/dxmrtp.dll
asms/60/msft/vcrtl/atl.dll
asms/60/msft/vcrtl/mfc42.dll
asms/60/msft/vcrtl/mfc42u.dll
asms/60/msft/vcrtl/msvcp60.dll
asms/60/msft/windows/common/controls/comctl32.dll
asms/70/msft/windows/mswincrt/msvcirt.dll
asms/70/msft/windows/mswincrt/msvcrt.dll
aspnet_filter.dll
aspnet_isapi.dll
asycfilt.dl_
authz.dl_
avifil32.dl_
batmeter.dl_
browseui.dl_
comaddin.dl_
comadmin.dl_
comdlg32.dl_
compatui.dl_
compstui.dl_
comrepl.dl_
comres.dl_
comsetup.dl_
comsnap.dl_
comsvcs.dl_
comuid.dl_
ddrawex.dl_
devenum.dl_
devmgr.dl_
dispex.dl_
ds32gt.dl_
dsprop.dl_
dsprpres.dl_
dsquery.dl_
dssec.dl_
dssenh.dl_
dsuiext.dl_
dxmasf.dl_
dxtmsft.dl_
dxtrans.dl_
encdec.dl_
fontext.dl_
fontsub.dl_
fusion.dl_
fusion.dll
glu32.dl_
hhsetup.dl_
hid.dl_
imm32.dl_
ip/dpcdll.dl_
iyuv_32.dl_
jscript.dl_
mciavi32.dl_
mciseq.dl_
mciwave.dl_
mfc40u.dl_
mfcsubs.dl_
midimap.dl_
mp43dmod.dl_
mp4sdmod.dl_
mpg4dmod.dl_
msacm32.dl_
msadds.dl_
msasn1.dl_
mscoree.dll
mscorwks.dll
msctf.dl_
msctfp.dl_
msvbvm60.dl_
msvcrt40.dl_
msvfw32.dl_
mswmdm.dl_
netapi32.dl_
ntdll.dll
odbc32.dl_
odbc32gt.dl_
odbcdcp.dl_
odbcconf.dl_
odbccp32.dl_
odbccr32.dl_
odbccu32.dl_
odbcint.dl_
ole32.dl_
oleaut32.dl_
olecli32.dl_
olecnv32.dl_
oledb32.dl_
oledb32r.dl_
oledlg.dl_
oleprn.dl_
olepro32.dl_
query.dl_
qutil.dl_
rtutils.dl_
s3gnb.dl_
scecli.dl_
setupapi.dl_
shdoclc.dl_
shdocvw.dl_
shell32.dl_
shgina.dl_
shimgvw.dl_
shlwapi.dl_
shmedia.dl_
shsvcs.dl_
slbcsp.dl_
slbiop.dl_
stobject.dl_
strmdll.dl_
strmfilt.dl_
userenv.dl_
vbscript.dl_
win32spl.dl_
winmm.dl_
wmadmod.dl_
wmadmoe.dl_
wmasf.dl_
wmdmlog.dl_
wmdmps.dl_
wmidx.dl_
wmm2ae.dl_
wmm2ext.dl_
wmm2filt.dl_
wmm2fxa.dl_
wmm2fxb.dl_
wmpcd.dl_
wmpcore.dl_
wmphoto.dl_
wmploc.dl_
wmploc.js_
wmpui.dl_
wmsdmod.dl_
wmsdmoe.dl_
wmsdmoe2.dl_
wmspdmod.dl_
wmspdmoe.dl_
wmstream.dl_
wmvcore.dl_
wmvdmod.dl_
wmvdmoe2.dl_
ws2_32.dl_
wshcon.dl_
wshext.dl_
wsock32.dl_
wzcsapi.dl_
xactsrv.dl_
xmllite.dl_
xmlprov.dl_
xmlprovi.dl_
xolehlp.dl_
zipfldr.dl_
'''

files_acm = """\
l3codeca.ac_
msadp32.ac_
msaud32.ac_
"""

files_ax = """\
dshowext.ax_
ip/vbicodec.ax_
ip/wstpager.ax_
ip/wstrendr.ax_
mpg2data.ax_
mpg4ds32.ax_
msadds32.ax_
msscds32.ax_
vbisurf.ax_
vidcap.ax_
wmv8ds32.ax_
wmvds32.ax_
"""

files_com = """\
format.co_
more.co_
tree.co_
"""

files_cpl = """\
hdwwiz.cp_
mmsys.cp_
odbccp32.cp_
timedate.cp_
"""

files_drv = """\
msh261.dr_
msh263.dr_
wdmaud.dr_
winspool.dr_
"""

files_exe = """\
admin.exe
aspnet_regiis.exe
aspnet_state.exe
aspnet_wp.exe
author.exe
comrepl.ex_
comrereg.ex_
cscript.ex_
grpconv.ex_
odbcad32.ex_
odbcconf.ex_
pinball.ex_
smss.ex_
spider.ex_
taskmgr.ex_
vbc.exe
wscript.ex_
"""

files_ocx = """\
asctrls.oc_
flash.oc_
hhctrl.oc_
msdxm.oc_
msscript.oc_
proctexe.oc_
sysmon.oc_
tdc.oc_
wmp.oc_
wshom.oc_
"""

files_sys = '''\
avc.sy_
avcstrm.sy_
bdasup.sy_
ccdecode.sy_
dmboot.sy_
dmio.sy_
dmusic.sy_
kmixer.sy_
ksecdd.sys
ntio.sy_
ntio404.sy_
ntio411.sy_
ntio412.sy_
ntio804.sy_
s3gnbm.sy_
swmidi.sy_
sysaudio.sy_
watchdog.sy_
wdmaud.sy_
win32k.sy_
wmiacpi.sy_
wvchntxx.sy_
'''

files_tlb = """\
msado20.tl_
msado21.tl_
msado25.tl_
msado26.tl_
msado27.tl_
mscorlib.tlb
msdatsrc.tl_
mshtml.tl_
simpdata.tl_
stdole2.tl_
stdole32.tl_
"""

files_tsp = """\
h323.ts_
hidphone.ts_
ipconf.ts_
kmddsp.ts_
ndptsp.ts_
remotesp.ts_
unimdm.ts_
"""

files = \
    files_acm + \
    files_com + \
    files_cpl + \
    files_dll + \
    files_drv + \
    files_exe + \
    files_ocx + \
    files_sys + \
    files_tlb + \
    files_tsp

files = files.splitlines()

array = []
for f in files:
    array.append(os.path.join("i386", f))
call(["/opt/local/bin/7z", "e", "-y", "-ssc-", "-o" + W_TEMP, SPSRC] + array)
del array

for f in files:
    src = os.path.join(W_TEMP, os.path.basename(f))
    dst = W_SYSTEM32
    
    if f.endswith((".sy_", ".sys")):
        dst = os.path.join(dst, "drivers")
        
    if f.endswith(("_")):
        p7ze(src, dst)
        
    else:
        shutil.copy2(src, dst)
        
    if f.endswith((".ex_", ".exe")):
        os.chmod(os.path.join(dst, os.path.splitext(os.path.basename(f))[0] + ".exe"), 0755)

call(["/opt/local/bin/7z", "e", "-y", "-o" + W_TEMP, SPSRC, "i386/root/cmpnents/netfx/i386/netfx.cab"])
call(["/opt/local/bin/7z", "e", "-y", "-o" + W_SYSTEM32, os.path.join(W_TEMP, "netfx.cab"), "msvcp70.dll", "msvcr70.dll"])


################
# RegisterDlls #
################

inf_data = """\
[version]
signature = $CHICAGO$

[DefaultInstall]
RegisterDlls = RegisterDllsSection

[RegisterDllsSection]
11,,quartz.dll      ,1
11,,mfc40u.dll      ,1
11,,mfc42.dll       ,1
11,,mfc42u.dll      ,1


11,,actxprxy.dll    ,1
11,,advpack.dll     ,1
11,,asctrls.ocx     ,1
11,,atl.dll         ,1
11,,bdaplgin.ax     ,1
11,,browseui.dll    ,1
11,,ddrawex.dll     ,1
11,,devenum.dll     ,1
11,,dinput.dll      ,1
11,,dinput8.dll     ,1
11,,dispex.dll      ,1
11,,dmband.dll      ,1
11,,dmcompos.dll    ,1
11,,dmime.dll       ,1
11,,dmloader.dll    ,1
11,,dmscript.dll    ,1
11,,dmstyle.dll     ,1
11,,dmsynth.dll     ,1
11,,dmusic.dll      ,1
11,,dplayx.dll      ,1
11,,dpnet.dll       ,1
11,,dpnhpast.dll    ,1
11,,dpnhupnp.dll    ,1
11,,dpvacm.dll      ,1
11,,dpvoice.dll     ,1
11,,dpvvox.dll      ,1
11,,dsdmo.dll       ,1
11,,dsdmoprp.dll    ,1
11,,dsprop.dll      ,1
11,,dsquery.dll     ,1
11,,dssenh.dll      ,1
11,,dsuiext.dll     ,1
11,,dswave.dll      ,1
11,,dx7vb.dll       ,1
11,,dx8vb.dll       ,1
11,,dxdiagn.dll     ,1
11,,dxmasf.dll      ,1
11,,dxmrtp.dll      ,1
11,,dxtmsft.dll     ,1
11,,dxtrans.dll     ,1
11,,encapi.dll      ,1
11,,encdec.dll      ,1
11,,flash.ocx       ,1
11,,fontext.dll     ,1
11,,hhctrl.ocx      ,1
11,,ipsink.ax       ,1
11,,jscript.dll     ,1
11,,ksproxy.ax      ,1
11,,kswdmcap.ax     ,1
11,,l3codeca.acm    ,1
11,,mp43dmod.dll    ,1
11,,mp4sdmod.dll    ,1
11,,mpg2data.ax     ,1
11,,mpg2splt.ax     ,1
11,,mpg4dmod.dll    ,1
11,,mpg4ds32.ax     ,1
11,,msadds32.ax     ,1
11,,msdvbnp.ax      ,1
11,,msdxm.ocx       ,1
11,,msscds32.ax     ,1
11,,msscript.ocx    ,1
11,,msvbvm60.dll    ,1
11,,mswebdvd.dll    ,1
11,,mswmdm.dll      ,1
11,,oledb32.dll     ,1
11,,oledb32r.dll    ,1
11,,oleprn.dll      ,1
11,,proctexe.ocx    ,1
11,,psisrndr.ax     ,1
11,,qasf.dll        ,1
11,,qcap.dll        ,1
11,,qdv.dll         ,1
11,,qdvd.dll        ,1
11,,qedit.dll       ,1
11,,query.dll       ,1
11,,qutil.dll       ,1
11,,scecli.dll      ,1
11,,shdocvw.dll     ,1
11,,shgina.dll      ,1
11,,shimgvw.dll     ,1
11,,shmedia.dll     ,1
11,,shsvcs.dll      ,1
11,,slbcsp.dll      ,1
11,,slbiop.dll      ,1
11,,stobject.dll    ,1
11,,sysmon.ocx      ,1
11,,tdc.ocx         ,1
11,,vbicodec.ax     ,1
11,,vbisurf.ax      ,1
11,,vbscript.dll    ,1
11,,vidcap.ax       ,1
11,,wmadmod.dll     ,1
11,,wmadmoe.dll     ,1
11,,wmdmlog.dll     ,1
11,,wmdmps.dll      ,1
11,,wmm2ae.dll      ,1
11,,wmm2ext.dll     ,1
11,,wmm2filt.dll    ,1
11,,wmm2fxa.dll     ,1
11,,wmm2fxb.dll     ,1
11,,wmp.ocx         ,1
11,,wmpcd.dll       ,1
11,,wmpcore.dll     ,1
11,,wmphoto.dll     ,1
11,,wmpui.dll       ,1
11,,wmsdmod.dll     ,1
11,,wmsdmoe.dll     ,1
11,,wmsdmoe2.dll    ,1
11,,wmspdmod.dll    ,1
11,,wmspdmoe.dll    ,1
11,,wmstream.dll    ,1
11,,wmv8ds32.ax     ,1
11,,wmvcore.dll     ,1
11,,wmvdmod.dll     ,1
11,,wmvdmoe2.dll    ,1
11,,wmvds32.ax      ,1
11,,wshcon.dll      ,1
11,,wshext.dll      ,1
11,,wshom.ocx       ,1
11,,wstdecod.dll    ,1
11,,wstpager.ax     ,1
11,,wstrendr.ax     ,1
11,,xmlprov.dll     ,1
11,,xmlprovi.dll    ,1
11,,zipfldr.dll     ,1
"""

inf_tmp = os.path.join(W_TEMP, os.path.basename(tempfile.NamedTemporaryFile(suffix=".inf").name))
open(inf_tmp, "w").write(inf_data)
wine("rundll32.exe", "setupapi.dll,InstallHinfSection", "DefaultInstall", "128", inf_tmp)



##############
# Visual C++ #
##############

wine('rundll32.exe', 'setupapi,InstallHinfSection', 'DefaultInstall', '128', prefix + '/share/wine/vcredist.inf')
wine(prefix + '/share/wine/vcrun2005/vcredist_x86.exe', '/q')
wine(prefix + '/share/wine/vcrun2008sp1/vcredist_x86.exe', '/q')
wine(prefix + '/share/wine/vcrun2010sp1/vcredist_x86.exe', '/q')
wine('wineboot.exe', '-r')



###########
# DirectX #
###########

wine("rundll32.exe", "setupapi,InstallHinfSection", "DefaultInstall", "128", prefix + "/share/wine/dxredist.inf")
os.putenv("WINEDLLOVERRIDES", "setupapi=n")
wine(prefix + "/share/wine/directx9/feb2010/dxsetup.exe", "/silent")
wine("wineboot.exe", "-r")
wine(prefix + "/share/wine/directx9/jun2010/dxsetup.exe", "/silent")
wine("wineboot.exe", "-r")
os.unsetenv("WINEDLLOVERRIDES")



####################
# Direct3D setting #
####################

plist   = Popen(['/usr/sbin/system_profiler', 'SPDisplaysDataType'], stdout=PIPE).communicate()[0]
vendor  = re.search('Vendor:.*(0x....)', plist).group(1)
device  = re.search('Device ID: (0x....)', plist).group(1)
reg = '''\
[HKEY_CURRENT_USER\\Software\\Wine\\Direct3D]
"*VideoPciDeviceID"=dword:__VideoPciDeviceID__
"*VideoPciVendorID"=dword:__VideoPciVendorID__
'''\
.replace('__VideoPciDeviceID__', device)\
.replace('__VideoPciVendorID__', vendor)
Popen([prefix + "/libexec/wine", "regedit.exe", "-"], stdin=PIPE).communicate(reg)


shutil.rmtree(W_TEMP)
