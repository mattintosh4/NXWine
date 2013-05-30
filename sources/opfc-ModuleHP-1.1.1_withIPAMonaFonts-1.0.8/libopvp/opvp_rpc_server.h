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

#ifndef _OPVP_RPC_SERVER_H_
#define _OPVP_RPC_SERVER_H_

#include "opvp_common.h"

/* private function prototyoes */
/* API Client Stub functions */
static int SStubOpenPrinter(void *ap, int seqNo);
static int SStubClosePrinter(void *ap, int seqNo);
static int SStubStartJob(void *ap, int seqNo);
static int SStubEndJob(void *ap, int seqNo);
static int SStubStartDoc(void *ap, int seqNo);
static int SStubEndDoc(void *ap, int seqNo);
static int SStubStartPage(void *ap, int seqNo);
static int SStubEndPage(void *ap, int seqNo);
static int SStubResetCTM(void *ap, int seqNo);
static int SStubSetCTM(void *ap, int seqNo);
static int SStubGetCTM(void *ap, int seqNo);
static int SStubInitGS(void *ap, int seqNo);
static int SStubSaveGS(void *ap, int seqNo);
static int SStubRestoreGS(void *ap, int seqNo);
static int SStubQueryColorSpace(void *ap, int seqNo);
static int SStubSetColorSpace(void *ap, int seqNo);
static int SStubGetColorSpace(void *ap, int seqNo);
static int SStubQueryROP(void *ap, int seqNo);
static int SStubSetROP(void *ap, int seqNo);
static int SStubGetROP(void *ap, int seqNo);
static int SStubSetFillMode(void *ap, int seqNo);
static int SStubGetFillMode(void *ap, int seqNo);
static int SStubSetAlphaConstant(void *ap, int seqNo);
static int SStubGetAlphaConstant(void *ap, int seqNo);
static int SStubSetLineWidth(void *ap, int seqNo);
static int SStubGetLineWidth(void *ap, int seqNo);
static int SStubSetLineDash(void *ap, int seqNo);
static int SStubGetLineDash(void *ap, int seqNo);
static int SStubSetLineDashOffset(void *ap, int seqNo);
static int SStubGetLineDashOffset(void *ap, int seqNo);
static int SStubSetLineStyle(void *ap, int seqNo);
static int SStubGetLineStyle(void *ap, int seqNo);
static int SStubSetLineCap(void *ap, int seqNo);
static int SStubGetLineCap(void *ap, int seqNo);
static int SStubSetLineJoin(void *ap, int seqNo);
static int SStubGetLineJoin(void *ap, int seqNo);
static int SStubSetMiterLimit(void *ap, int seqNo);
static int SStubGetMiterLimit(void *ap, int seqNo);
static int SStubSetPaintMode(void *ap, int seqNo);
static int SStubGetPaintMode(void *ap, int seqNo);
static int SStubSetStrokeColor(void *ap, int seqNo);
static int SStubSetFillColor(void *ap, int seqNo);
static int SStubSetBgColor(void *ap, int seqNo);
static int SStubNewPath(void *ap, int seqNo);
static int SStubEndPath(void *ap, int seqNo);
static int SStubStrokePath(void *ap, int seqNo);
static int SStubFillPath(void *ap, int seqNo);
static int SStubStrokeFillPath(void *ap, int seqNo);
static int SStubSetClipPath(void *ap, int seqNo);
static int SStubSetCurrentPoint(void *ap, int seqNo);
static int SStubLinePath(void *ap, int seqNo);
static int SStubPolygonPath(void *ap, int seqNo);
static int SStubRectanglePath(void *ap, int seqNo);
static int SStubRoundRectanglePath(void *ap, int seqNo);
static int SStubBezierPath(void *ap, int seqNo);
static int SStubArcPath(void *ap, int seqNo);
static int SStubDrawBitmapText(void *ap, int seqNo);
static int SStubDrawImage(void *ap, int seqNo);
static int SStubStartDrawImage(void *ap, int seqNo);
static int SStubTransferDrawImage(void *ap, int seqNo);
static int SStubEndDrawImage(void *ap, int seqNo);
static int SStubStartScanline(void *ap, int seqNo);
static int SStubScanline(void *ap, int seqNo);
static int SStubEndScanline(void *ap, int seqNo);
static int SStubStartRaster(void *ap, int seqNo);
static int SStubTransferRasterData(void *ap, int seqNo);
static int SStubSkipRaster(void *ap, int seqNo);
static int SStubEndRaster(void *ap, int seqNo);
static int SStubStartStream(void *ap, int seqNo);
static int SStubTransferStreamData(void *ap, int seqNo);
static int SStubEndStream(void *ap, int seqNo);
#if (_PDAPI_VERSION_MAJOR_ > 0 || _PDAPI_VERSION_MINOR_ >= 2)
static int SStubQueryDeviceCapability(void *ap, int seqNo);
static int SStubQueryDeviceInfo(void *ap, int seqNo);
static int SStubResetClipPath(void *ap, int seqNo);
#endif

#endif /* _OPVP_RPC_SERVER_H_ */
