#!/usr/bin/env python
# -*- coding: utf-8 -*-

from subprocess import call, check_call, Popen, PIPE
import os
import sys
import shutil
import tempfile


prefix      = "/usr/local/wine"
WINELOADER  = os.path.join(prefix, "bin", "wine")
CABEXTRACT  = os.path.join(prefix, "bin", "cabextract")


W_DRIVE_C   = Popen(
    [os.path.join(prefix, "libexec", "wine"), "winepath.exe", "-u", "c:"],
    stdout=PIPE).communicate()[0].strip()

if not os.path.exists(W_DRIVE_C):
    print "Could not find WINEPREFIX."
    sys.exit(1)

W_SYSTEM32  = os.path.join(W_DRIVE_C, "windows", "system32")
W_DRIVERS   = os.path.join(W_DRIVE_C, "windows", "system32", "drivers")
W_INF       = os.path.join(W_DRIVE_C, "windows", "inf")
W_TEMP      = tempfile.mkdtemp(dir=os.path.join(W_DRIVE_C, "windows", "temp"))

# Windows XP Service Pack 3
SPSRC       = os.path.expanduser("~/Library/Caches/winetricks/xpsp3jp/WindowsXP-KB936929-SP3-x86-JPN.exe")


class Wine:

    def run(self, *args):
        check_call((WINELOADER,) + args)

    def regedit(self, *args):
        self.run("regedit.exe", *args)

    def regedit_stdin(self, strings):
        Popen((WINELOADER, "regedit.exe", "-"), stdin=PIPE).communicate(strings)

    def rundll32(self, f, InstallHinfSection="DefaultInstall"):
        self.run("rundll32.exe", "setupapi.dll,InstallHinfSection", InstallHinfSection, "128", f)

wine            = Wine()
w_try           = wine.run
w_regedit       = wine.regedit
w_regedit_stdin = wine.regedit_stdin
w_rundll32      = wine.rundll32


def cabextract(*args):
    check_call((CABEXTRACT, "-q", "-L") + args)

# ------------------------------------------------------------------------------
# dxnt
# ------------------------------------------------------------------------------
# 2013-09-03: dpnet.dll は dxnt.cab 内のものを使用すること
#
def load_dxnt():
    print "Extracting files from " + SPSRC + "..."
    
    _files = (
        # as dxnt.cab
        """
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
        """

        # as bdaxp.cab
        + """
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
        """
    ).split()

    for f in _files:
        f = os.path.join("i386", f)
        cabextract("-d", W_TEMP, "-F", f, SPSRC)

        f = os.path.join(W_TEMP, f)
        if f.endswith(".in_"):
            cabextract("-d", W_INF, f)
        elif f.endswith(".sy_"):
            cabextract("-d", W_DRIVERS, f)
        else:
            cabextract("-d", W_SYSTEM32, f)

    #----------#
    # dxnt.cab #
    #----------#
    print "Extracting files from dxnt.cab..."
    
    _files = """
    d3dim.xpg
    d3dpmesh.xpg
    d3dramp.xpg
    d3drm.xpg
    d3dxof.xpg
    diactfrm.xpg
    dimap.xpg
    dpnet.dll
    dsound.vxd
    dxapi.xpg
    gcdef.xpg
    """.split()
    
    for f in _files:
        cabextract("-d", W_SYSTEM32, "-F", f, os.path.join(prefix, "share/wine/directx9/feb2010/dxnt.cab"))

        f = os.path.join(W_SYSTEM32, f)
        if f.endswith(("dpnet.dll", "dsound.vxd")):
            continue
        elif f.endswith("dxapi.xpg"):
            _dst = os.path.join(W_DRIVERS, "dxapi.sys")
        else:
            _dst = os.path.join(os.path.splitext(f)[0] + ".dll")

        shutil.move(f, _dst)
        print f, "->", _dst

    w_regedit_stdin("""\
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"*amstream"     ="native"
"*d3dim"        ="native"
"*d3drm"        ="native"
"*d3dxof"       ="native"
"*ddrawex"      ="native"
"*devenum"      ="native"
"*dinput"       ="native"
"*dinput8"      ="native"
"*dmband"       ="native"
"*dmcompos"     ="native"
"*dmime"        ="native"
"*dmloader"     ="native"
"*dmscript"     ="native"
"*dmstyle"      ="native"
"*dmsynth"      ="native"
"*dmusic"       ="native"
"*dplayx"       ="native"
"*dpnaddr"      ="native"
"*dpnet"        ="native"
"*dpnhpast"     ="native"
"*dpnlobby"     ="native"
"*dpwsockx"     ="native"
"*dsound"       ="builtin,native"
"*dsound.vxd"   ="native"
"*dsound3d"     ="native"
"*dswave"       ="native"
"*dxdiag.exe"   ="native"
"*dxdiagn"      ="native"
"*joy.cpl"      ="native"
"*mciqtz32"     ="native"
"*msdmo"        ="native"
"*qcap"         ="native"
"*qedit"        ="native"
"*quartz"       ="native"
""")

