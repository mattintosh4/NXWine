/*

Copyright (c) 2003-2004, AXE, Inc.  All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <string.h>
#include <dlfcn.h>
#ifndef DLOPEN_MODULE
#include "pdapi.h"
#define USE_PDAPI_H
#endif /* !defined(DLOPEN_MODULE) */
#include "opvp_common.h"
#include "opvp_driver.h"
#include "opvp_rpc_server.h"
#include "opvp_rpc_core.h"
#include "opvp_rpc_reqno.h"


/* Pointer to the real OpenPrinter */
static (*xOpenPrinter)(int,char*,int*,OPVP_api_procs**);
static int *xErrorno;

/* driver library handle */
static void *xHandle;


#define OPVP_BUFF_SIZE 1024

typedef int (*Stubfunp)(void *ap, int seqNo);

/* global variables */

/* private variables */

static OPVP_api_procs *apiEntry;

/* server stab function table */
static  Stubfunp sstubs[] = {
    SStubOpenPrinter,
    SStubClosePrinter,
    SStubStartJob,
    SStubEndJob,
    SStubStartDoc,
    SStubEndDoc,
    SStubStartPage,
    SStubEndPage,
#if (_PDAPI_VERSION_MAJOR_ > 0 || _PDAPI_VERSION_MINOR_ >= 2)
    SStubQueryDeviceCapability,
    SStubQueryDeviceInfo,
#endif
    SStubResetCTM,
    SStubSetCTM,
    SStubGetCTM,
    SStubInitGS,
    SStubSaveGS,
    SStubRestoreGS,
    SStubQueryColorSpace,
    SStubSetColorSpace,
    SStubGetColorSpace,
    SStubQueryROP,
    SStubSetROP,
    SStubGetROP,
    SStubSetFillMode,
    SStubGetFillMode,
    SStubSetAlphaConstant,
    SStubGetAlphaConstant,
    SStubSetLineWidth,
    SStubGetLineWidth,
    SStubSetLineDash,
    SStubGetLineDash,
    SStubSetLineDashOffset,
    SStubGetLineDashOffset,
    SStubSetLineStyle,
    SStubGetLineStyle,
    SStubSetLineCap,
    SStubGetLineCap,
    SStubSetLineJoin,
    SStubGetLineJoin,
    SStubSetMiterLimit,
    SStubGetMiterLimit,
    SStubSetPaintMode,
    SStubGetPaintMode,
    SStubSetStrokeColor,
    SStubSetFillColor,
    SStubSetBgColor,
    SStubNewPath,
    SStubEndPath,
    SStubStrokePath,
    SStubFillPath,
    SStubStrokeFillPath,
    SStubSetClipPath,
#if (_PDAPI_VERSION_MAJOR_ > 0 || _PDAPI_VERSION_MINOR_ >= 2)
    SStubResetClipPath,
#endif
    SStubSetCurrentPoint,
    SStubLinePath,
    SStubPolygonPath,
    SStubRectanglePath,
    SStubRoundRectanglePath,
    SStubBezierPath,
    SStubArcPath,
    SStubDrawBitmapText,
    SStubDrawImage,
    SStubStartDrawImage,
    SStubTransferDrawImage,
    SStubEndDrawImage,
    SStubStartScanline,
    SStubScanline,
    SStubEndScanline,
    SStubStartRaster,
    SStubTransferRasterData,
    SStubSkipRaster,
    SStubEndRaster,
    SStubStartStream,
    SStubTransferStreamData,
    SStubEndStream,
};

/* communication pipe */
/* -1 : not specified */
static int inPipe = -1;
static int outPipe = -1;

static int oprpc_sendReady(void *ap)
{
    if (oprpc_putPktStart(ap,-1,RPCNO_READY) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * ------------------------------------------------------------------------
 * Creating and Managing Print Contexts
 * ------------------------------------------------------------------------
 */

/*
 * OpenPrinter
 */
int SStubOpenPrinter(void *ap, int seqNo)
{
    int outputFD;
    char *printerModel;
    int nApiEntry;
    int i;
    typedef int (*Funp)();
    Funp *p;
    char *apiFlags;
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&outputFD,sizeof(outputFD)) < 0) {
	return -1;
    }
    if (oprpc_getStr(ap,&printerModel) < 0) {
	return -1;
    }
    /* call real proc */
    if ((printerContext = xOpenPrinter(outputFD,
         printerModel,&nApiEntry,&apiEntry)) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_OPENPRINTER) < 0) {
	    return -1;
	}
	return 0;
    }
    /* check apiEntry */
    p = (Funp *)apiEntry;
    if ((apiFlags = alloca(nApiEntry)) == NULL) {
	return -1;
    }
    /* create apiFlags */
    for (i = 0;i < nApiEntry;i++) {
	apiFlags[i] = (p[i] != NULL);
    }

    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_OPENPRINTER) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&nApiEntry,sizeof(nApiEntry)) < 0) {
	return -1;
    }
    if (oprpc_putPktPointer(ap,apiFlags,nApiEntry) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * ClosePrinter
 */
static int SStubClosePrinter(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->ClosePrinter(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno, RPCNO_CLOSEPRINTER) < 0) {
	    return -1;
	}
	return 0;
    }

    /* send response */
    /* no return value but synchronous function */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_CLOSEPRINTER) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * ------------------------------------------------------------------------
 * Job Control Operations
 * ------------------------------------------------------------------------
 */

