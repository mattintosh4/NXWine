/* pdapi.h -- PDAPIの定義ファイル
 * Copyright (C) 2003 EPSON KOWA Corporation
 *
 * Permission to use, copy, modify, distribute, and sell this software
 * and its documentation for any purpose is hereby granted without fee,
 * provided that the above copyright notice appear in all copies and
 * that both that copyright notice and this permission notice appear in
 * supporting documentation.
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT.  IN NO EVENT SHALL EPSON KOWA CORPORATION BE LIABLE FOR
 * ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 * CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of EPSON KOWA Corporation
 * shall not be used in advertising or otherwise to promote the sale,
 * use or other dealings in this Software without prior written
 * authorization from EPSON KOWA Corporation.
 */

/* $Id: pdapi.h,v 1.1.1.1 2004/10/22 08:37:09 gishi Exp $ */

#ifndef _PDAPI_H
#define _PDAPI_H

/* Return Values */
#define	OK		0
#define ERROR		-1

/* Error Codes */
/*
 * 定数の各値は仮。
 */
#define	FATALERROR	1	/* ライブラリ内で復旧不可能なエラーが発生した */
#define	BADREQUEST	2	/* 関数を呼んではいけないところで、呼んでしまった */
#define	BADCONTEXT	3	/* パラメータのプリンタコンテキストが不正 */
#define	NOTSUPPORTED	4	/* パラメータの組み合わせにより、ドライバもしくは
				   プリンタが扱えないリクエストが行われた。*/
#define	JOBCANCELED	5	/* なんらかの要因により、ジョブをキャンセルしている。*/
#define	PARAMERROR	6	/* パラメータの組み合わせが不正 */


/* Fix  */
/**
 * opvp_common.hからコピーしてOPVP_を削除
 */
#define FIX_FRACT_WIDTH    8
#define FIX_FRACT_DENOM    (1<<FIX_FRACT_WIDTH)
#define FIX_FLOOR_WIDTH    (sizeof(int)*8-FIX_FRACT_WIDTH)
typedef struct {
        unsigned int    fract   : FIX_FRACT_WIDTH;
        signed int      floor   : FIX_FLOOR_WIDTH;
} Fix;
#define i2Fix(i,fix)       (fix.fract=0,fix.floor=i)
#define Fix2f(fix,f)       (f=(double)fix.floor\
                                  +(double)(fix.fract)/FIX_FRACT_DENOM)
#define f2Fix(f,fix)       (fix.fract=(f-floor(f))*FIX_FRACT_DENOM,\
                                 fix.floor=floor(f))
/* 切り捨てタイプ */
/* #define Fix2i(fix)         (fix.floor) */
/* 四捨五入タイプ */
#define Fix2i(fix)         (fix.floor + (int)floor(((double)(fix.fract) / FIX_FRACT_DENOM) + 0.5))
#define Fix2d(fix)       ((double)fix.floor + (double)(fix.fract) / FIX_FRACT_DENOM)
#define ApplyCtmX_Integer(x, y, ctm) ((int)(floor(((Fix2d(x) * (ctm).a) + (Fix2d(y) * (ctm).c) + (ctm).e) + 0.5)))
#define ApplyCtmY_Integer(x, y, ctm) ((int)(floor(((Fix2d(x) * (ctm).b) + (Fix2d(y) * (ctm).d) + (ctm).f) + 0.5)))

/** ここまで */


/* Basic Types */
typedef struct Point_s {
	Fix	x;
	Fix	y;
} Point;

typedef struct Rectangle_s {
	Point	p0;	/* 開始点 */
	Point	p1;	/* 対角点 */
} Rectangle;

typedef struct RoundRectangle_s {
	Point	p0;	/* 開始点 */
	Point	p1;	/* 対角点 */
	Fix		xellipse;
	Fix		yellipse;
} RoundRectangle;

/* Image Formats */
typedef enum _ImageFormat {
	iformatRaw = 0,
	iformatRLE = 1,
	iformatJPEG = 2,
	iformatPNG = 3
} ImageFormat;

/* Color Presentation */
typedef enum _ColorMapping {
	cmapDirect = 0,
	cmapIndexed = 1
} ColorMapping;

typedef enum _ColorSpace {
	cspaceBW = 0,
	cspaceDeviceGray = 1,
	cspaceDeviceCMY = 2,
	cspaceDeviceCMYK = 3,
	cspaceDeviceRGB = 4,
	cspaceStandardRGB = 5,
	cspaceStandardRGB64 = 6
} ColorSpace;

/* Fill, Paint, Clip */
typedef enum _FillMode {
	fillModeEvenOdd = 0,
	fillModeWinding = 1
} FillMode;