# ------------------------------------------------------------------------------
# core component
# ------------------------------------------------------------------------------
## VisualBasic 6 sp 6 data
# VB6.0-KB290887-X86.exe/vbrun60sp6.exe
# asycfilt.dll
# comcat.dll
# msvbvm60.dll
# oleaut32.dll
# olepro32.dll
# stdole2.tlb

def load_core():
    print "Extracting files from " + SPSRC + "..."
    
    _files = (
        # dll
        [
            "aclua.dl_"     ,
            "aclui.dl_"     ,
            "activeds.dl_"  ,
            "actxprxy.dl_"  ,
            "adsldp.dl_"    ,
            "adsldpc.dl_"   ,
            "advapi32.dl_"  ,
            "advpack.dl_"   ,
            "apphelp.dl_"   ,
            "asms/10/msft/windows/gdiplus/gdiplus.dll"          ,
            "asms/52/msft/windows/net/dxmrtp/dxmrtp.dll"        ,
            "asms/60/msft/vcrtl/atl.dll"                        ,
            "asms/60/msft/vcrtl/msvcp60.dll"                    ,
            "asms/60/msft/windows/common/controls/comctl32.dll" ,
            "asms/70/msft/windows/mswincrt/msvcirt.dll"         ,
            "asms/70/msft/windows/mswincrt/msvcrt.dll"          ,
            "authz.dl_"     ,
            "avifil32.dl_"  ,
            "batmeter.dl_"  ,
            "browseui.dl_"  ,
            "comaddin.dl_"  ,
            "comadmin.dl_"  ,
            "comdlg32.dl_"  ,
            "compatui.dl_"  ,
            "compstui.dl_"  ,
            "comrepl.dl_"   ,
            "comres.dl_"    ,
            "comsetup.dl_"  ,
            "comsnap.dl_"   ,
            "comsvcs.dl_"   ,
            "comuid.dl_"    ,
            "devmgr.dl_"    ,
            "dispex.dl_"    ,
            "ds32gt.dl_"    ,
            "dsprop.dl_"    ,
            "dsprpres.dl_"  ,
            "dsquery.dl_"   ,
            "dssec.dl_"     ,
            "dssenh.dl_"    ,
            "dsuiext.dl_"   ,
            "dxmasf.dl_"    ,
            "dxtmsft.dl_"   ,
            "dxtrans.dl_"   ,
            "encdec.dl_"    ,
            "fusion.dll"    ,
            "glu32.dl_"     ,
            "hhsetup.dl_"   ,
            "hid.dl_"       ,
            "imagehlp.dll"  ,
            "imm32.dl_"     ,
            "ip/dpcdll.dl_" ,
            "ip/pidgen.dll" ,
            "iyuv_32.dl_"   ,
            "jscript.dl_"   ,
            "mciavi32.dl_"  ,
            "mciseq.dl_"    ,
            "mciwave.dl_"   ,
            "mfc40u.dl_"    ,
            "mfc42.dl_"     ,
            "mfc42u.dl_"    ,
            "mfcsubs.dl_"   ,
            "midimap.dl_"   ,
            "mp43dmod.dl_"  ,
            "mp4sdmod.dl_"  ,
            "mpg4dmod.dl_"  ,
            "msacm32.dl_"   ,
            "msadds.dl_"    ,
            "msasn1.dl_"    ,
            "mscms.dl_"     ,
            "msftedit.dl_"  ,
            "msctf.dl_"     ,
            "msctfp.dl_"    ,
            "msrle32.dl_"   ,
            "msvcrt40.dl_"  ,
            "msvfw32.dl_"   ,
            "mswmdm.dl_"    ,
            "msxml.dl_"     ,
            "msxml2.dl_"    ,
            "msxml3.dl_"    ,
            "msxml6.dl_"    ,
            "msxml6r.dl_"   ,
            "netapi32.dl_"  ,
            "odbc32.dl_"    ,
            "odbc32gt.dl_"  ,
            "odbcbcp.dl_"   ,
            "odbcconf.dl_"  ,
            "odbccp32.dl_"  ,
            "odbccr32.dl_"  ,
            "odbccu32.dl_"  ,
            "odbcint.dl_"   ,
            "ole32.dl_"     ,
            "olecli32.dl_"  ,
            "olecnv32.dl_"  ,
            "oledb32.dl_"   ,
            "oledb32r.dl_"  ,
            "oledlg.dl_"    ,
            "oleprn.dl_"    ,
            "query.dl_"     ,
            "qutil.dl_"     ,
            "rtutils.dl_"   ,
            "s3gnb.dl_"     ,
            "samlib.dl_"    ,
            "scecli.dl_"    ,
            "setupapi.dl_"  ,
            "shdoclc.dl_"   ,
            "shdocvw.dl_"   ,
            "shell32.dl_"   ,
            "shgina.dl_"    ,
            "shimgvw.dl_"   ,
            "shlwapi.dl_"   ,
            "shmedia.dl_"   ,
            "shsvcs.dl_"    ,
            "slbcsp.dl_"    ,
            "slbiop.dl_"    ,
            "spoolss.dl_"   ,
            "stobject.dl_"  ,
            "strmdll.dl_"   ,
            "strmfilt.dl_"  ,
            "userenv.dl_"   ,
            "vbscript.dl_"  ,
            "wavemsp.dl_"   ,
            "win32spl.dl_"  ,
            "winmm.dl_"     ,
            "wmadmod.dl_"   ,
            "wmadmoe.dl_"   ,
            "wmasf.dl_"     ,
            "wmdmlog.dl_"   ,
            "wmdmps.dl_"    ,
            "wmidx.dl_"     ,
            "wmm2ae.dl_"    ,
            "wmm2ext.dl_"   ,
            "wmm2filt.dl_"  ,
            "wmm2fxa.dl_"   ,
            "wmm2fxb.dl_"   ,
            "wmpcd.dl_"     ,
            "wmpcore.dl_"   ,
            "wmphoto.dl_"   ,
            "wmploc.dl_"    ,
            "wmploc.js_"    ,
            "wmpui.dl_"     ,
            "wmsdmod.dl_"   ,
            "wmsdmoe.dl_"   ,
            "wmsdmoe2.dl_"  ,
            "wmspdmod.dl_"  ,
            "wmspdmoe.dl_"  ,
            "wmstream.dl_"  ,
            "wmvcore.dl_"   ,
            "wmvdmod.dl_"   ,
            "wmvdmoe2.dl_"  ,
            "ws2_32.dl_"    ,
            "wshbth.dl_"    ,
            "wshcon.dl_"    ,
            "wshext.dl_"    ,
            "wship6.dl_"    ,
            "wshirda.dl_"   ,
            "wshrm.dl_"     ,
            "wshtcpip.dl_"  ,
            "wsock32.dl_"   ,
            "wzcsapi.dl_"   ,
            "xactsrv.dl_"   ,
            "xmllite.dl_"   ,
            "xmlprov.dl_"   ,
            "xmlprovi.dl_"  ,
            "xolehlp.dl_"   ,
            "zipfldr.dl_"   ,
        ]

        # acm
        + [
            "imaadp32.ac_"  ,
            "l3codeca.ac_"  ,
            "msadp32.ac_"   ,
            "msaud32.ac_"   ,
            "sl_anet.ac_"   ,
        ]

        # ax
        + [
            "dshowext.ax_"      ,
            "ip/vbicodec.ax_"   ,
            "ip/wstpager.ax_"   ,
            "ip/wstrendr.ax_"   ,
            "mpg2data.ax_"      ,
            "mpg4ds32.ax_"      ,
            "msadds32.ax_"      ,
            "msscds32.ax_"      ,
            "vbisurf.ax_"       ,
            "vidcap.ax_"        ,
            "wmv8ds32.ax_"      ,
            "wmvds32.ax_"       ,
        ]

        # com
        + [
            "format.co_"    ,
            "more.co_"      ,
            "tree.co_"      ,
        ]

        # cpl
        + [
            "hdwwiz.cp_"    ,
            "mmsys.cp_"     ,
            "odbccp32.cp_"  ,
            "timedate.cp_"  ,
        ]

        # drv
        + [
            "msh261.dr_"    ,
            "msh263.dr_"    ,
            "wdmaud.dr_"    ,
        ]

        # exe
        + [
            "admin.exe"         ,
            "aspnet_regiis.exe" ,
            "aspnet_state.exe"  ,
            "aspnet_wp.exe"     ,
            "author.exe"        ,
            "comrepl.ex_"       ,
            "comrereg.ex_"      ,
            "cscript.ex_"       ,
            "grpconv.ex_"       ,
            "odbcad32.ex_"      ,
            "odbcconf.ex_"      ,
            "smss.ex_"          ,
            "spider.ex_"        ,
            "taskmgr.ex_"       ,
            "wscript.ex_"       ,
        ]

        # ocx
        + [
            "asctrls.oc_"   ,
            "flash.oc_"     ,
            "hhctrl.oc_"    ,
            "msdxm.oc_"     ,
            "msscript.oc_"  ,
            "proctexe.oc_"  ,
            "sysmon.oc_"    ,
            "tdc.oc_"       ,
            "wmp.oc_"       ,
            "wshom.oc_"     ,
        ]

        # sys
        + [
            "avc.sy_"       ,
            "avcstrm.sy_"   ,
            "bdasup.sy_"    ,
            "ccdecode.sy_"  ,
            "dmboot.sy_"    ,
            "dmio.sy_"      ,
            "dmusic.sy_"    ,
            "kmixer.sy_"    ,
            "ksecdd.sys"    ,
            "ntio.sy_"      ,
            "ntio404.sy_"   ,
            "ntio411.sy_"   ,
            "ntio412.sy_"   ,
            "ntio804.sy_"   ,
            "s3gnbm.sy_"    ,
            "swmidi.sy_"    ,
            "sysaudio.sy_"  ,
            "watchdog.sy_"  ,
            "wdmaud.sy_"    ,
            "win32k.sy_"    ,
            "wmiacpi.sy_"   ,
            "wvchntxx.sy_"  ,
        ]

        # tlb
        + [
            "msado20.tl_"   ,
            "msado21.tl_"   ,
            "msado25.tl_"   ,
            "msado26.tl_"   ,
            "msado27.tl_"   ,
            "mscorlib.tlb"  ,
            "msdatsrc.tl_"  ,
            "mshtml.tl_"    ,
            "simpdata.tl_"  ,
            "stdole32.tl_"  ,
        ]

        # tsp
        + [
            "h323.ts_"      ,
            "hidphone.ts_"  ,
            "ipconf.ts_"    ,
            "kmddsp.ts_"    ,
            "ndptsp.ts_"    ,
            "remotesp.ts_"  ,
            "unimdm.ts_"    ,
        ]
    )

    for f in _files:
        f = os.path.join("i386", f)
        cabextract("-d", W_TEMP, "-F", f, SPSRC)

        f = os.path.join(W_TEMP, f)

        if f.endswith((".sy_", ".sys")):
            _dst = W_DRIVERS
        else:
            _dst = W_SYSTEM32

        if f.endswith(("_")):
            cabextract("-d", _dst, f)
        else:
            shutil.copy2(f, _dst)

    #-----------#
    # netfx.cab #
    #-----------#
    _src = "i386/root/cmpnents/netfx/i386/netfx.cab"
    cabextract("-d", W_TEMP, "-F", _src, SPSRC)
    _src = os.path.join(W_TEMP, _src)
    cabextract("-d", W_SYSTEM32, "-F", "msvc?70.dll", _src)

    #--------------#
    # RegisterDlls #
    #--------------#
    _inf_data = """\
[version]
signature = $CHICAGO$

[DefaultInstall]
RegisterDlls = RegisterDllsSection

[RegisterDllsSection]
11,,quartz.dll      ,1
11,,atl.dll         ,1
11,,mfc40u.dll      ,1
11,,mfc42.dll       ,1
11,,mfc42u.dll      ,1

11,,actxprxy.dll    ,1
11,,advpack.dll     ,1
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
11,,jscript.dll     ,1
11,,mp43dmod.dll    ,1
11,,mp4sdmod.dll    ,1
11,,mpg4dmod.dll    ,1
11,,mswebdvd.dll    ,1
11,,mswmdm.dll      ,1
11,,msxml6.dll      ,1
11,,oledb32.dll     ,1
11,,oledb32r.dll    ,1
11,,oleprn.dll      ,1
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
11,,vbscript.dll    ,1
11,,wavemsp.dll     ,1
11,,wmadmod.dll     ,1
11,,wmadmoe.dll     ,1
11,,wmdmlog.dll     ,1
11,,wmdmps.dll      ,1
11,,wmm2ae.dll      ,1
11,,wmm2ext.dll     ,1
11,,wmm2filt.dll    ,1
11,,wmm2fxa.dll     ,1
11,,wmm2fxb.dll     ,1
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
11,,wmvcore.dll     ,1
11,,wmvdmod.dll     ,1
11,,wmvdmoe2.dll    ,1
11,,wshcon.dll      ,1
11,,wshext.dll      ,1
11,,wstdecod.dll    ,1
11,,xmlprov.dll     ,1
11,,xmlprovi.dll    ,1
11,,zipfldr.dll     ,1

;;;;;;;
; ACM ;
;;;;;;;

11,,l3codeca.acm    ,1

;;;;;;
; AX ;
;;;;;;

11,,bdaplgin.ax     ,1
11,,ipsink.ax       ,1
11,,ksproxy.ax      ,1
11,,kswdmcap.ax     ,1
11,,mpg2data.ax     ,1
11,,mpg2splt.ax     ,1
11,,mpg4ds32.ax     ,1
11,,msadds32.ax     ,1
11,,msdvbnp.ax      ,1
11,,msscds32.ax     ,1
11,,psisrndr.ax     ,1
11,,vbicodec.ax     ,1
11,,vbisurf.ax      ,1
11,,vidcap.ax       ,1
11,,wmv8ds32.ax     ,1
11,,wmvds32.ax      ,1
11,,wstpager.ax     ,1
11,,wstrendr.ax     ,1

;;;;;;;
; OCX ;
;;;;;;;

11,,asctrls.ocx     ,1
11,,flash.ocx       ,1
11,,hhctrl.ocx      ,1
11,,msdxm.ocx       ,1
11,,msscript.ocx    ,1
11,,proctexe.ocx    ,1
11,,sysmon.ocx      ,1
11,,tdc.ocx         ,1
11,,wmp.ocx         ,1
11,,wshom.ocx       ,1
"""

    _inf_fd, _inf_path = tempfile.mkstemp(suffix=".inf", dir=W_TEMP)
    os.write(_inf_fd, _inf_data)
    os.close(_inf_fd)
    w_rundll32(_inf_path)