/*
 * StartJob
 */
static int SStubStartJob(void *ap, int seqNo)
{
    int printerContext;
    char *jobInfo;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getStr(ap,&jobInfo) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StartJob(printerContext,jobInfo) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno, RPCNO_STARTJOB) < 0) {
	    return -1;
	}
	return 0;
    }

    return 0;
}

/*
 * EndJob
 */
static int SStubEndJob(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->EndJob(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ENDJOB) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    /* no return value but synchronous function */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_ENDJOB) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * StartDoc
 */
static int SStubStartDoc(void *ap, int seqNo)
{
    int printerContext;
    char *docInfo;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getStr(ap,&docInfo) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StartDoc(printerContext,docInfo) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_STARTDOC) < 0) {
	    return -1;
	}
	return 0;
    }

    return 0;
}

/*
 * EndDoc
 */
static int SStubEndDoc(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->EndDoc(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ENDDOC) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    /* no return value but synchronous function */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_ENDDOC) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * StartPage
 */
static int SStubStartPage(void *ap, int seqNo)
{
    int printerContext;
    char *pageInfo;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getStr(ap,&pageInfo) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StartPage(printerContext,pageInfo) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_STARTPAGE) < 0) {
	    return -1;
	}
	return 0;
    }

    return 0;
}

/*
 * EndPage
 */
static int SStubEndPage(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->EndPage(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ENDPAGE) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    /* no return value but synchronous function */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_ENDPAGE) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

#if (_PDAPI_VERSION_MAJOR_ > 0 || _PDAPI_VERSION_MINOR_ >= 2)
static int SStubQueryDeviceCapability(void *ap, int seqNo)
{
    int printerContext;
    int queryflag;
    int buflen;
    int f;
    char *infoBuf;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&queryflag,sizeof(queryflag)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&buflen,sizeof(buflen)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&f,sizeof(f)) < 0) {
	return -1;
    }
    if (buflen <= 0) f = 1;
    if (f) {
	if ((infoBuf = alloca(buflen)) == NULL) {
	    return -1;
	}
    }
    /* call real proc */
    if (apiEntry->QueryDeviceCapability(printerContext, queryflag,
        buflen, f ? NULL : infoBuf)) {
	if (oprpc_putError(ap,seqNo,*xErrorno,
	      RPCNO_QUERYDEVICECAPABILITY) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_QUERYDEVICECAPABILITY) < 0) {
	return -1;
    }
    if (oprpc_putStr(ap,infoBuf) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
}

static int SStubQueryDeviceInfo(void *ap, int seqNo)
{
    int printerContext;
    int queryflag;
    int buflen;
    int f;
    char *infoBuf;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&queryflag,sizeof(queryflag)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&buflen,sizeof(buflen)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&f,sizeof(f)) < 0) {
	return -1;
    }
    if (buflen <= 0) f = 1;
    if (f) {
	if ((infoBuf = alloca(buflen)) == NULL) {
	    return -1;
	}
    }
    /* call real proc */
    if (apiEntry->QueryDeviceInfo(printerContext, queryflag,
        buflen, f ? NULL : infoBuf)) {
	if (oprpc_putError(ap,seqNo,*xErrorno,
	      RPCNO_QUERYDEVICEINFO) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_QUERYDEVICEINFO) < 0) {
	return -1;
    }
    if (oprpc_putStr(ap,infoBuf) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
    return 0;
}
#endif

/*
 * ------------------------------------------------------------------------
 * Graphics State Object Operations
 * ------------------------------------------------------------------------
 */

/*
 * ResetCTM
 */
static int SStubResetCTM(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->ResetCTM(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_RESETCTM) < 0) {
	    return -1;
	}
	return 0;
    }

    return 0;
}

/*
 * SetCTM
 */
static int SStubSetCTM(void *ap, int seqNo)
{
    int printerContext;
    OPVP_CTM *pCTM;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&pCTM,sizeof(OPVP_CTM)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetCTM(printerContext,pCTM) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETCTM) < 0) {
	    return -1;
	}
	return 0;
    }

    return 0;
}

/*
 * GetCTM
 */
static int SStubGetCTM(void *ap, int seqNo)
{
    int printerContext;
    OPVP_CTM ctm;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetCTM(printerContext,&ctm) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETCTM) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETCTM) < 0) {
	return -1;
    }
    if (oprpc_putPktPointer(ap,&ctm,sizeof(OPVP_CTM)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
}

/*
 * InitGS
 */
static int SStubInitGS(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->InitGS(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_INITGS) < 0) {
	    return -1;
	}
	return 0;
    }

    return 0;
}

