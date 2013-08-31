#!/usr/bin/python
# -*- encoding: utf-8 -*-

import fnmatch
import os
import re
import shutil
import subprocess

prefix      = "/usr/local/wine/"
WINELOADER  = prefix + "bin/wine"
w_system32  = os.path.expanduser('~/.wine/drive_c/windows/system32/')
srcmedia    = '/Volumes/WindowsXPSP3/i386/'

def wine (*args):
    cmd = (WINELOADER,) + args
    subprocess.call(cmd)

def p7ze (src, dst):
    subprocess.call(
        ['/opt/local/bin/7z', 'e', '-y', '-ssc-', '-o' + dst, src],
        stdout=open(os.devnull, 'w'))
    print 'Extracted', src, '->', dst

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

for f in as_dxnt + as_bdaxp:
    
    src = os.path.join(srcmedia, f)
    dst = w_system32
  
    if f.endswith(('.sy_')):
        dst += 'drivers'
        
    elif f.endswith(('.in_')):
        dst += '../inf'
    
    p7ze(src, dst)


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
    
    subprocess.call(
        ["/opt/local/bin/7z", "e", "-y", "-o" + w_system32, "/usr/local/wine/share/wine/directx9/feb2010/dxnt.cab", f],
        stdout=open(os.devnull, 'w'))
    
    print 'Extracted file', f, "from dxnt.cab"
    
    if fnmatch.fnmatch(f, "dsound.vxd"):
        continue
    
    src = os.path.join(w_system32, f)
    dst = w_system32
    
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

subprocess.Popen([WINELOADER, 'regedit.exe', '-'], stdin=subprocess.PIPE).communicate(reg)

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

for f in files:
    
    src = srcmedia + f
    dst = w_system32
    
    if f.endswith((".sy_", ".sys")):
        dst += "drivers"
        
    if f.endswith(("_")):
        p7ze(src, dst)
        
    else:
        shutil.copy2(src, dst)
        print "Copied file", src, "->", os.path.join(dst, f)
        
    if f.endswith((".ex_", ".exe")):
        os.chmod(dst + os.path.splitext(os.path.basename(f))[0] + ".exe", 0755)

subprocess.call(["/opt/local/bin/7z", "e", "-y", "-o" + w_system32, srcmedia + "root/cmpnents/netfx/i386/netfx.cab", "msvcp70.dll", "msvcr70.dll"])

RegisterDlls = """\
actxprxy.dll
advpack.dll
asctrls.ocx
atl.dll
bdaplgin.ax
browseui.dll
ddrawex.dll
devenum.dll
dinput.dll
dinput8.dll
dispex.dll
dmband.dll
dmcompos.dll
dmime.dll
dmloader.dll
dmscript.dll
dmstyle.dll
dmsynth.dll
dmusic.dll
dplayx.dll
dpnet.dll
dpnhpast.dll
dpnhupnp.dll
dpvacm.dll
dpvoice.dll
dpvvox.dll
dsdmo.dll
dsdmoprp.dll
dsprop.dll
dsquery.dll
dssenh.dll
dsuiext.dll
dswave.dll
dx7vb.dll
dx8vb.dll
dxdiagn.dll
dxmasf.dll
dxmrtp.dll
dxtmsft.dll
dxtrans.dll
encapi.dll
encdec.dll
flash.ocx
fontext.dll
hhctrl.ocx
ipsink.ax
jscript.dll
ksproxy.ax
kswdmcap.ax
l3codeca.acm
mfc40u.dll
mfc42.dll
mfc42u.dll
mp43dmod.dll
mp4sdmod.dll
mpg2data.ax
mpg2splt.ax
mpg4dmod.dll
mpg4ds32.ax
msadds32.ax
msdvbnp.ax
msdxm.ocx
msscds32.ax
msscript.ocx
msvbvm60.dll
mswebdvd.dll
mswmdm.dll
oledb32.dll
oledb32r.dll
oleprn.dll
proctexe.ocx
psisrndr.ax
qasf.dll
qcap.dll
qcliprov.dll
qdv.dll
qdvd.dll
qedit.dll
quartz.dll
query.dll
qutil.dll
scecli.dll
shdocvw.dll
shgina.dll
shimgvw.dll
shmedia.dll
shsvcs.dll
slbcsp.dll
slbiop.dll
stobject.dll
sysmon.ocx
tdc.ocx
vbicodec.ax
vbisurf.ax
vbscript.dll
vidcap.ax
wmadmod.dll
wmadmoe.dll
wmdmlog.dll
wmdmps.dll
wmm2ae.dll
wmm2ext.dll
wmm2filt.dll
wmm2fxa.dll
wmm2fxb.dll
wmp.ocx
wmpcd.dll
wmpcore.dll
wmphoto.dll
wmpui.dll
wmsdmod.dll
wmsdmoe.dll
wmsdmoe2.dll
wmspdmod.dll
wmspdmoe.dll
wmstream.dll
wmv8ds32.ax
wmvcore.dll
wmvdmod.dll
wmvdmoe2.dll
wmvds32.ax
wshcon.dll
wshext.dll
wshom.ocx
wstdecod.dll
wstpager.ax
wstrendr.ax
xmlprov.dll
xmlprovi.dll
zipfldr.dll
""".splitlines()

for f in RegisterDlls:
    wine('regsvr32.exe', f)



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
plist   = subprocess.Popen(['/usr/sbin/system_profiler', 'SPDisplaysDataType'], stdout=subprocess.PIPE).communicate()[0]
vendor  = re.search('Vendor:.*(0x....)', plist).group(1)
device  = re.search('Device ID: (0x....)', plist).group(1)
reg = '''\
[HKEY_CURRENT_USER\\Software\\Wine\\Direct3D]
"*VideoPciDeviceID"=dword:__VideoPciDeviceID__
"*VideoPciVendorID"=dword:__VideoPciVendorID__
'''\
.replace('__VideoPciDeviceID__', device)\
.replace('__VideoPciVendorID__', vendor)
subprocess.Popen([prefix + "/libexec/wine", "regedit.exe", "-"], stdin=subprocess.PIPE).communicate(reg)