#-------------------------------------------------------------------------------
# .NET Framework 2.0
#-------------------------------------------------------------------------------
def load_dotnetfx20():
    print "Starting .NET Framework 2.0 setup..."

    dotnetfx20 = "/usr/local/src/NXWine/sources/nativedlls/dotnetfx20/NetFx20SP2_x86.exe"
    dotnetfx40 = "/usr/local/src/NXWine/sources/nativedlls/dotnetfx40/dotNetFx40_Client_x86_x64.exe"

    w_regedit_stdin("""\
[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
"mscoree"="native"
""")
    call([WINELOADER, dotnetfx20, "/passive"])
    call([WINELOADER, dotnetfx40, "/passive"])
#-------------------------------------------------------------------------------
# Visual Basic Runtime
#-------------------------------------------------------------------------------
def load_vbrun():
    print "Starting Visual Basic runtime setup..."

    vbrun6sp6 = os.path.join(prefix, "share/wine/vbrun6sp6/vbrun60sp6.exe")

    os.remove(os.path.join(W_SYSTEM32, "comcat.dll"))
    os.remove(os.path.join(W_SYSTEM32, "oleaut32.dll"))
    os.remove(os.path.join(W_SYSTEM32, "olepro32.dll"))
    os.remove(os.path.join(W_SYSTEM32, "stdole2.tlb"))

    w_regedit_stdin("""\
[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
"comcat.dll"    ="native"
"oleaut32.dll"  ="native"
"olepro32.dll"  ="native"
"stdole2.tlb"   ="native"
""")

    call([WINELOADER, vbrun6sp6, "/Q"])