/*
 * SaveGS
 */
static int SStubSaveGS(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SaveGS(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SAVEGS) < 0) {
	    return -1;
	}
	return 0;
    }

    return 0;
}

/*
 * RestoreGS
 */
static int SStubRestoreGS(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->RestoreGS(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_RESTOREGS) < 0) {
	    return -1;
	}
	return 0;
    }

    return 0;
}

/*
 * QueryColorSpace
 */
static int SStubQueryColorSpace(void *ap, int seqNo)
{
    int printerContext;
    int num,rnum;
    OPVP_ColorSpace *pcspace;
    int f;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&num,sizeof(num)) < 0) {
	return -1;
    }
    f = num > 0;
    if ((pcspace = (OPVP_ColorSpace *)alloca(num*sizeof(OPVP_ColorSpace)))
         == NULL) {
	return -1;
    }
    rnum = num;
    /* call real proc */
    if (apiEntry->QueryColorSpace(printerContext,
       f ? pcspace : NULL,&rnum) < 0 && *xErrorno != OPVP_PARAMERROR) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_QUERYCOLORSPACE) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_QUERYCOLORSPACE) < 0) {
	return -1;
    }
    /* changed parameter order, because we need num before pcspace */
    if (oprpc_putPkt(ap,(char *)&rnum,sizeof(rnum)) < 0) {
	return -1;
    }
    if (rnum <= num && f) {
	if (oprpc_putPktPointer(ap,pcspace,rnum*sizeof(OPVP_ColorSpace)) < 0) {
	    return -1;
	}
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
}

/*
 * SetColorSpace
 */
static int SStubSetColorSpace(void *ap, int seqNo)
{
    int printerContext;
    OPVP_ColorSpace cspace;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&cspace,sizeof(cspace)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetColorSpace(printerContext,cspace) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETCOLORSPACE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetColorSpace
 */
static int SStubGetColorSpace(void *ap, int seqNo)
{
    int printerContext;
    OPVP_ColorSpace cspace;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetColorSpace(printerContext,&cspace) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETCOLORSPACE) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETCOLORSPACE) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&cspace,sizeof(cspace)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
}

/*
 * QueryROP
 */
static int SStubQueryROP(void *ap, int seqNo)
{
    int printerContext;
    int num;
    int *prop;
    int f;
    int rnum;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&num,sizeof(num)) < 0) {
	return -1;
    }
    f = num > 0;
    if (f && (prop = (int *)alloca(num*sizeof(int))) == NULL) {
	return -1;
    }
    /* call real proc */
    rnum = num;
    if (apiEntry->QueryROP(printerContext,&rnum, f ? prop : NULL) < 0
        && *xErrorno != OPVP_PARAMERROR) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_QUERYROP) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_QUERYROP) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&rnum,sizeof(rnum)) < 0) {
	return -1;
    }
    if (rnum <= num && f) {
	if (oprpc_putPktPointer(ap,prop,num*sizeof(int)) < 0) {
	    return -1;
	}
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
}

/*
 * SetROP
 */
static int SStubSetROP(void *ap, int seqNo)
{
    int printerContext;
    int rop;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&rop,sizeof(rop)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetROP(printerContext,rop) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETROP) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetROP
 */
static int SStubGetROP(void *ap, int seqNo)
{
    int printerContext;
    int rop;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetROP(printerContext,&rop) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETROP) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETROP) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&rop,sizeof(rop)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
}

/*
 * SetFillMode
 */
static int SStubSetFillMode(void *ap, int seqNo)
{
    int printerContext;
    OPVP_FillMode fillmode;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&fillmode,sizeof(fillmode)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetFillMode(printerContext,fillmode) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETFILLMODE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetFillMode
 */
static int SStubGetFillMode(void *ap, int seqNo)
{
    int printerContext;
    OPVP_FillMode fillmode;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetFillMode(printerContext,&fillmode) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETFILLMODE) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETFILLMODE) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&fillmode,sizeof(fillmode)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
}

/*
 * SetAlphaConstant
 */
static int SStubSetAlphaConstant(void *ap, int seqNo)
{
    int printerContext;
    float alpha;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&alpha,sizeof(alpha)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetAlphaConstant(printerContext,alpha) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETALPHACONSTANT) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetAlphaConstant
 */
static int SStubGetAlphaConstant(void *ap, int seqNo)
{
    int printerContext;
    float alpha;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetAlphaConstant(printerContext,&alpha) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETALPHACONSTANT) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETALPHACONSTANT) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&alpha,sizeof(alpha)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }

    return 0;
}

/*
 * SetLineWidth
 */