typedef enum _PaintMode {
	paintModeOpaque = 0,
	paintModeTransparent = 1
} PaintMode;

typedef enum _ClipRule {
	clipRuleEvenOdd = 0,
	clipRuleWinding = 1
} ClipRule;

/* Line */
typedef enum _LineStyle {
	lineStyleSolid = 0,
	lineStyleDash = 1
} LineStyle;

typedef enum _LineCap {
	lineCapButt = 0,
	lineCapRound = 1,
	lineCapSquare = 2
} LineCap;

typedef enum _LineJoin {
	lineJoinMiter = 0,
	lineJoinRound = 1,
	lineJoinBevel = 2
} LineJoin;

/* Brush */
typedef enum _BrushDataType {
	bdtypeNormal = 0
} BrushDataType;

typedef struct BrushData_s {
	BrushDataType	type;
	int		width;
	int		height;
	int		pitch;
	void		*data;		// pointer to actual data
} BrushData;

typedef struct Brush_s {
	ColorSpace	colorSpace;
	int		color[4];		/* aRGB quadruplet */
	int		xorg, yorg;		/* brush origin
						   ignored for SetBgColor */
	BrushData	*pbrush;		/* pointer to brush data
						   solid brush used, if null */
} Brush;


/* Misc. Flags */
#define	Arc			0	/* 円弧 */
#define	Chord			1	/* 弓形 */
#define	Pie			2	/* 扇形 */
#define	Clockwise			/* 時計方向 */
#define	Counterclockwise		/* 反時計方向 */
#define	PathClose		0	/* Close path upon LinePath */
#define	PathOpen		1	/* Do not close path upon LinePath */

/* CTM */
typedef struct CTM_s {
	float a, b, c, d, e, f;
} CTM;


extern int	errorno;

/* KLUDGE!
   The API draft specification requires that drivers only export the
   OpenPrinter function so we have to declare all other functions as
   static.  To avoid breaking the existing (broken) implementations,
   you work around this by defining PDAPI_STRICT_SPEC.
 */
#ifdef PDAPI_STRICT_SPEC
#define PDAPI_STATIC static
#else
#define PDAPI_STATIC
#endif

/* The spec requires us to fill unsupported functionality slots in the
   apiEntry[] passed into OpenPrinting() with NULL so we'd better make
   sure it is defined.  */
#ifndef NULL
#define NULL 0
#endif

/* プロトタイプ宣言 */
/* Creating and Managing Print Contexts */
#ifdef PDAPI_STRICT_SPEC
int OpenPrinter(int outputFD, char *printerModel, int *nApiEntry, int (**apiEntry[])());
#else
int OpenPrinter(int outputFD, char *printerModel, int *nApiEntry, void *apiEntry[]);
#endif
PDAPI_STATIC int ClosePrinter(int printerContext);

/* Job Control Operations */
PDAPI_STATIC int StartJob(int printerContext, char *jobInfo);
PDAPI_STATIC int EndJob(int printerContext);
PDAPI_STATIC int StartDoc(int printerContext, char *docInfo);
PDAPI_STATIC int EndDoc(int printerContext);
PDAPI_STATIC int StartPage(int printerContext, char *pageInfo);
PDAPI_STATIC int EndPage(int printerContext);
PDAPI_STATIC int QueryDeviceCapability(int printerContext, int queryflag, int buflen, char *infoBuf);
PDAPI_STATIC int QueryDeviceInfo(int printerContext, int queryflag, int buflen, char *infoBuf);