#-------------------------------------------------------------------------------
# Visual C++ Runtime
#-------------------------------------------------------------------------------
def load_vcrun():
    print "Starting Visual C++ runtime setup..."
    
    inf       = os.path.join(prefix, "share/wine/vcredist.inf")
    vcrun2005 = os.path.join(prefix, "share/wine/vcrun2005/vcredist_x86.exe")
    vcrun2008 = os.path.join(prefix, "share/wine/vcrun2008sp1/vcredist_x86.exe")
    vcrun2010 = os.path.join(prefix, "share/wine/vcrun2010sp1/vcredist_x86.exe")

    w_rundll32(inf)
    w_try(vcrun2005, '/q')
    w_try(vcrun2008, '/q')
    w_try(vcrun2010, '/q')
    w_try("wineboot.exe", "-r")

#-------------------------------------------------------------------------------
# DirectX 9.0c
#-------------------------------------------------------------------------------
def load_dx9():
    print "Starting DirectX 9 setup..."
    
    inf         = os.path.join(prefix, "share/wine/dxredist.inf")
    dx9feb2010  = os.path.join(prefix, "share/wine/directx9/feb2010/dxsetup.exe")
    dx9jun2010  = os.path.join(prefix, "share/wine/directx9/jun2010/dxsetup.exe")

    w_rundll32(inf)
    os.environ["WINEDLLOVERRIDES"] = "setupapi=n"
    # note: dxsetup.exe will return the exit status 1
    call([WINELOADER, dx9feb2010, "/silent"])
    w_try("wineboot.exe", "-r")
    call([WINELOADER, dx9jun2010, "/silent"])
    w_try("wineboot.exe", "-r")
    del os.environ["WINEDLLOVERRIDES"]

    #-------------------#
    # Direct3D settings #
    #-------------------#
    import plistlib
    import re

    p = Popen(["system_profiler", "-xml", "SPDisplaysDataType"], stdout=PIPE).communicate()[0]
    d = plistlib.readPlistFromString(p)

    _value  = {
        "VideoPciDeviceID":                       d[0]["_items"][0]["spdisplays_device-id"],
        "VideoPciVendorID": re.search("(0x....)", d[0]["_items"][0]["spdisplays_vendor"]).group(1)
    }

    w_regedit_stdin("""\
[HKEY_CURRENT_USER\\Software\\Wine\\Direct3D]
"*VideoPciDeviceID"=dword:{VideoPciDeviceID}
"*VideoPciVendorID"=dword:{VideoPciVendorID}
""".format(**_value))

#-------------------------------------------------------------------------------

#if __name__ == "__main__":
# todo: init.inf
load_dotnetfx20()
load_vbrun()
w_rundll32(os.path.join(prefix, "share/wine/init.inf"))
load_dxnt()
load_core()
load_vcrun()
load_dx9()
shutil.rmtree(W_TEMP)