static int SStubSetLineWidth(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix width;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&width,sizeof(width)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetLineWidth(printerContext,width) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETLINEWIDTH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetLineWidth
 */
static int SStubGetLineWidth(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix width;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetLineWidth(printerContext,&width) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETLINEWIDTH) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETLINEWIDTH) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&width,sizeof(width)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * SetLineDash
 */
static int SStubSetLineDash(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix *pdash;
    int num;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* changed parameter order, because we need num before pdash */
    if (oprpc_getPkt(ap,(char *)&num,sizeof(num)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&pdash,num*sizeof(OPVP_Fix)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetLineDash(printerContext,pdash,num) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETLINEDASH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetLineDash
 */
static int SStubGetLineDash(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix *pdash;
    int num;
    int f;
    int rnum;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&num,sizeof(num)) < 0) {
	return -1;
    }
    f = num > 0;
    if (f && ((pdash = (OPVP_Fix *)alloca(num*sizeof(OPVP_Fix))) == NULL)) {
	return -1;
    }
    rnum = num;
    /* call real proc */
    if (apiEntry->GetLineDash(printerContext,f ? pdash : NULL,&rnum) < 0
        && *xErrorno != OPVP_PARAMERROR) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETLINEDASH) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETLINEDASH) < 0) {
	return -1;
    }
    /* changed parameter order, because we need num before pdash */
    if (oprpc_putPkt(ap,(char *)&rnum,sizeof(rnum)) < 0) {
	return -1;
    }
    if (f && rnum <= num) {
	if (oprpc_putPktPointer(ap,pdash,rnum*sizeof(OPVP_Fix)) < 0) {
	    return -1;
	}
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * SetLineDashOffset
 */
static int SStubSetLineDashOffset(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix offset;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&offset,sizeof(offset)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetLineDashOffset(printerContext,offset) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETLINEDASHOFFSET) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetLineDashOffset
 */
static int SStubGetLineDashOffset(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix offset;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetLineDashOffset(printerContext,&offset) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETLINEDASHOFFSET) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETLINEDASHOFFSET) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&offset,sizeof(offset)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * SetLineStyle
 */
static int SStubSetLineStyle(void *ap, int seqNo)
{
    int printerContext;
    OPVP_LineStyle linestyle;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&linestyle,sizeof(linestyle)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetLineStyle(printerContext,linestyle) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETLINESTYLE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetLineStyle
 */
static int SStubGetLineStyle(void *ap, int seqNo)
{
    int printerContext;
    OPVP_LineStyle linestyle;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetLineStyle(printerContext,&linestyle) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETLINESTYLE) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETLINESTYLE) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&linestyle,sizeof(linestyle)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * SetLineCap
 */
static int SStubSetLineCap(void *ap, int seqNo)
{
    int printerContext;
    OPVP_LineCap linecap;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&linecap,sizeof(linecap)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetLineCap(printerContext,linecap) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETLINECAP) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetLineCap
 */
static int SStubGetLineCap(void *ap, int seqNo)
{
    int printerContext;
    OPVP_LineCap linecap;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetLineCap(printerContext,&linecap) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETLINECAP) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETLINECAP) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&linecap,sizeof(linecap)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * SetLineJoin
 */
static int SStubSetLineJoin(void *ap, int seqNo)
{
    int printerContext;
    OPVP_LineJoin linejoin;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&linejoin,sizeof(linejoin)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetLineJoin(printerContext,linejoin) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETLINEJOIN) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetLineJoin
 */
static int SStubGetLineJoin(void *ap, int seqNo)
{
    int printerContext;
    OPVP_LineJoin linejoin;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetLineJoin(printerContext,&linejoin) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETLINEJOIN) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETLINEJOIN) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&linejoin,sizeof(linejoin)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * SetMiterLimit
 */
static int SStubSetMiterLimit(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix miterlimit;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&miterlimit,sizeof(miterlimit)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetMiterLimit(printerContext,miterlimit) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETMITERLIMIT) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetMiterLimit
 */
static int SStubGetMiterLimit(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix miterlimit;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetMiterLimit(printerContext,&miterlimit) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETMITERLIMIT) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETMITERLIMIT) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&miterlimit,sizeof(miterlimit)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * SetPaintMode
 */
static int SStubSetPaintMode(void *ap, int seqNo)
{
    int printerContext;
    OPVP_PaintMode paintmode;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&paintmode,sizeof(paintmode)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetPaintMode(printerContext,paintmode) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETPAINTMODE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * GetPaintMode
 */
static int SStubGetPaintMode(void *ap, int seqNo)
{
    int printerContext;
    OPVP_PaintMode paintmode;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->GetPaintMode(printerContext,&paintmode) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_GETPAINTMODE) < 0) {
	    return -1;
	}
	return 0;
    }
    /* send response */
    if (oprpc_putPktStart(ap,seqNo,RPCNO_GETPAINTMODE) < 0) {
	return -1;
    }
    if (oprpc_putPkt(ap,(char *)&paintmode,sizeof(paintmode)) < 0) {
	return -1;
    }
    if (oprpc_putPktEnd(ap) < 0) {
	return -1;
    }
    return 0;
}