/* Graphics State Object Operations */
PDAPI_STATIC int ResetCTM(int printerContext);
PDAPI_STATIC int SetCTM(int printerContext, CTM *pCTM);
PDAPI_STATIC int GetCTM(int printerContext, CTM *pCTM);
PDAPI_STATIC int InitGS(int printerContext);
PDAPI_STATIC int SaveGS(int printerContext);
PDAPI_STATIC int RestoreGS(int printerContext);
PDAPI_STATIC int QueryColorSpace(int printerContext, ColorSpace *pcspace, int *pnum);
PDAPI_STATIC int SetColorSpace(int printerContext, ColorSpace cspace);
PDAPI_STATIC int GetColorSpace(int printerContext, ColorSpace *pcspace);
PDAPI_STATIC int QueryROP(int printerContext, int *pnum, int *prop);
PDAPI_STATIC int SetROP(int printerContext, int rop);
PDAPI_STATIC int GetROP(int printerContext, int *prop);
PDAPI_STATIC int SetFillMode(int printerContext, FillMode fillmode);
PDAPI_STATIC int GetFillMode(int printerContext, FillMode* pfillmode);
PDAPI_STATIC int SetAlphaConstant(int printerContext, float alpha);
PDAPI_STATIC int GetAlphaConstant(int printerContext, float *palpha);
PDAPI_STATIC int SetLineWidth(int printerContext, Fix width);
PDAPI_STATIC int GetLineWidth(int printerContext, Fix *pwidth);
PDAPI_STATIC int SetLineDash(int printerContext, Fix pdash[], int num);
PDAPI_STATIC int GetLineDash(int printerContext, Fix pdash[], int *pnum);
PDAPI_STATIC int SetLineDashOffset(int printerContext, Fix offset);
PDAPI_STATIC int GetLineDashOffset(int printerContext, Fix *poffset);
PDAPI_STATIC int SetLineStyle(int printerContext, LineStyle linestyle);
PDAPI_STATIC int GetLineStyle(int printerContext, LineStyle *plinestyle);
PDAPI_STATIC int SetLineCap(int printerContext, LineCap linecap);
PDAPI_STATIC int GetLineCap(int printerContext, LineCap *plinecap);
PDAPI_STATIC int SetLineJoin(int printerContext, LineJoin linejoin);
PDAPI_STATIC int GetLineJoin(int printerContext, LineJoin *plinejoin);
PDAPI_STATIC int SetMiterLimit(int printerContext, Fix miterlimit);
PDAPI_STATIC int GetMiterLimit(int printerContext, Fix *pmiterlimit);
PDAPI_STATIC int SetPaintMode(int printerContext, PaintMode paintmode);
PDAPI_STATIC int GetPaintMode(int printerContext, PaintMode *ppaintmode);
PDAPI_STATIC int SetStrokeColor(int printerContext, Brush *brush);
PDAPI_STATIC int SetFillColor(int printerContext, Brush *brush);
PDAPI_STATIC int SetBgColor(int printerContext, Brush *brush);

/* Path Operations */
PDAPI_STATIC int NewPath(int printerContext);
PDAPI_STATIC int EndPath(int printerContext);
PDAPI_STATIC int StrokePath(int printerContext);
PDAPI_STATIC int FillPath(int printerContext);
PDAPI_STATIC int StrokeFillPath(int printerContext);
PDAPI_STATIC int SetClipPath(int printerContext, ClipRule clipRule);
PDAPI_STATIC int ResetClipPath( int printerContext);
PDAPI_STATIC int SetCurrentPoint(int printerContext, Fix x, Fix y);
PDAPI_STATIC int LinePath(int printerContext, int flag, int npoints, Point *points);
PDAPI_STATIC int PolygonPath(int printerContext, int npolygons, int *nvertexes, Point *points);
PDAPI_STATIC int RectanglePath(int printerContext, int nrectangles, Rectangle *rectangles);
PDAPI_STATIC int RoundRectanglePath(int printerContext, int nrectangles, RoundRectangle *rectangles);
PDAPI_STATIC int BezierPath(int printerContext, int npoints, Point *points);
PDAPI_STATIC int ArcPath(int printerContext, int kind, int dir, Fix bbx0, Fix bby0, Fix bbx1, Fix bby1, Fix x0, Fix y0, Fix x1, Fix y1);

/* Text Operations */
PDAPI_STATIC int DrawBitmapText(int printerContext, int width, int height, int pitch, void *fontdata);

/* Bitmap Image Operations */
PDAPI_STATIC int DrawImage(int printerContext, int sourceWidth, int sourceHeight, int colorSpace, ImageFormat imageFormat, Rectangle destinationSize, int count, void *imageData);
PDAPI_STATIC int StartDrawImage(int printerContext, int sourceWidth, int sourceHeight, int colorSpace, ImageFormat imageFormat, Rectangle destinationSize);
PDAPI_STATIC int TransferDrawImage(int printerContext, int count, void *imageData);
PDAPI_STATIC int EndDrawImage(int printerContext);

/* Scan Line Operations */
PDAPI_STATIC int StartScanline(int printerContext, int yposition);
PDAPI_STATIC int Scanline(int printerContext, int nscanpairs, int *scanpairs);
PDAPI_STATIC int EndScanline(int printerContext);

/* Raster Image Operations */
PDAPI_STATIC int StartRaster(int printerContext, int rasterWidth);
PDAPI_STATIC int TransferRasterData(int printerContext, int count, unsigned char *data);
PDAPI_STATIC int SkipRaster(int printerContext, int count);
PDAPI_STATIC int EndRaster(int printerContext);

/* Stream Data Operations */
PDAPI_STATIC int StartStream(int printerContext);
PDAPI_STATIC int TransferStreamData(int printerContext, int count, void *data);
PDAPI_STATIC int EndStream(int printerContext);



#endif /* _PDAPI_H */