/*
 * get Brush Data
 */
static int oprpc_getBrushData(void *ap, OPVP_Brush *pbrush)
{
    int f;
#if (_PDAPI_VERSION_MAJOR_ == 0 && _PDAPI_VERSION_MINOR_ < 2)
    OPVP_BrushData *pbd;
#endif

    if (oprpc_getPkt(ap,(char *)&f,
         sizeof(int)) < 0) {
	return -1;
    }
    if (f) {
	pbrush->pbrush = NULL;
	return 0;
    }
#if (_PDAPI_VERSION_MAJOR_ == 0 && _PDAPI_VERSION_MINOR_ < 2)
    pbd = pbrush->pbrush;
    if (oprpc_getPkt(ap,(char *)&(pbd->type),
         sizeof(OPVP_BrushDataType)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&(pbd->width),
         sizeof(int)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&(pbd->height),
         sizeof(int)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&(pbd->pitch),
         sizeof(int)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,&(pbd->data),pbd->pitch*pbd->height) < 0) {
	return -1;
    }
#else
    if (oprpc_getPktPointer(ap,(void **)&(pbrush->pbrush),-1) < 0) {
	return -1;
    }
#endif
    return 0;
}

/*
 * get Brush
 */
static int oprpc_getBrush(void *ap, OPVP_Brush *pbrush)
{
    if (oprpc_getPkt(ap,(char *)&(pbrush->colorSpace),
         sizeof(OPVP_ColorSpace)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&(pbrush->color),
         sizeof(int)*4) < 0) {
	return -1;
    }
#if (_PDAPI_VERSION_MAJOR_ == 0 && _PDAPI_VERSION_MINOR_ < 2)
    if (oprpc_getBrushData(ap,pbrush) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&(pbrush->xorg),
         sizeof(int)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&(pbrush->yorg),
         sizeof(int)) < 0) {
	return -1;
    }
#else
    if (oprpc_getPkt(ap,(char *)&(pbrush->xorg),
         sizeof(int)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&(pbrush->yorg),
         sizeof(int)) < 0) {
	return -1;
    }
    if (oprpc_getBrushData(ap,pbrush) < 0) {
	return -1;
    }
#endif
    return 0;
}

/*
 * SetStrokeColor
 */
static int SStubSetStrokeColor(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Brush brush;
#if (_PDAPI_VERSION_MAJOR_ == 0 && _PDAPI_VERSION_MINOR_ < 2)
    OPVP_BrushData bd;

    brush.pbrush = &bd;
#endif
    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getBrush(ap,&brush) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetStrokeColor(printerContext,&brush) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETSTROKECOLOR) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * SetFillColor
 */
static int SStubSetFillColor(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Brush brush;
#if (_PDAPI_VERSION_MAJOR_ == 0 && _PDAPI_VERSION_MINOR_ < 2)
    OPVP_BrushData bd;

    brush.pbrush = &bd;
#endif
    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getBrush(ap,&brush) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetFillColor(printerContext,&brush) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETFILLCOLOR) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * SetBgColor
 */
static int SStubSetBgColor(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Brush brush;
#if (_PDAPI_VERSION_MAJOR_ == 0 && _PDAPI_VERSION_MINOR_ < 2)
    OPVP_BrushData bd;

    brush.pbrush = &bd;
#endif
    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getBrush(ap,&brush) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetBgColor(printerContext,&brush) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETBGCOLOR) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * ------------------------------------------------------------------------
 * Path Operations
 * ------------------------------------------------------------------------
 */

/*
 * NewPath
 */
static int SStubNewPath(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->NewPath(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_NEWPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * EndPath
 */
static int SStubEndPath(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->EndPath(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ENDPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * StrokePath
 */
static int SStubStrokePath(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StrokePath(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_STROKEPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * FillPath
 */
static int SStubFillPath(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->FillPath(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_FILLPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * StrokeFillPath
 */
static int SStubStrokeFillPath(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StrokeFillPath(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_STROKEFILLPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * SetClipPath
 */
static int SStubSetClipPath(void *ap, int seqNo)
{
    int printerContext;
    OPVP_ClipRule clipRule;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&clipRule,sizeof(clipRule)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetClipPath(printerContext,clipRule) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETCLIPPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

#if (_PDAPI_VERSION_MAJOR_ > 0 || _PDAPI_VERSION_MINOR_ >= 2)
/*
 * ResetClipPath
 */
static int SStubResetClipPath(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->ResetClipPath(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_RESETCLIPPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}
#endif

/*
 * SetCurrentPoint
 */
static int SStubSetCurrentPoint(void *ap, int seqNo)
{
    int printerContext;
    OPVP_Fix x;
    OPVP_Fix y;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&x,sizeof(x)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&y,sizeof(y)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SetCurrentPoint(printerContext,x,y) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SETCURRENTPOINT) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * LinePath
 */
static int SStubLinePath(void *ap, int seqNo)
{
    int printerContext;
    int flag;
    int npoints;
    OPVP_Point *points;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&flag,sizeof(flag)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&npoints,sizeof(npoints)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&points,
         npoints*sizeof(OPVP_Point)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->LinePath(printerContext,flag,npoints,points) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_LINEPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * PolygonPath
 */
static int SStubPolygonPath(void *ap, int seqNo)
{
    int printerContext;
    int npolygons;
    int *nvertexes;
    OPVP_Point *points;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&npolygons,sizeof(npolygons)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&nvertexes,
         npolygons*sizeof(int)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&points,
        -1 /* no size check, no index advance */) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->PolygonPath(printerContext,npolygons,nvertexes,points) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_POLYGONPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * RectanglePath
 */
static int SStubRectanglePath(void *ap, int seqNo)
{
    int printerContext;
    int nrectangles;
    OPVP_Rectangle *rectangles;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&nrectangles,sizeof(nrectangles)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&rectangles,
        nrectangles*sizeof(OPVP_Rectangle)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->RectanglePath(printerContext,nrectangles,rectangles) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_RECTANGLEPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * RoundRectanglePath
 */
static int SStubRoundRectanglePath(void *ap, int seqNo)
{
    int printerContext;
    int nrectangles;
    OPVP_RoundRectangle *rectangles;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&nrectangles,sizeof(nrectangles)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&rectangles,
        nrectangles*sizeof(OPVP_RoundRectangle)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->RoundRectanglePath(printerContext,
        nrectangles,rectangles) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ROUNDRECTANGLEPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * BezierPath
 */
static int SStubBezierPath(void *ap, int seqNo)
#if (_PDAPI_VERSION_MAJOR_ == 0 && _PDAPI_VERSION_MINOR_ < 2)
{
    int printerContext;
    int *npoints;
    OPVP_Point *points;
    int n;
    int f;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if ((f = oprpc_getPktPointer(ap,(void **)&npoints,
        -1 /* no size check, no index advance */)) < 0) {
	return -1;
    }
    if (f == 0) {
	/* find end */
	for (n = 0;npoints[n] != 0;n++);
	/* advance packet index */
	if (oprpc_addInPktIndex(ap,(n+1)*sizeof(int)) < 0) {
	    return -1;
	}
    }

    if (oprpc_getPktPointer(ap,(void **)&points,
        -1 /* no size check, no index advance */) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->BezierPath(printerContext,
        npoints,points) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_BEZIERPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}
#else
{
    int printerContext;
    int npoints;
    OPVP_Point *points;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&npoints,sizeof(npoints)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&points,
         npoints*sizeof(OPVP_Point)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->BezierPath(printerContext,npoints,points) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_BEZIERPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}
#endif

/*
 * ArcPath
 */
static int SStubArcPath(void *ap, int seqNo)
{
    int printerContext;
    int kind, dir;
    OPVP_Fix bbx0,bby0,bbx1,bby1;
    OPVP_Fix x0,y0;
    OPVP_Fix x1,y1;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&kind,sizeof(kind)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&dir,sizeof(dir)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&bbx0,sizeof(bbx0)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&bby0,sizeof(bby0)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&bbx1,sizeof(bbx1)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&bby1,sizeof(bby1)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&x0,sizeof(x0)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&y0,sizeof(y0)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&x1,sizeof(x1)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&y1,sizeof(y1)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->ArcPath(printerContext,kind,dir,bbx0,bby0,bbx1,bby1,
        x0,y0,x1,y1) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ARCPATH) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * ------------------------------------------------------------------------
 * Text Operations
 * ------------------------------------------------------------------------
 */

/*
 * DrawBitmapText
 */
static int SStubDrawBitmapText(void *ap, int seqNo)
{
    int printerContext;
    int width;
    int height;
    int pitch;
    void *fontdata;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&width,sizeof(width)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&height,sizeof(height)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&pitch,sizeof(pitch)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,&fontdata,pitch/8*height) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->DrawBitmapText(printerContext,width,height,pitch,
         fontdata) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_DRAWBITMAPTEXT) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * ------------------------------------------------------------------------
 * Bitmap Image Operations
 * ------------------------------------------------------------------------
 */

/*
 * DrawImage
 */
static int SStubDrawImage(void *ap, int seqNo)
{
    int printerContext;
    int sourceWidth;
    int sourceHeight;
    int colorSpace;
    OPVP_ImageFormat imageFormat;
    OPVP_Rectangle destinationSize;
    int count;
    void *imageData;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&sourceWidth,sizeof(sourceWidth)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&sourceHeight,sizeof(sourceHeight)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&colorSpace,sizeof(colorSpace)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&imageFormat,sizeof(imageFormat)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&destinationSize,sizeof(destinationSize)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&count,sizeof(count)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,&imageData,count) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->DrawImage(printerContext,sourceWidth,
        sourceHeight,colorSpace,imageFormat,destinationSize,
	count,imageData) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_DRAWIMAGE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * StartDrawImage
 */
static int SStubStartDrawImage(void *ap, int seqNo)
{
    int printerContext;
    int sourceWidth;
    int sourceHeight;
    int colorSpace;
    OPVP_ImageFormat imageFormat;
    OPVP_Rectangle destinationSize;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&sourceWidth,sizeof(sourceWidth)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&sourceHeight,sizeof(sourceHeight)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&colorSpace,sizeof(colorSpace)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&imageFormat,sizeof(imageFormat)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&destinationSize,sizeof(destinationSize)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StartDrawImage(printerContext,sourceWidth,
        sourceHeight,colorSpace,imageFormat,destinationSize) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_STARTDRAWIMAGE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * TransferDrawImage
 */
static int SStubTransferDrawImage(void *ap, int seqNo)
{
    int printerContext;
    int count;
    void *imageData;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&count,sizeof(count)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,&imageData,count) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->TransferDrawImage(printerContext,count,imageData) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_TRANSFERDRAWIMAGE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * EndDrawImage
 */
static int SStubEndDrawImage(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->EndDrawImage(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ENDDRAWIMAGE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * ------------------------------------------------------------------------
 * Scan Line Operations
 * ------------------------------------------------------------------------
 */

/*
 * StartScanline
 */
static int SStubStartScanline(void *ap, int seqNo)
{
    int printerContext;
    int yposition;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&yposition,sizeof(yposition)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StartScanline(printerContext,yposition) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_STARTSCANLINE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * Scanline
 */
static int SStubScanline(void *ap, int seqNo)
{
    int printerContext;
    int nscanpairs;
    int *scanpairs;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&nscanpairs,sizeof(nscanpairs)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,(void **)&scanpairs,
       nscanpairs*2*sizeof(int)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->Scanline(printerContext,nscanpairs,scanpairs) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SCANLINE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * EndScanline
 */
static int SStubEndScanline(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->EndScanline(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ENDSCANLINE) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * ------------------------------------------------------------------------
 * Raster Image Operations
 * ------------------------------------------------------------------------
 */

/*
 * StartRaster
 */
static int SStubStartRaster(void *ap, int seqNo)
{
    int printerContext;
    int rasterWidth;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&rasterWidth,sizeof(rasterWidth)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StartRaster(printerContext,rasterWidth) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_STARTRASTER) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * TransferRasterData
 */
static int SStubTransferRasterData(void *ap, int seqNo)
{
    int printerContext;
    int count;
    void *data;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&count,sizeof(count)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,&data,count) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->TransferRasterData(printerContext,count,data) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_TRANSFERRASTERDATA) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * SkipRaster
 */
static int SStubSkipRaster(void *ap, int seqNo)
{
    int printerContext;
    int count;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&count,sizeof(count)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->SkipRaster(printerContext,count) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_SKIPRASTER) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * EndRaster
 */
static int SStubEndRaster(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->EndRaster(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ENDRASTER) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * ------------------------------------------------------------------------
 * Raster Image Operations
 * ------------------------------------------------------------------------
 */

/*
 * StartStream
 */
static int SStubStartStream(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->StartStream(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_STARTSTREAM) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * TransferStreamData
 */
static int SStubTransferStreamData(void *ap, int seqNo)
{
    int printerContext;
    int count;
    void *data;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    if (oprpc_getPkt(ap,(char *)&count,sizeof(count)) < 0) {
	return -1;
    }
    if (oprpc_getPktPointer(ap,&data,count) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->TransferStreamData(printerContext,count,data) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_TRANSFERSTREAMDATA) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

/*
 * EndStream
 */
static int SStubEndStream(void *ap, int seqNo)
{
    int printerContext;

    /* get parameter */
    if (oprpc_getPkt(ap,(char *)&printerContext,sizeof(printerContext)) < 0) {
	return -1;
    }
    /* call real proc */
    if (apiEntry->EndStream(printerContext) < 0) {
	if (oprpc_putError(ap,seqNo,*xErrorno,RPCNO_ENDSTREAM) < 0) {
	    return -1;
	}
	return 0;
    }
    return 0;
}

static char * opvp_alloc_string(char **destin, char *source)
{
    if (!destin) return NULL;

    if (*destin) {
	if (source) {
	    *destin = realloc(*destin, strlen(source)+1);
	} else {
	    free(*destin);
	    *destin = NULL;
	}
    } else {
	if (source) {
	    *destin = malloc(strlen(source)+1);
	}
    }
    if (*destin && source) {
	if (*destin != source) {
	    strcpy(*destin, source);
	}
    }

    return *destin;
}

static char ** opvp_gen_dynamic_lib_name(char *name)
{
    static char	*buff[5] = {NULL,NULL,NULL,NULL,NULL};
    char tbuff[OPVP_BUFF_SIZE];

    strcpy(tbuff, name);
    opvp_alloc_string(&(buff[0]), tbuff);
    strcat(tbuff, ".so");
    opvp_alloc_string(&(buff[1]), tbuff);
    strcpy(tbuff, name);
    strcat(tbuff, ".dll");
    opvp_alloc_string(&(buff[2]), tbuff);
    strcpy(tbuff, "lib");
    strcat(tbuff, name);
    strcat(tbuff, ".so");
    opvp_alloc_string(&(buff[3]), tbuff);
    buff[4] = NULL;

    return buff;
}

/*
 * load vector-driver
 */
static int opvp_load_vector_driver(char *name)
{
#ifndef DLOPEN_MODULE
	xOpenPrinter = (int(*)(int,char*,int*,OPVP_api_procs**))OpenPrinter;
	xErrorno = &errorno;
	return(0);
#else /* defined(DLOPEN_MODULE) */
    char **list = NULL;
    int	 i;
    void *h;

    list = opvp_gen_dynamic_lib_name(name);

    if (list) {
	i = 0;
	while (list[i]) {
	    if ((h = dlopen(list[i],RTLD_NOW))) {
		xOpenPrinter = dlsym(h,"OpenPrinter");
		xErrorno = dlsym(h,"errorno");
		if (xOpenPrinter && xErrorno) {
		    xHandle = h;
		    break;
		}
		xOpenPrinter = NULL;
		xErrorno = NULL;
	    }
	    i++;
	}
    }
    return xHandle ? 0 : -1;
#endif /* defined(DLOPEN_MODULE) */
}

/*
 * unload vector-driver
 */
static int opvp_unload_vector_driver(void)
{
#ifdef DLOPEN_MODULE
    if (xHandle) {
	dlclose(xHandle);
	xHandle = NULL;
	xOpenPrinter = NULL;
	xErrorno = NULL;
    }
#endif /* DLOPEN_MODULE */
    return 0;
}

/* print usage and exit */
static void usage(char *cmd)
{
    fprintf(stderr,"Usage:%s -i <inputFd> -o <outputFd> <drivername>\n",cmd);
    exit(2);
}

/* driver name */
static char *driverName = NULL;

/* parse arguments */
static void parseArgs(int argc, char **argv)
{
    int i;

    for (i = 1;i < argc;i++) {
	if (argv[i][0] == '-') {
	    switch (argv[i][1]) {
	    case 'i':
		if (++i >= argc) {
		    usage(argv[0]);
		}
		inPipe = atoi(argv[i]);
		break;
	    case 'o':
		if (++i >= argc) {
		    usage(argv[0]);
		}
		outPipe = atoi(argv[i]);
		break;
	    default:
		usage(argv[0]);
		break;
	    }
	} else {
	    driverName = argv[i];
	}
    }
    /* checking if  all needed arguments are specified */
    if (driverName == NULL
       || inPipe < 0
       || outPipe < 0) {
	usage(argv[0]);
    }
}

static int oprpc_mainLoop(void *ap)
{
    for(;;) {
	int reqNo;
	int reqSeqNo;

	if ((reqSeqNo = oprpc_getPktStart(ap)) < 0) {
	    return -1;
	}
	if (oprpc_getPkt(ap,(char *)&reqNo,sizeof(reqNo)) < 0) {
	    fprintf(stderr,"getPkt error\n");
	    return -1;
	}
	switch (reqNo) {
	case RPCNO_ECHO:
	case RPCNO_READY:
	default:
	    if (reqNo < 0 || reqNo > sizeof(sstubs)/sizeof(Stubfunp)) {
		fprintf(stderr,"Unknown request number\n");
		return -1;
	    }
	}
	if ((*(sstubs[reqNo]))(ap,reqSeqNo) < 0) {
	    return -1;
	}
	if (oprpc_getPktEnd(ap) < 0) {
	    return -1;
	}
    }
}

int main(int argc, char **argv)
{
    void *ap;

    parseArgs(argc, argv);
    if (opvp_load_vector_driver(driverName) != 0) {
	fprintf(stderr,"Can't load driver library:%s\n",driverName);
	exit(2);
    }
    if ((ap = oprpc_init(inPipe,outPipe)) == NULL) {
	fprintf(stderr,"Can't initialize RPC\n");
	exit(2);
    }
    if (oprpc_sendReady(ap) < 0) {
	fprintf(stderr,"Can't send RPC Ready\n");
	exit(2);
    }
    if (oprpc_flush(ap) < 0) {
	fprintf(stderr,"Can't send RPC Ready\n");
	exit(2);
    }
    if (oprpc_mainLoop(ap) < 0) {
	exit(2);
    }
    return 0;
}

