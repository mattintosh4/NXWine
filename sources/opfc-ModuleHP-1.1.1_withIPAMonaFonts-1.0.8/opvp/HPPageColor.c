/* HPPageColor.c -- Vector Driver for HP Color LaserJet Printer.
 * Copyright (C) 2003 EPSON KOWA Corporation
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/* $Id: HPPageColor.c,v 1.1.1.1 2004/10/22 08:37:08 gishi Exp $ */


/* system include files */

#include <sys/types.h>
#include <unistd.h>

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <stdarg.h>
#include <math.h>

/* local */
#include "pdapi.h"

typedef int bool;

#ifndef FALSE
#define FALSE 0
#endif

#ifndef TRUE
#define TRUE (!FALSE)
#endif

#ifndef NULL
#ifdef __cplusplus
#define NULL 0
#else
#define NULL (void *)0
#endif
#endif

typedef double floatp;


#define GS              (0x1b)
#define PCL_ESC         "\033"
#define PCL_FF          "\014"
#define PCL_CR          "\015"
#define PCL_LF          "\012"
#define PCL_BS          "\010"

#define POINT                           72
#define PCLUNIT                         720
#define MMETER_PER_INCH                 25.4

#define HP_DEFAULT_WIDTH                (4840)
#define HP_DEFAULT_HEIGHT               (6896)

#define HP_LEFT_MARGIN_DEFAULT          5. / (MMETER_PER_INCH / POINT)
#define HP_BOTTOM_MARGIN_DEFAULT        5. / (MMETER_PER_INCH / POINT)
#define HP_RIGHT_MARGIN_DEFAULT         5. / (MMETER_PER_INCH / POINT)
#define HP_TOP_MARGIN_DEFAULT           5. / (MMETER_PER_INCH / POINT)

struct node {
    long                byte;
    char                *buf;
    struct node         *next;
};


#define         BUFCHECK(x)             \
        if (strlen(obuf) > x) {         \
            (void)DebugPrint("overflow %d : LINE %d\n", strlen(obuf), __LINE__); \
        }



#define HP_OPTION_MANUALFEED            "ManualFeed"            /* �ѻ�ȥ쥤 */
#define HP_OPTION_CASSETFEED            "Casset"                /* ���ȥ쥤 */
#define HP_OPTION_FACEUP                "FU"                    /* �ӻ�ȥ쥤 Face Up */
#define HP_OPTION_FACEDOWN              "FD"                    /* �ӻ�ȥ쥤 Face Down */
#define HP_OPTION_DUPLEX                "Duplex"                /* ξ�̰��� */
#define HP_OPTION_DUPLEX_TUMBLE         "Tumble"                /* �Ȥ����� */
#define HP_OPTION_MEDIATYPE             "MediaType"             /* ��� */
#define HP_OPTION_RIT                   "RITOff"                /* RIT */
#define HP_OPTION_LANDSCAPE             "Landscape"             /* LANDSCAPE */
#define HP_OPTION_TONERDENSITY          "TonerDensity"          /* �ȥʡ�ǻ�� */
#define HP_OPTION_TONERSAVING           "TonerSaving"           /* �ȥʡ������� */
#define HP_OPTION_COLLATE               "Collate"               /* �������� */

#define HP_TUMBLE_DEFAULT               FALSE                   /* Long age */
#define HP_RIT_DEFAULT                  FALSE
#define HP_FACEUP_DEFAULT               FALSE
#define HP_FACEUP_DEFAULT               FALSE

#define HP_MEDIATYPE_DEFAULT            0                       /* NORMAL */
#define HP_MEDIACHAR_MAX                32

#define HP_MANUALFEED_DEFAULT           FALSE
#define HP_CASSETFEED_DEFAULT           0

#define HP_DPI_MIN                      60
#define HP_DPI_MAX                      600
#define HP_DPI_SUPERFINE                1200

#define HP_A3_HEIGHT                    1190
#define HP_A3_WIDTH                     842
#define HP_POSTCARD_HEIGHT              419
#define HP_POSTCARD_WIDTH               284
#define HP_LETTER_HEIGHT                792
#define HP_LETTER_WIDTH                 612
#define HP_LEDGER_HEIGHT                1224
#define HP_LEDGER_WIDTH                 HP_LETTER_HEIGHT

#define HP_HEIGHT_MAX                   HP_A3_HEIGHT
#define HP_WIDTH_MAX                    HP_A3_WIDTH
#define HP_HEIGHT_MIN                   HP_POSTCARD_HEIGHT
#define HP_WIDTH_MIN                    HP_POSTCARD_WIDTH

#define EP_COMPRESS5                    (5 << 16)
#define EP_COMPRESS20                   (20 << 16)
#define EP_COMPRESS30                   (30 << 16)

#define RES1200                         HP_DPI_SUPERFINE
#define RES600                          HP_DPI_MAX
#define RES300                          300

#define JPN                             TRUE
#define ENG                             FALSE

#define HP_COLOR_ID_STROKE              2
#define HP_COLOR_ID_FILL                3
#define HP_COLOR_ID_BACK                4

#define HP_DEFAULT_PRINTER              "default"       /* �ǥե���ȥץ��̾�� */
#define HP_OPTION_FACE_UP               "UPPER"         /* �ӻ�ȥ쥤 Face Up */
#define HP_OPTION_FACE_DOWN             "LOWER"         /* �ӻ�ȥ쥤 Face Down */

#define HP_OPTION_ON                    "ON"            /* ON ʸ���� */
#define HP_OPTION_OFF                   "OFF"           /* OFF ʸ���� */


typedef struct PaperTable_s
{
    int         width;                  /* paper width (unit: dot(300dpi)) */
    int         height;                 /* paper height (unit: dot(300dpi)) */
    int         distwidth;              /* distance logical area (unit: dot(300dpi)) */
    int         distheight;             /* distance picture frame area (unit: dot(300dpi)) */
    int         distdraw;               /* distance printable area (unit: dot(300dpi)) */
    int         pcl;                    /* number of papersize in PCL */
    char        *name;                  /* paper Name */
} PaperTable;

static const PaperTable HpPaperTable[] =
{
    {2480, 3507, 71, 150, 50, 26, "A4"},              /* A4 */
    {3507, 4960, 71, 150, 50, 27, "A3"},              /* A3 */
    {2550, 3300, 75, 150, 50, 2, "LETTER"},           /* Letter */
    {2550, 4200, 75, 150, 50, 3, "LEGAL"},            /* Legal */
//    {2175, 3150, 75, 150, 50, 1, "EXECUTIVE"},      /* Executive */
//    {3300, 5100, 75, 150, 50, 6, "LEDGER"},         /* Ledger */
    {0, 0, 0, 0, 0, -1, NULL}                    /* Undefined */
};


/* Vector Driver API Proc. Entries */
typedef struct  _OPVP_api_procs {
        int     (*OpenPrinter)(int,char *,int *,struct _OPVP_api_procs **);
        int     (*ClosePrinter)(int);
        int     (*StartJob)(int,char *);
        int     (*EndJob)(int);
        int     (*StartDoc)(int,char *);
        int     (*EndDoc)(int);
        int     (*StartPage)(int,char *);
        int     (*EndPage)(int);
#ifndef OLD_API
        int     (*QueryDeviceCapability)(int, int, int, char *);
        int     (*QueryDeviceInfo)(int, int, int, char *);
#endif /* OLD_API */
        int     (*ResetCTM)(int);
        int     (*SetCTM)(int,CTM *);
        int     (*GetCTM)(int,CTM *);
        int     (*InitGS)(int);
        int     (*SaveGS)(int);
        int     (*RestoreGS)(int);
        int     (*QueryColorSpace)(int,ColorSpace *,int *);
        int     (*SetColorSpace)(int,ColorSpace);
        int     (*GetColorSpace)(int,ColorSpace *);
        int     (*QueryROP)(int,int *,int *);
        int     (*SetROP)(int,int);
        int     (*GetROP)(int,int *);
        int     (*SetFillMode)(int,FillMode);
        int     (*GetFillMode)(int,FillMode *);
        int     (*SetAlphaConstant)(int,float);
        int     (*GetAlphaConstant)(int,float *);
        int     (*SetLineWidth)(int,Fix);
        int     (*GetLineWidth)(int,Fix *);
        int     (*SetLineDash)(int,Fix *,int);
        int     (*GetLineDash)(int,Fix *,int *);
        int     (*SetLineDashOffset)(int,Fix);
        int     (*GetLineDashOffset)(int,Fix *);
        int     (*SetLineStyle)(int,LineStyle);
        int     (*GetLineStyle)(int,LineStyle *);
        int     (*SetLineCap)(int,LineCap);
        int     (*GetLineCap)(int,LineCap *);
        int     (*SetLineJoin)(int,LineJoin);
        int     (*GetLineJoin)(int,LineJoin *);
        int     (*SetMiterLimit)(int,Fix);
        int     (*GetMiterLimit)(int,Fix *);
        int     (*SetPaintMode)(int,PaintMode);
        int     (*GetPaintMode)(int,PaintMode *);
        int     (*SetStrokeColor)(int,Brush *);
        int     (*SetFillColor)(int,Brush *);
        int     (*SetBgColor)(int,Brush *);
        int     (*NewPath)(int);
        int     (*EndPath)(int);
        int     (*StrokePath)(int);
        int     (*FillPath)(int);
        int     (*StrokeFillPath)(int);
        int     (*SetClipPath)(int,ClipRule);
#ifndef OLD_API
        int     (*ResetClipPath)(int);
#endif /* OLD_API */
        int     (*SetCurrentPoint)(int,Fix,Fix);
        int     (*LinePath)(int,int,int,Point *);
        int     (*PolygonPath)(int,int,int *,Point *);
        int     (*RectanglePath)(int,int,Rectangle *);
        int     (*RoundRectanglePath)(int,int,RoundRectangle *);
        int     (*BezierPath)(int,int *,Point *);
        int     (*ArcPath)(int,int,int,Fix,Fix,Fix,Fix,
                           Fix,Fix,Fix,Fix);
        int     (*DrawBitmapText)(int,int,int,int,void *);
        int     (*DrawImage)(int,int,int,int,
                             ImageFormat,Rectangle,int,void *);
        int     (*StartDrawImage)(int,int,int,int,
                                  ImageFormat,Rectangle);
        int     (*TransferDrawImage)(int,int,void *);
        int     (*EndDrawImage)(int);
        int     (*StartScanline)(int,int);
        int     (*Scanline)(int,int,int *);
        int     (*EndScanline)(int);
        int     (*StartRaster)(int,int);
        int     (*TransferRasterData)(int,int,unsigned char *);
        int     (*SkipRaster)(int,int);
        int     (*EndRaster)(int);
        int     (*StartStream)(int);
        int     (*TransferStreamData)(int,int,void *);
        int     (*EndStream)(int);
} OPVP_api_procs;

/* �ꥹ�ȤΥΡ��� */
typedef struct ItemList_s {
        void *item;
        size_t length;
        struct ItemList_s *next;
} ItemList;

/*
 * GraphicsState
 *      ����˴ؤ������Ƥξ����������빽¤��
 */
typedef struct GraphicsState_s {
        /* Graphic State Object Operations */
        CTM             ctm;
        ColorSpace      colorSpace;
        FillMode        fillMode;
        Fix             lineWidth;
        LineCap         lineCap;
        LineJoin        lineJoin;
        Brush           strokeBrush;
        Brush           fillBrush;
        Brush           bgBrush;
        bool            useBgBrush;
        int             rop;
        PaintMode       paintMode;

        /* Path */
        bool        pathActive; /* Path������Ǥ����TRUE�������Ǥʤ����FALSE */
        bool        subpathActive; /* SubPath������Ǥ����TRUE�������Ǥʤ����FALSE */
        ItemList    *pathList; /* Path���ޥ�ɤ��Ǽ����ꥹ�Ȥ���Ƭ���ɥ쥹 */
        ItemList    *pathEndPoint; /* Path���ޥ�ɥꥹ�Ȥν�ü���ɥ쥹 */
        Fix         miterlimit; /* MiterLimit������ */

        /* Image */
        bool        imageActive; /* Image������Ǥ����TRUE�������Ǥʤ����FALSE */
        ImageFormat imageFormat;
        int         imageWidth;
        int         imageHeight;
        int         imageDepth;
        int         imageDestWidth;
        int         imageDestHeight;
} GraphicsState;


/*
 * GraphicsStateList
 *      GraphicsState �δ����ѥꥹ��
 *      next �Ǥ��ɤä��Ǹ夬�����Ȥ� GraphicsState ��ɽ��
 */
typedef struct GraphicsStateList_s {
        GraphicsState                           *gstate;
        struct GraphicsStateList_s      *next;
} GraphicsStateList;

/*
 * JobInfo
 *      Job �δ����ѹ�¤��
 */
typedef struct JobInfo_s {
        GraphicsStateList               gstateList;     /* Graphics State */
} JobInfo;

/*
 * DeviceInfo
 *      �ץ�󥿤ΥǥХ��������ɽ��
 *      ���Ĥ� printerContext �ˣ��Ĥ���¸�ߤ���
 */
typedef struct DeviceInfo_s {
        bool            manualFeed;                     /* Use manual feed */
        int             cassetFeed;                     /* Input Casset */
        bool            RITOff;                         /* RIT Control */
        bool            Collate;                        /* �������� */
        int             toner_density;                  /* �ȥʡ�ǻ�� */
        bool            toner_saving;                   /* �ȥʡ������� */
        int             prev_paper_size;
        int             prev_paper_width;
        int             prev_paper_height;
        int             prev_num_copies;
        int             prev_feed_mode;
        int             orientation;                    /* ���� */
        int             MediaType;                      /* ��� */

        bool            first_page;
        bool            Tumble;                         /* �Ȥ����� */
        int             ncomp;
        int             MaskReverse;                    /* ȿž���� */
        int             MaskState;
        bool            c4map;                          /* 4bit ColorMap */
        bool            c8map;                          /* 8bit ColorMap */
        int             prev_x;
        int             prev_y;

        /* for Font Downloading */
        long            reverse_x;
        long            reverse_y;
        int             bx, by;
        int             w, h;
        int             roll;
        float           sx, sy;
        long            dd;

        unsigned char   *printerName;                   /* �ץ��̾�� */
        int             resolution;                     /* ����ֲ����� */
        int             maxRes;                         /* ��������� */
        int             country;                        /* ���̾��� */
        char            *duplex;                        /* ξ�̰��� */
        char            *face;                          /* �ե��������� */
        int             pageSize;                       /* �ѻ極���� */

} DeviceInfo;


/*
 * Printer
 *      �ץ�󥿤����Ƥξ����������뤿��ι�¤�Τ�ɽ��
 *      ���Ĥ� printerContext �ˣ��Ĥ���¸�ߤ���
 */
typedef struct Printer_s {
        DeviceInfo              dev;                            /* Device */
        JobInfo                 job;                            /* job infomation */
        int                     outputFD;                       /* �����ǡ����ν����� */
        bool                    jobStarted;                     /* StartJob����λ���Ƥ��뤫 */
//      PageInfo                page;                           /* page information */
//      DocInfo                 doc;                            /* document information */
} Printer;

/*
 * PrinterList
 *      Printer �Υꥹ�Ȥ�������뤿��ι�¤�Τ�ɽ��
 */
typedef struct PrinterList_s {
        Printer                 printer;                        /* Device */
        int                     printerContext;         /* printerContext */
        struct PrinterList_s    *next;
} PrinterList;

/* ---------------- global valiable(s) ---------------- */
/* Printer �δ����� */
PrinterList             *gPrinterList = NULL;

/* ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */

/*
 * ScaleInfo
 *      �����ΰ������;����ɽ��
 */
typedef struct ScaleInfo_s {
        int             pictFrame_x;                    /* PCL PictureFrame X */
        int             pictFrame_y;                    /* PCL PictureFrame Y */
        int             pictOffs;                       /* PCL PictureOffset */
        int             glScale_x;                      /* GL Scale X */
        int             glScale_y;                      /* GL Scale Y */
        int             glScale_min;                    /* GL Scale Min */
} ScaleInfo;



/* static functions */
static void DebugPrint(const char *fmt, ...);
static ItemList *NewList(void *item, size_t length);
static void DeleteList(ItemList *node);
static ItemList *AddList(void *list, void *item, size_t length);
static void DeleteListAll(ItemList *node);
static int Write(int printerContext, const void *buf, size_t nBytes);
static int CheckWrite(int printerContext, const void *buf, size_t nBytes);

static Printer *GetPrinter(int printerContext);
static GraphicsState *GetGraphicsState(int printerContext);
static int NewPrinterContext(void);
static DeviceInfo *GetDeviceInfo(int printerContext);

//static int WriteLineAttributes(int printerContext) ;
static int CopyBrush(Brush* dest, Brush* src);
static bool IsSameBrush(Brush *pb1, Brush *pb2);

static int SetPrinterName(int printerContext, char *printerModel);
static int SetBrushData(int printerContext, Brush *pbrush, int brushID);

static int GetScaleInfo(DeviceInfo *pdev, ScaleInfo *pscl);

/* #### ���Υɥ饤�Фǡ����ݡ��Ȥ���Ƥ���ؿ��ꥹ�� */
static const void *VectorProcs[] =
{
        /* Creating and Managing Print Contexts */
        OpenPrinter,
        ClosePrinter,

        /* Job Control Operations */
        StartJob,
        EndJob,
        StartDoc,
        EndDoc,
        StartPage,
        EndPage,
#ifndef OLD_API
        NULL, /* QueryDeviceCapability, */
        NULL, /* QueryDeviceInfo, */
#endif /* OLD_API */

        /* Graphics State Object Operations */
        ResetCTM,
        SetCTM,
        GetCTM,
        InitGS,
        SaveGS,
        RestoreGS,
        QueryColorSpace,
        SetColorSpace,
        GetColorSpace,
        QueryROP,
        SetROP,
        GetROP,
        SetFillMode,
        GetFillMode,
        NULL, /* SetAlphaConstant, */
        NULL, /* GetAlphaConstant, */
        SetLineWidth,
        GetLineWidth,
        NULL, /* SetLineDash, */
        NULL, /* GetLineDash, */
        NULL, /* SetLineDashOffset, */
        NULL, /* GetLineDashOffset, */
        NULL, /* SetLineStyle, */
        NULL, /* GetLineStyle, */
        SetLineCap,
        GetLineCap,
        SetLineJoin,
        GetLineJoin,
        SetMiterLimit,
        GetMiterLimit,
        SetPaintMode,
        GetPaintMode,
        SetStrokeColor,
        SetFillColor,
        SetBgColor,

        /* Path Operations */
        NewPath,
        EndPath,
        StrokePath,
        FillPath,
        StrokeFillPath,
        NULL, /* SetClipPath */
#ifndef OLD_API
        NULL, /* ResetClipPath */
#endif
        SetCurrentPoint,
        LinePath,
        PolygonPath,
        RectanglePath,
        RoundRectanglePath,
        BezierPath,
        NULL, /* ArchPath, */

        /* Text Operations */
        NULL, /* DrawBitmapText, */

        /* Bitmap Image Operations */
        NULL, /* DrawImage, */
        StartDrawImage,
        TransferDrawImage,
        EndDrawImage,

        /* Scan Line Operations */
        NULL, /* StartScanline, */
        NULL, /* Scanline, */
        NULL, /* EndScanline, */

        /* Raster Image Operations */
        StartRaster,
        TransferRasterData,
        SkipRaster,
        EndRaster,

        /* Stream Data Operations */
        NULL, /* StartStream, */
        NULL, /* TransferStreamData, */
        NULL, /* EndStream */
};

/* ���顼�����ɳ�Ǽ�ѤΥ����Х��ѿ� */
int     errorno;


/* ----------------------------------------------------------------

    Static Functions

 * ---------------------------------------------------------------- */
/* ----------------------------------------------------------------
 *
 *      DebugPrint
 *
 * Name
 *      DebugPrint - Debug�ѥ�å��������ϴؿ�
 *
 * Arguments
 *      printf��Ʊ��
 *
 * Description
 *      �ܴؿ��ϡ�"DEBUG"��define����Ƥ����硢��å�������stderr��
 *      ���Ϥ��롣"DEBUG"��define����Ƥ��ʤ���С�����Ԥ�ʤ���
 *
 * Return Value
 *      ̵��
 * ---------------------------------------------------------------- */
static void DebugPrint(const char *fmt, ...)
{
#ifdef DEBUG
        va_list ap;

        va_start(ap, fmt);
        vfprintf(stderr, fmt, ap);
        va_end(ap);
        fflush(stderr);
#endif
        return;
}

/* ----------------------------------------------------------------
 *
 *      NewList
 *
 * Name
 *      NewList - �ꥹ�ȤΥΡ��ɤ��������
 *
 * Arguments
 *      item - item(data)��Ǽ���ؤΥݥ���
 *      length - item�Υ�����
 *
 * Description
 *      ItemList��¤�Τ��ΰ����ݤ���item���Ǽ�����ꥹ�ȤΥΡ��ɤ�
 *      �����˺�������
 *
 * Return Value
 *      ��������к��������Ρ��ɤؤΥݥ��󥿤򡢼��Ԥʤ�NULL���֤�
 * ---------------------------------------------------------------- */
static ItemList *NewList(void *item, size_t length)
{
        ItemList *node;

        if (item == NULL) {
                errorno = FATALERROR;
                return (NULL);
        }

        node = (ItemList *)malloc(sizeof(ItemList)+length);
        if (node == NULL) {
                errorno = FATALERROR;
                return (NULL);
        }

        if (length == 0) {
                node->item = NULL;
        } else {
                node->item = node + 1;
                memcpy (node->item, item, length);
        }

        node->length = length;
        node->next = NULL;

        return (node);
}

/* ----------------------------------------------------------------
 *
 *      DeleteList
 *
 * Name
 *      DeleteList - �ꥹ�ȤΥΡ��ɤ�������
 *
 * Arguments
 *      node - �������ItemList��¤�ΤؤΥݥ���
 *
 * Description
 *      �Ρ��ɤ��ΰ��������ޤ�
 *
 * Return Value
 *      ̵��
 * ---------------------------------------------------------------- */
static void DeleteList(ItemList *node)
{
        if (node != NULL) {
                free(node);
        }
        return;
}

/* ----------------------------------------------------------------
 *
 *      AddList
 *
 * Name
 *      AddList - �Ρ��ɤ���������ꥹ�Ȥ��ɲä���
 *
 * Arguments
 *      list - list�ؤΥݥ���
 *      item - item(data)��Ǽ���ؤΥݥ���
 *      length - item�Υ�����
 *
 * Description
 *      list�κǸ�˥Ρ��ɤ��ɲä���
 *
 * Return Value
 *      ��������к��������Ρ��ɤؤΥݥ��󥿤򡢼��Ԥʤ�NULL���֤�
 * ---------------------------------------------------------------- */
static ItemList *AddList(void *list, void *item, size_t length)
{
        ItemList *node;

        if (list == NULL) {
                errorno = FATALERROR;
                return (NULL);
        }

        node = list;
        while (node->next != NULL) {
                node = node->next;
        }

        node->next = NewList(item, length);
        return (node->next);
}

/* ----------------------------------------------------------------
 *
 *      DeleteListAll
 *
 * Name
 *      DeleteListAll - �ꥹ�Ȥ˴ޤޤ�����ƤΥΡ��ɤ�������
 *
 * Arguments
 *      node - �������ꥹ�Ȥ���Ƭ��ItemList��¤�ΤؤΥݥ���
 *
 * Description
 *      �ꥹ�����ƤΥΡ��ɤ�������ޤ�
 *
 * Return Value
 *      ̵��
 * ---------------------------------------------------------------- */
static void DeleteListAll(ItemList *node)
{
        if (node == NULL) {
                return;
        }

        while (node != NULL) {
                ItemList *next;

                next = node->next;
                DeleteList(node);
                node = next;
        }
        return;
}


/* ----------------------------------------------------------------
 *
 *      GetPrinter
 *
 * Name
 *      GetPrinter - get specified printer context.
 *                                              ���ꤵ�줿 printerContext ����ץ�󥿾�����֤���
 *
 * Arguments
 *      printerContext - OpenPrinter �����ֵѤ��줿�ץ�󥿥���ƥ�����
 *                                              �ͤ���ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿 printerContext ����ץ���Ѿ���δ�ؤΥݥ��󥿤��֤���
 *
 * Return Value
 *      ����˽�λ����ȥץ�󥿾���ؤΥݥ��󥿤��֤���롣
 *      ���顼�����ä����� NULL ���֤���롣
 *
 * ---------------------------------------------------------------- */
static Printer *GetPrinter(int printerContext)
{
        PrinterList             *list;

        for (list = gPrinterList; list != NULL; list = list->next) {
                if (list->printerContext == printerContext) {
                        break;
                }
        }
        if (list == NULL) {
                errorno = BADCONTEXT;
                return(NULL);
        }
        return(&(list->printer));
}

/* ----------------------------------------------------------------
 *
 *      GetGraphicsState
 *
 * Name
 *      GetGraphicsState - get specified graphics state
 *                                              printerContext �ǻ��ꤵ�줿 Graphics State ���֤���
 *
 * Arguments
 *      printerContext - OpenPrinter �����ֵѤ��줿�ץ�󥿥���ƥ�����
 *                                              �ͤ���ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿 printerContext �Ǥ� �����Ȥ� Graphics State ���֤���
 *
 * Return Value
 *      ����˽�λ����ȥץ�󥿤� Graphics State �ؤΥݥ��󥿤��֤���롣
 *      ���顼�����ä����� NULL ���֤���롣
 *
 * ---------------------------------------------------------------- */
static GraphicsState *GetGraphicsState(int printerContext)
{
        Printer                         *printer;
        GraphicsStateList       *gl;

        printer = GetPrinter(printerContext);
        if (printer == NULL) {
                return(NULL);
        }

        for (gl = &(printer->job.gstateList); gl->next != NULL; gl = gl->next) {
                ;
        }

        return(gl->gstate);
}

/* ----------------------------------------------------------------
 *
 *      CopyGraphicsState
 *
 * Name
 *      CopyGraphicsState - copy graphics state to destination GraphicsState
 *                                              printerContext �ǻ��ꤵ�줿 Graphics State ���֤���
 *
 * Arguments
 *      printerContext - OpenPrinter �����ֵѤ��줿�ץ�󥿥���ƥ�����
 *                                              �ͤ���ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿 printerContext �Ǥ� �����Ȥ� Graphics State ���֤���
 *
 * Return Value
 *      ����˽�λ����ȥץ�󥿤� Graphics State �ؤΥݥ��󥿤��֤���롣
 *      ���顼�����ä����� NULL ���֤���롣
 *
 * ---------------------------------------------------------------- */
static void CopyGraphicsState(GraphicsState *dst, GraphicsState *src)
{
        if (dst->strokeBrush.pbrush)
                free(dst->strokeBrush.pbrush);
        if (dst->fillBrush.pbrush)
                free(dst->fillBrush.pbrush);

        memcpy(dst, src, sizeof(GraphicsState));

        if (src->strokeBrush.pbrush) {
                dst->strokeBrush.pbrush = malloc(sizeof(BrushData));
                if (dst->strokeBrush.pbrush == NULL) {
                        return;
                }
                memcpy(dst->strokeBrush.pbrush, src->strokeBrush.pbrush, sizeof(BrushData));
        }

        if (src->fillBrush.pbrush) {
                dst->fillBrush.pbrush = malloc(sizeof(BrushData));
                if (dst->fillBrush.pbrush == NULL) {
                        return;
                }
                memcpy(dst->fillBrush.pbrush, src->fillBrush.pbrush, sizeof(BrushData));
        }

        /* ����� */
        dst->pathList = NULL;
        dst->pathEndPoint = NULL;

        return;
}

/* ----------------------------------------------------------------
 *
 *      NewGraphicsState
 *
 * Name
 *      NewGraphicsState - create new graphics state
 *
 * Arguments
 *      �ʤ�
 *
 * Description
 *      ������ GraphicsState ���������
 *
 * Return Value
 *      ����˽�λ����ȿ����˺������줿 Graphics State �ؤΥݥ��󥿤��֤���롣
 *      ���顼�����ä����� NULL ���֤���롣
 *
 * ---------------------------------------------------------------- */
static GraphicsState *NewGraphicsState(void)
{
        GraphicsState   *gs;

        gs = malloc(sizeof(GraphicsState));
        if (gs == NULL) {
                errorno = FATALERROR;
                return(NULL);
        }

        gs->strokeBrush.pbrush = NULL;
        gs->fillBrush.pbrush = NULL;
        gs->bgBrush.pbrush = NULL;
        gs->pathList = NULL;
        gs->pathActive = FALSE;

        return(gs);
}

/* ----------------------------------------------------------------
 *
 *      DeleteGraphicsState
 *
 * Name
 *      DeleteGraphicsState - delete specified graphics state
 *
 * Arguments
 *      GraphicsState - ����оݤ� GraphicsState ����ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿 GraphicsState �ˤ֤餵���äƤ��� malloc() �ǳ��ݤ��줿��Τ������롣
 *
 * Return Value
 *      �ʤ�
 *
 * ---------------------------------------------------------------- */
static void DeleteGraphicsState(GraphicsState *gs)
{
        if (gs == NULL) {
                return;
        }

        DeleteListAll(gs->pathList);                    /* �ѥ��κ�� */

        if (gs->strokeBrush.pbrush)
                free(gs->strokeBrush.pbrush);           /* �֥饷�κ�� */
        if (gs->fillBrush.pbrush)
                free(gs->fillBrush.pbrush);

        free(gs);

        return;
}

/* ----------------------------------------------------------------
 *
 *      PushGraphicsState
 *
 * Name
 *      PushGraphicsState - push graphics state and create new graphics state
 *                                              printerContext �ǻ��ꤵ�줿�ץ�󥿤� Graphics State ���ɲä��롣
 *
 * Arguments
 *      printerContext - �оݤΥץ�󥿥���ƥ�����
 *
 * Description
 *      ���ꤵ�줿 printerContext �˥����Ȥ�Ʊ��� Graphics State ���ɲä��롣
 *
 * Return Value
 *      ����˽�λ����ȥץ�󥿤� Graphics State �ؤΥݥ��󥿤��֤���롣
 *      ���顼�����ä����� NULL ���֤���롣
 *
 *      #### �Ȥꤢ����
 *      ���ͽ�Ǥ� "n��" �ȤʤäƤ��뤬�Ϥä��ꤷ�Ƥ��ʤ��Τǡ����������̤�����å�
 *
 * ---------------------------------------------------------------- */
static int PushGraphicsState(int printerContext)
{
        Printer                         *printer;
        GraphicsStateList       *gl;
        GraphicsState           *gs;

        printer = GetPrinter(printerContext);
        if (printer == NULL) {
                return(ERROR);
        }

        for (gl = &(printer->job.gstateList); gl->next != NULL; gl = gl->next) {
                ;
        }
        gl->next = malloc(sizeof(GraphicsStateList));
        if (gl->next == NULL) {
                errorno = JOBCANCELED;
                return(ERROR);
        }
        gl->next->next = NULL;

        gs = NewGraphicsState();
        if (gs == NULL) {
                free(gl->next);                                                 /* ���� */
                gl->next = NULL;
                errorno = JOBCANCELED;
                return(ERROR);
        }
        gl->next->gstate = gs;

        /* ������ GraphicsState �˥����Ȥ� GraphicsState �򥳥ԡ����� */
        CopyGraphicsState(gs, gl->gstate);

        return(OK);
}

/* ----------------------------------------------------------------
 *
 *      PopGraphicsState
 *
 * Name
 *      PopGraphicsState - pop graphics state
 *                                              printerContext �ǻ��ꤵ�줿�ץ�󥿤� Graphics State ���ɲä��롣
 *
 * Arguments
 *      printerContext - �оݤΥץ�󥿥���ƥ�����
 *
 * Description
 *      ���ꤵ�줿 printerContext �˥����Ȥ�Ʊ��� Graphics State ���ɲä��롣
 *
 * Return Value
 *      ����˽�λ����ȥץ�󥿤� Graphics State �ؤΥݥ��󥿤��֤���롣
 *      ���顼�����ä����� NULL ���֤���롣
 *
 * ---------------------------------------------------------------- */
static int PopGraphicsState(int printerContext)
{
        Printer                         *printer;
        GraphicsStateList       *gl;
        GraphicsStateList       *prev;

        printer = GetPrinter(printerContext);
        if (printer == NULL) {
                return(ERROR);
        }

        prev = &(printer->job.gstateList);
        for (gl = prev; gl->next != NULL; gl = gl->next) {
                prev = gl;
        }
        if (prev == &(printer->job.gstateList)) {
                /* ���顼: pop �Ǥ��ʤ� */
                errorno = PARAMERROR;
                return(ERROR);
        }

        prev->next = NULL;
        DeleteGraphicsState(gl->gstate);
        free(gl);

        return(OK);
}

/* ----------------------------------------------------------------
 *
 *      DeleteDevice
 *
 * Name
 *      DeleteDevice - delete a printer device information.
 *                                              �ץ�󥿤� �ǥХ��������Ѥδ�������롣
 *
 * Arguments
 *      printer - �ץ�󥿤� �ǥХ��������Ѥδ����ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿�ץ�󥿤ΥǥХ�������δ��������
 *
 * Return Value
 *      �ʤ�
 *
 * ---------------------------------------------------------------- */
static void DeleteDevice(DeviceInfo *dev)
{

        /* �����Ϻ�����٤���Τϲ���ʤ� */

        return;
}

/* ----------------------------------------------------------------
 *
 *      DeleteJob
 *
 * Name
 *      DeleteJob - delete a job information.
 *                                              �ץ�󥿤� JOB �����Ѥδ�������롣
 *
 * Arguments
 *      printer - �ץ�󥿤� JOB �����Ѥδ����ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿�ץ�󥿤� JOB ����δ��������
 *
 * Return Value
 *      �ʤ�
 *
 * ---------------------------------------------------------------- */
static void DeleteJob(JobInfo *job)
{
        GraphicsStateList       *gl;

        /* GraphicsState �ϥꥹ�ȤˤʤäƤ����ǽ�������� */
        gl = &(job->gstateList);
        for (gl = gl->next; gl != NULL; gl = gl->next) {
                DeleteGraphicsState(gl->gstate);
        }
        job->gstateList.next = NULL;

        return;
}

/* ----------------------------------------------------------------
 *
 *      DeletePrinterContext
 *
 * Name
 *      DeletePrinterContext - delete a printer context.
 *                                              �ץ�󥿾����Ѥδ�������롣
 *
 * Arguments
 *      printerContext - �ץ�󥿥���ƥ������ͤ���ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿�ץ�󥿥���ƥ����ȤΥץ���Ѿ���δ��������
 *
 * Return Value
 *      ����˽�λ����ȿ����˺������줿���ؤ� printerContext �ͤ��֤���롣
 *      ���顼�����ä����� -1 ���֤���롣
 *
 * ---------------------------------------------------------------- */
static int DeletePrinterContext(int printerContext)
{
        PrinterList             *list;
        PrinterList             *prev;
        int                             i;

        list = gPrinterList;
        prev = list;
        for (i = 0; (i < printerContext) && (list->next != NULL); i++) {
                prev = list;
                list = list->next;
        }
        if (printerContext == 0) {
                // ��Ƭ
                gPrinterList = gPrinterList->next;
        } else {
                if (i == printerContext) {
                        prev->next = list->next;
                } else {
                        errorno = BADCONTEXT;
                        return(ERROR);
                }
        }

        /* ��������Τ� list ���� */
        /* dev �ʲ� */
        DeleteDevice(&(list->printer.dev));

        /* job �ʲ� */
        DeleteJob(&(list->printer.job));

        free(list);

        return(OK);
}

/* ----------------------------------------------------------------
 *
 *      NewPrinterContext
 *
 * Name
 *      NewPrinterContext - create a new printer context.
 *                                              �����˥ץ�󥿾����Ѥδ����ݤ��롣
 *
 * Arguments
 *      �ʤ�
 *
 * Description
 *      �ץ���Ѿ���δ�򿷤������
 *
 * Return Value
 *      ����˽�λ����ȿ����˺������줿���ؤ� printerContext �ͤ��֤���롣
 *      ���顼�����ä����� -1 ���֤���롣
 *
 * ---------------------------------------------------------------- */
static int NewPrinterContext(void)
{
        PrinterList                     *list;
        PrinterList                     *next;
        GraphicsStateList       *gl;
        int                                     printerContext;
        int                                     result;

        /* device �������ΰ�γ��� */
        list = malloc(sizeof(PrinterList));
        if (list == NULL) {
                /* ������­ */
                errorno = FATALERROR;
                return(ERROR);
        }

        list->next = NULL;

        if (gPrinterList == NULL) {
                /* ���� */
                gPrinterList = list;
                printerContext = 0;
                list->printerContext = printerContext;
        } else {
                /* �����ܰʹ� */
                for (next = gPrinterList; next->next != NULL; next = next->next) {
                        ;
                }
                printerContext = next->printerContext;
                printerContext++;
                list->printerContext = printerContext;
                next->next = list;
        }


        gl = &(list->printer.job.gstateList);
        gl->gstate = NewGraphicsState();
        if (gl->gstate == NULL) {
                /* ������­ */
                errorno = FATALERROR;

                (void)DeletePrinterContext(printerContext);

                return(ERROR);
        }
        gl->next = NULL;
        list->printer.jobStarted = FALSE;

        /* Graphics State �ν������Ԥʤ� */
        result = InitGS(printerContext);
        if (result < 0) {
                (void)DeletePrinterContext(printerContext);

                return(ERROR);
        }

        return(printerContext);
}

/* ----------------------------------------------------------------
 *
 *      GetDeviceInfo
 *
 * Name
 *      GetDeviceInfo - get specified device information.
 *                                      ���ꤵ�줿 printerContext ����ץ�󥿾�����֤���
 *
 * Arguments
 *      printerContext - OpenPrinter �����ֵѤ��줿�ץ�󥿥���ƥ�����
 *                                              �ͤ���ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿 printerContext ����ץ�󥿤ΥǥХ������� ���֤���
 *
 * Return Value
 *      ����˽�λ����ȥץ�󥿤ΥǥХ�������ؤΥݥ��󥿤��֤���롣
 *      ���顼�����ä����� NULL ���֤���롣
 *
 * ---------------------------------------------------------------- */
static DeviceInfo *GetDeviceInfo(int printerContext)
{
        Printer         *printer;

        printer = GetPrinter(printerContext);
        if (printer == NULL) {
                return(NULL);
        }

        return(&(printer->dev));
}

/* ----------------------------------------------------------------
 *
 *      Write
 *
 * Name
 *      Write - �ǡ����ν񤭹��ߤ�Ԥ��ޤ�
 *
 * Arguments
 *      printerContext - OpenPrinter �����ֵѤ��줿�ץ�󥿥���ƥ�����
 *                                              �ͤ���ꤹ�롣
 *      buf - �񤭹��ߤ�Ԥ��ǡ����ؤΥݥ���
 *      nBytes - �񤭹��ߤ�Ԥ��ǡ����Υ�����
 *
 * Description
 *      printerContext�ǻ��ꤵ�줿������ˡ��ǡ�����񤭹��ߤޤ���
 *      ���ƤΥǡ�����񤭽Ф��ޤǡ��ܴؿ��ϥ֥�å����ޤ���
 *
 * Return Value
 *      ����˽�λ�����OK ���֤���롣���顼�����ä�����-1 ���֤��졢
 *      errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
static int Write(int printerContext, const void *buf, size_t nBytes)
{
        Printer *pl;
        int fd;

        pl = GetPrinter(printerContext);
        if (pl == NULL) {
                /* Printer Context�������Ǥ��� */
                DebugPrint("pdapi: %s,%d\n", __FUNCTION__, __LINE__);
                errorno = FATALERROR;
                return (ERROR);
        }
        
        fd = pl->outputFD;
        while (0 < nBytes) {
                ssize_t wBytes;
                
                wBytes = write(fd, buf, nBytes);
                if (wBytes < 0) {
                        /* �����ƥॳ���륨�顼 */
                        if((errno != EINTR) && (errno != EAGAIN) && (errno != EIO)) {
                                /* ��������ʤ����顼��ȯ������ */
                                DebugPrint("pdapi: %s,%d\n", __FUNCTION__, __LINE__);
                                errorno = FATALERROR;
                                return (ERROR);
                        }
                } else {
                        /* �񤭹������� */
                        buf += wBytes;
                        nBytes -= wBytes;
                }
        }
        return (OK);
}

/* ----------------------------------------------------------------
 *
 *      CheckWrite
 *
 * Name
 *      CheckWrite - StartJob()����λ���Ƥ����硢�ǡ����ν񤭹���(Write())��Ԥ��ޤ�
 *               ��λ���Ƥ��ʤ���硢�ʤˤ⤻�������ｪλ���ޤ�
 *
 * Arguments
 *      printerContext - OpenPrinter �����ֵѤ��줿�ץ�󥿥���ƥ�����
 *                                              �ͤ���ꤹ�롣
 *      buf - �񤭹��ߤ�Ԥ��ǡ����ؤΥݥ���
 *      nBytes - �񤭹��ߤ�Ԥ��ǡ����Υ�����
 *
 * Description
 *      printerContext�ǻ��ꤵ�줿������ˡ��ǡ�����񤭹��ߤޤ���
 *      ���ƤΥǡ�����񤭽Ф��ޤǡ��ܴؿ��ϥ֥�å����ޤ���
 *
 * Return Value
 *      ����˽�λ�����OK ���֤���롣���顼�����ä�����-1 ���֤��졢
 *      errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
static int CheckWrite(int printerContext, const void *buf, size_t nBytes) {

        Printer *pPrinter;
        
        pPrinter = GetPrinter(printerContext);
        if (pPrinter == NULL) {
                errorno = FATALERROR;
                return(ERROR);
        }
        // StartJob�Ͻ�λ���Ƥ��뤫
        if (!pPrinter->jobStarted) {
                // �ޤ����ޥ�ɤ��Ǥ�������ˤʤ�
                return (OK);
        }
        return Write(printerContext, buf, nBytes);
}

/* ----------------------------------------------------------------
 *
 *      CopyBrush
 *
 * Name
 *      CopyBrush -
 *
 * Arguments
 *      pDest - ���ԡ���Brush��¤��
 *      pSrc - ���ԡ���Brush��¤��
 *
 * Description
 *      Brush��¤�ΤΥ��ԡ���Ԥʤ���
 *      Brush��¤�����BrushData��¤�Τ����Ƥ⥳�ԡ�����롣
 *      pDest�ϡ����˳��ݤ��줿��¤�Τ���Ƭ���ɥ쥹�Ǥ��뤳�ȡ�
 *      BrushData.data�ˤĤ��Ƥϡ�̤���ݡ��ȡ����NULL�����ꤵ��롣
 *
 * Return Value
 *      ����˽�λ�����OK ���֤���롣���顼�����ä�����-1 ���֤��졢
 *      errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
static int CopyBrush(Brush *pDest, Brush *pSrc)
{
        if (pDest == NULL || pSrc == NULL) {
                DebugPrint("pdapi: %s,%d pDest=%p or pSrc=%p is NULL.\n", __FUNCTION__, __LINE__, pDest, pSrc);
                errorno = FATALERROR;
                return(ERROR);
        }

        pDest->colorSpace = pSrc->colorSpace;

        pDest->color[0] = pSrc->color[0];
        pDest->color[1] = pSrc->color[1];
        pDest->color[2] = pSrc->color[2];
        pDest->color[3] = pSrc->color[3];

        pDest->xorg = pSrc->xorg;
        pDest->yorg = pSrc->yorg;

        if (pSrc->pbrush) {
                BrushData *pSrcBD;
                BrushData *pDestBD;

                if (pDest->pbrush == NULL) {
                        pDest->pbrush = malloc(sizeof(BrushData));
                        if (pDest->pbrush == NULL) {
                                errorno = FATALERROR;
                                return(ERROR);
                        }
                }
                pSrcBD = pSrc->pbrush;
                pDestBD = pDest->pbrush;

                pDestBD->type = pSrcBD->type;
                pDestBD->width = pSrcBD->width;
                pDestBD->height = pSrcBD->height;
                pDestBD->pitch = pSrcBD->pitch;
                pDestBD->data = NULL; /* Not Supported this Version. */
        }
        else {
                if (pDest->pbrush) {
                        free(pDest->pbrush);
                        pDest->pbrush = NULL;
                }
        }
        return(OK);
}

/* ----------------------------------------------------------------
 *
 *      IsSameBrush
 *
 * Name
 *      IsSameBrush -
 *
 * Arguments
 *      pb1 - Brush��¤��1
 *      pb2 - Brush��¤��2
 *
 * Description
 *      Brush��¤�Τ���Ӥ��롣
 *
 * Return Value
 *      Ʊ��Brush�ξ��TRUE���֤���롣�ۤʤ����FALSE���֤���롣
 *
 * ---------------------------------------------------------------- */
static bool IsSameBrush(Brush *pb1, Brush *pb2)
{
        if (pb1->pbrush == NULL && pb2->pbrush == NULL) {
                if ((pb1->colorSpace == pb2->colorSpace) 
                        && (pb1->color[0] == pb2->color[0]) 
                        && (pb1->color[1] == pb2->color[1]) 
                        && (pb1->color[2] == pb2->color[2]) 
                        && (pb1->color[3] == pb2->color[3])) {
                        return (TRUE);
                }
                return (FALSE);
        }
        /* pbrush != NULL �ξ��Υ����å��Ͼ�ά */
        
        return (FALSE);
}
        

/* ----------------------------------------------------------------
 *
 *      SetPrinterName
 *
 * Name
 *      SetPrinterName - set printer name.
 *
 * Arguments
 *      printerContext - OpenPrinter �����ֵѤ��줿�ץ�󥿥���ƥ�����
 *                                              �ͤ���ꤹ�롣
 *      printerModel - �ץ�󥿥�ǥ�̾����ꤹ��(UTF-8)��
 *                                      NULL �ξ��ϥɥ饤�Ф����ꤹ��ǥե���ȤΥ�ǥ�
 *                                      �Ȥʤ롣
 *
 * Description
 *      �ץ��̾�Τ� Graphics State �����ꤷ��̾�Τˤ�ä�ɬ�פ������Ԥʤ���
 *      �ץ��̾�Τ򥳥ԡ����ƥ�����˻��ġ� (ɬ�פ�����Τ��ʡ�)
 *
 * Return Value
 *      ����˽�λ����ȡ�OK ���֤���롣
 *      ���顼�����ä�����-1 ���֤��졢errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
static int SetPrinterName(int printerContext, char *printerModel)
{

        /* �Ƶ�����θ�ͭ�ξ���ν���������� */
        struct PrinterDeviceInfo_s {
                char    *name;                                  /* �ץ��̾�� (Glue �����Ϥ����̾�Τ�Ʊ��) */
                int     maxRes;                                 /* ��������� */
                int     country;                                /* ���̾��� */
                char    *duplex;                                /* ξ�̰��� */
                char    *face;                                  /* �ե��������� */
        } PrinterDeviceList[] = {
                { "clj4600", RES600, JPN, HP_OPTION_OFF, HP_OPTION_FACE_DOWN },
                { "clj5500", RES600, JPN, HP_OPTION_OFF, HP_OPTION_FACE_DOWN },

                /* default ��������
                 *      ����κǸ�ˤʤ���Фʤ�ʤ�
                 */
                { HP_DEFAULT_PRINTER, RES300, JPN, HP_OPTION_OFF, HP_OPTION_FACE_DOWN },
        };

        DeviceInfo      *dev;
        int                     i;

        DebugPrint("pdapi: %s,%d (printerContext=%d, printerModel=%s\n", __FUNCTION__, __LINE__, printerContext, printerModel);

        dev = GetDeviceInfo(printerContext);
        if (dev == NULL) {
                return(ERROR);
        }

        /* �ץ��̾ */
        /* ����˱����ơ�Ŭ�ڤ������ͤˤ��� */
        for (i = 0; strcmp(PrinterDeviceList[i].name, HP_DEFAULT_PRINTER) != 0; i++) {
                if (printerModel != NULL
                    && strcmp(printerModel, PrinterDeviceList[i].name) == 0) {
                        break;
                }
        }

        dev->printerName = PrinterDeviceList[i].name;
        dev->maxRes =  PrinterDeviceList[i].maxRes;
        dev->country  = PrinterDeviceList[i].country;
        dev->duplex = PrinterDeviceList[i].duplex;
        dev->face = PrinterDeviceList[i].face;

        return(OK);
}


/* ----------------------------------------------------------------
 *
 *      SetBrushData
 *
 * Name
 *      SetBrushData - download a brush data to printer.
 *
 * Arguments
 *      printerContext - OpenPrinter �����ֵѤ��줿�ץ�󥿥���ƥ�����
 *                                              �ͤ���ꤹ�롣
 *      pbrush - Brush����ꤹ�롣
 *      brushID - ����(Stroke, Fill, Background)����ꤹ�롣
 *
 * Description
 *      ���ꤵ�줿BrushData��ץ�󥿤���Ͽ���롣
 *
 * Return Value
 *      ����˽�λ����ȡ�OK ���֤���롣
 *      ���顼�����ä�����-1 ���֤��졢errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
static int SetBrushData(int printerContext, Brush *pbrush, int brushID)
{
        char obuf[64];
        BrushData *pBrushData;
        char *pData;
        int dataSize;
        DeviceInfo *dev;

        pBrushData = pbrush->pbrush;

        /* Enter PCL mode(GL/2 pen position) and specify pattern ID */
        (void)sprintf(obuf, PCL_ESC "%%1A" PCL_ESC "*c%dG", brushID);
        if (CheckWrite(printerContext, obuf, strlen(obuf)) != OK) {
                return(ERROR);
        }

        DebugPrint("width=%d,height=%d\n", pBrushData->width, pBrushData->height);
        dataSize = (pBrushData->width + 7) / 8;
        dataSize *= pBrushData->height;
        dataSize += 12; /* Add header size */

        /* Download pattern */
        (void)sprintf(obuf, PCL_ESC "*c%dW", dataSize);
        if (CheckWrite(printerContext, obuf, strlen(obuf)) != OK) {
                return(ERROR);
        }

        dev = GetDeviceInfo(printerContext);
        if (dev == NULL) {
                return(ERROR);
        }

        pData = malloc(dataSize);
        if (pData == NULL) {
                errorno = FATALERROR;
                return(ERROR);
        }
        
        *(pData + 0) = 20;
        *(pData + 1) = 0;
        *(pData + 2) = 1;
        *(pData + 3) = 0;
        *(pData + 4) = pBrushData->height >> 8;
        *(pData + 5) = pBrushData->height & 0xff;
        *(pData + 6) = pBrushData->width >> 8;
        *(pData + 7) = pBrushData->width & 0xff;
        *(pData + 8) = dev->resolution >> 8;
        *(pData + 9) = dev->resolution & 0xff;
        *(pData + 10) = dev->resolution >> 8;
        *(pData + 11) = dev->resolution & 0xff;
        memcpy(pData + 12, pBrushData->data, dataSize-12);
        if (CheckWrite(printerContext, pData, dataSize) != OK) {
                free(pData);
                return(ERROR);
        }
        free(pData);

        (void)sprintf(obuf, 
                        PCL_ESC "&f0S"  /* Push curent position */
                        PCL_ESC "%%0B"  /* Enter GL/2 mode */
                        "PU%d,%d"       /* Move to brush origin position */
                        PCL_ESC "%%1A"  /* Enter PCL mode(GL/2 pen position) */
                        PCL_ESC "*p0R"  /* Set pattern reference point */
                        PCL_ESC "&f1S"  /* Restore current position */
                        PCL_ESC "%%1B"  /* Enter GL/2 mode(PCL current position) */
                                , pbrush->xorg, pbrush->yorg);
        if (CheckWrite(printerContext, obuf, strlen(obuf)) != OK) {
                return(ERROR);
        }

        return(OK);
}


/* ----------------------------------------------------------------
 *
 *      GetScaleInfo
 *
 * Name
 *      GetScaleInfo - set PCL/GL scaling information.
 *
 * Arguments
 *      pdev - �ץ�󥿤ΥǥХ�������
 *      pscl - ��������󥰾���γ�Ǽ�衣
 *
 * Description
 *      �����٤��ѻ極������ꡢPCL/GL��Scale�ͤ���롣
 *
 * Return Value
 *      ����˽�λ�����OK ���֤���롣���顼�����ä�����-1 ���֤��졢
 *      errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
static int GetScaleInfo(DeviceInfo *pdev, ScaleInfo *pscl)
{
        if (pdev == NULL || pscl == NULL) {
                return(ERROR);
        }

        pscl->glScale_min = HpPaperTable[pdev->pageSize].distdraw * pdev->resolution / RES300;
        pscl->pictFrame_x = (HpPaperTable[pdev->pageSize].width * PCLUNIT / RES300) + 1;
        pscl->pictFrame_y = (HpPaperTable[pdev->pageSize].height * PCLUNIT / RES300) + 1;
        pscl->pictOffs = HpPaperTable[pdev->pageSize].distheight * PCLUNIT / RES300;
        pscl->glScale_x = (HpPaperTable[pdev->pageSize].width * pdev->resolution / RES300) 
                            + pscl->glScale_min;
        pscl->glScale_y = (HpPaperTable[pdev->pageSize].height * pdev->resolution / RES300)
                            + pscl->glScale_min;

        return(OK);
}


/* ----------------------------------------------------------------
 *
 *      OutputCurrentGS
 *
 * Name
 *      OutputCurrentGS - output current Graphics State to printer.
 *
 * Arguments
 *      printerContext - �ץ�󥿥���ƥ������ͤ���ꤹ�롣
 *
 * Description
 *      �����Ȥ� GraphicsState �ǥץ�󥿤� (����) ���ꤹ�롣
 *      RestoreGS �ξ��ʤɤ˸ƤФ�롣
 *
 * Return Value
 *      ����˽�λ����ȡ�OK ���֤���롣
 *      ���顼�����ä�����-1 ���֤��졢errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
// �����Ȥ� GS �����Ƥ�ץ�󥿤����ꤹ��
static int OutputCurrentGS(int printerContext)
{
        GraphicsState   *gs;
        int             result;

        // Get pointer to current GraphicsState.
        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        result = SetFillMode(printerContext, gs->fillMode);
        if (result < 0) {
                return(ERROR);
        }
        result = SetLineWidth(printerContext, gs->lineWidth);
        if (result < 0) {
                return(ERROR);
        }
        result = SetLineCap(printerContext, gs->lineCap);
        if (result < 0) {
                return(ERROR);
        }
        result = SetLineJoin(printerContext, gs->lineJoin);
        if (result < 0) {
                return(ERROR);
        }
        result = SetStrokeColor(printerContext, &gs->strokeBrush);
        if (result < 0) {
                return(ERROR);
        }
        result = SetFillColor(printerContext, &gs->fillBrush);
        if (result < 0) {
                return(ERROR);
        }

        result = SetBgColor(printerContext, &gs->bgBrush);
        if (result < 0) {
                return(ERROR);
        }

        result = SetMiterLimit(printerContext, gs->miterlimit);
        if (result < 0) {
                return(ERROR);
        }

        return(OK);
}

/* ----------------------------------------------------------------
 *
 * Creating and Managing Print Contexts
 *
 * ---------------------------------------------------------------- */

int OpenPrinter(int outputFD, char *printerModel, int *nApiEntry, void *apiEntry[])
{
        int                     printerContext;
        Printer         *printer;
        int                     result;

        DebugPrint("pdapi: %s,%d outputFD=%d, printerModel=%s, nApiEntry=%p, apiEntry=%p\n", __FUNCTION__, __LINE__, outputFD, printerModel, nApiEntry, apiEntry);

        /* device �������ΰ�γ��� */
        printerContext = NewPrinterContext();
        if (printerContext < 0) {
                /* ���顼 */
                errorno = FATALERROR;
                return(ERROR);
        }

        /* ����ͤ����� */

        /* �ؿ�����ȥ�ؤ���Ͽ */
        *apiEntry = VectorProcs;
        *nApiEntry = sizeof(VectorProcs) / sizeof(int);

        /* �ץ��̾�����ꤹ�� */
        result = SetPrinterName(printerContext, printerModel);
        if (result < 0) {
                /* ���顼 */
                errorno = FATALERROR;
                return(ERROR);
        }

        /* ������ */
        printer = GetPrinter(printerContext); 
        printer->outputFD = outputFD;

        return(printerContext);
}


int ClosePrinter(int printerContext)
{
        int             result;

        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        result = DeletePrinterContext(printerContext);

        return(result);
}



typedef struct NByte_s {
        int                             length;         /* Ĺ�� */
        unsigned char   *p;                     /* �Х�����ؤΥݥ��� */
} NByte;



int StartJob(int printerContext, char *jobInfo)
{
        DeviceInfo      *dev;
        char    obuf[128];
        int resolution;
        int pageSize;

        DebugPrint("pdapi: %s,%d (printerContext=%d, jobInfo=[%s])\n",
                           __FUNCTION__,
                           __LINE__,
                           printerContext,
                           jobInfo);

        resolution = 300; // default��
        pageSize = 0;     // default��(HpPaperTable��0����)

        if (jobInfo != NULL) {
                int i;
                char* p;
                char* q;
                char tmp[16]; // TBD

                // resolutionʸ����μ���
                p = &jobInfo[0];
                q = &tmp[0];
                
                while ((*p != '\0') && (*p != ';')) {
                        *q++ = *p++;
                }
                *q = '\0';

                if (strcmp(tmp, "600x600") == 0) {
                        resolution = 600;
                }
                // else resolution = default;

 
                if (p != NULL) {
                        p++;
                }

                q = &tmp[0];
                while ((*p != '\0') && (*p != ';')) {
                        *q++ = *p++;
                }
                *q = '\0';

                i = 0;
                for (i = 0; HpPaperTable[i].name != NULL; i++) {
                        DebugPrint("serching paper size - %d [%s] [%s]\n",
                                           i,
                                           HpPaperTable[i].name,
                                           tmp);
                        if (strcmp(HpPaperTable[i].name, tmp) == 0) {
                                pageSize = i;
                        }
                }
        }

        DebugPrint("pdapi: %s,%d resolution=%d, pagesize=%d[%s]\n",
                           __FUNCTION__,
                           __LINE__,
                           resolution,
                           pageSize,
                           HpPaperTable[pageSize].name);
        
        dev = GetDeviceInfo(printerContext);
        if (dev == NULL) {
                errorno = BADCONTEXT;
                return(ERROR);
        }

        // ������/PaperSize��StartPage()�Ǥ���Ѥ��뤿�ᡢ
        // DeviceInfo�����ꤷ�Ƥ���
        dev->resolution = resolution;
        dev->pageSize = pageSize;

        /**
         * PJL���ޥ�ɤϰ����ǡ���(Job)����Ƭ�ˤ������֤Ǥ��ʤ�
         * PJL���ޥ�ɤΥѥ�᡼����jobInfo�˰�¸���롣
         * jobInfo�����Ƥ˹�碌��PJL���ѹ����롣
         */
        /**
         * ���ޥ�������Τ����Write�ǥ��顼��ȯ����������
         * ³���Բ�ǽ�Ǥ���Τǡ��ʹߤν����ϹԤʤ�ʤ���
         */ 

        sprintf(obuf,
                PCL_ESC "%%-12345X"                     //�귿��
                "@PJL JOB\012"                          //STARTJOB���ޥ��
                "@PJL SET RESOLUTION=%d\012"            //������
                "@PJL SET PAPER=%s\012"                 //�ѻ極����
                "@PJL SET ORIENTATION=PORTRAIT\012"     //Orientation
                "@PJL ENTER LANGUAGE=PCL\015\012",      //���쥹������
                resolution,
                HpPaperTable[pageSize].name);
        if (ERROR == Write(printerContext, obuf, strlen(obuf))) {
                return(ERROR);
        }

        /* ������ȥ쥤 */
        //sprintf(obuf, "@PJL SET OUTBIN=%s\012", dev->face);
        //if (ERROR == Write(printerContext, obuf, strlen(obuf))) {
        //      return(ERROR);
        //}

        /* MEDIASOURCE */
        //p = "@PJL SET AUTOSELECT=ON\012";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* ξ�̰���On/Off */
        //sprintf(obuf, "@PJL SET DUPLEX=%s\012", dev->duplex);
        //if (ERROR == Write(printerContext, obuf, strlen(obuf))) {
        //      return(ERROR);
        //}

        /* QTY */
        //p = "@PJL SET QTY=1\012";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* ���� */
        //p = "@PJL SET COPIES=1\012";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* RIT(RET) */
        //p = "@PJL SET RET=ON\012";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        ///* �ѻ楿���� */
        //p = "@PJL SET MEDIATYPE=PAPER\012";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* EconoMode */
        //p = "@PJL SET ECONOMODE=OFF\012";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* ���� */
        //p = " ZOOM=OFF";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* ���顼������ */
        //p = " ERRORCODE=ON";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* SIZEIGNORE */
        //p = " SIZEIGNORE=OFF";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* ������� */
        //p = " SKIPBLANKPAGE=YES";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* �奪�ե��å� */
        //p = " TOPOFFSET=0";
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* �����ե��å� */
        //p = " LEFTOFFSET=0" "\012"; // SET���ޥ�ɽ�λ
        //if (ERROR == Write(printerContext, p, strlen(p))) {
        //      return(ERROR);
        //}

        /* StartJob()��λ */
        {
                Printer* pPrinter;
                pPrinter = GetPrinter(printerContext);
                if (pPrinter == NULL) {
                        return(ERROR);
                }
                pPrinter->jobStarted = TRUE;
        }

        DebugPrint("pdapi: %s,%d\n", __FUNCTION__, __LINE__);
        /* ��������λ */
        return(OK);
}


int EndJob(int printerContext)
{
        int     result;
        char    *cmd = PCL_ESC "%-12345X";

        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        {
                Printer *pPrinter;
                
                pPrinter = GetPrinter(printerContext);
                if (pPrinter == NULL) {
                        errorno = FATALERROR;
                        return(ERROR);
                }
                pPrinter->jobStarted = FALSE;
        }

        result = Write(printerContext, cmd, strlen(cmd));

        return(result);
}


int StartDoc(int printerContext, char *docInfo)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int EndDoc(int printerContext)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int StartPage(int printerContext, char *pageInfo)
{
        DeviceInfo      *dev;
        char            obuf[128];
        ScaleInfo       scl;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        dev = GetDeviceInfo(printerContext);
        if (dev == NULL) {
                return(ERROR);
        }

        if (ERROR == GetScaleInfo(dev, &scl)) {
                return(ERROR);
        }

        // �ڡ���ñ�̤Υ��ޥ������
        sprintf(obuf, 
                "\033E"                 //RESET���ޥ��
                PCL_ESC "&u%dD"         //PCL Unit���ꥳ�ޥ��
                PCL_ESC "*t%dR"         //�饹�������������ꥳ�ޥ��
                PCL_ESC "&l-%dZ"        //���ե��å����ꥳ�ޥ��
                PCL_ESC "*c%dx%dY"      //�ԥ����㡼�ե졼�����ꥳ�ޥ��
                "\033*c0T"              //���󥫡��ݥ�������ꥳ�ޥ��
                "\033%%0B"              //GL�⡼�ɰܹԥ��ޥ��
                "IN"                    //GL�⡼�� ���˥���饤�����ޥ��
                "SC%d,%d,%d,%d,1",      //GL�⡼�� ������������ꥳ�ޥ��
                dev->resolution,
                dev->resolution,
                scl.pictOffs,
                scl.pictFrame_x, scl.pictFrame_y,
                scl.glScale_min, scl.glScale_x, scl.glScale_y, scl.glScale_min);
        if (ERROR == Write(printerContext, obuf, strlen(obuf))) {
                return(ERROR);
        }

        /* Graphics State �ν������Ԥʤ� */
        if (ERROR == InitGS(printerContext)) {
                return(ERROR);
        }

        return(OK);
}


int EndPage(int printerContext)
{
        char            *cmd = PCL_ESC "E";

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return Write(printerContext, cmd, strlen(cmd));
}



#ifndef OLD_API
/* Ver 0.2 pre���ɲ� */
int QueryDeviceCapability(int printerContext, int queryflag, int buflen, char *infoBuf)
{
        int             result;
        result = 0;
        
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);
        
        return(result);
}


/* Ver 0.2 pre���ɲ� */
int QueryDeviceInfo(int printerContext, int queryflag, int buflen, char *infoBuf)
{
        int             result;
        result = 0;
        
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);
        
        return(result);
}
#endif /* OLD_API */


int ResetCTM(int printerContext)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);
        
        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        /* �ǥե������ */
        {
                CTM ctm;

                ctm.a = 1;
                ctm.b = 0;
                ctm.c = 0;
                ctm.d = 1;
                ctm.e = 0;
                ctm.f = 0;
                SetCTM(printerContext, &ctm);
        }

        return(OK);
}


int SetCTM(int printerContext, CTM *pCTM)
{
        GraphicsState *gs;
        CTM *pCurCTM;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        if (pCTM == NULL) {
                errorno = PARAMERROR;
                return(ERROR);
        }

        // Get pointer to current CTM.
        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        
        pCurCTM = &(gs->ctm);

        {
                // Copy CTM.
                pCurCTM->a = pCTM->a;
                pCurCTM->b = pCTM->b;
                pCurCTM->c = pCTM->c;
                pCurCTM->d = pCTM->d;
                pCurCTM->e = pCTM->e;
                pCurCTM->f = pCTM->f;
        }
        
        return(OK);
}


int GetCTM(int printerContext, CTM *pCTM)
{
        GraphicsState *gs;
        CTM *pCurCTM;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        if (pCTM == NULL) {
                errorno = PARAMERROR;
                return(ERROR);
        }

        // Get pointer to current CTM.
        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        pCurCTM = &(gs->ctm);

        {
                pCTM->a = pCurCTM->a;
                pCTM->b = pCurCTM->b;
                pCTM->c = pCurCTM->c;
                pCTM->d = pCurCTM->d;
                pCTM->e = pCurCTM->e;
                pCTM->f = pCurCTM->f;           
        }

        return(OK);
}


int InitGS(int printerContext)
{

        DebugPrint("pdapi: %s,%d (printerContext=%d)\n", __FUNCTION__, __LINE__, printerContext);

        /* CTM */
        // �ǥե������
        if (ResetCTM(printerContext) != OK) {
                return(ERROR);
        }

        /* ColorSpace */
        // �ǥե������
        if (SetColorSpace(printerContext, cspaceStandardRGB) != OK) {
                return(ERROR);
        }

        /* FillMode */
        // �ǥե������
        if (SetFillMode(printerContext, fillModeEvenOdd) != OK) {
                return(ERROR);
        }
        

        /* LineWidth */
        // �ǥե������(1.0)
        {
                Fix defaultLineWidth;
                i2Fix(1, defaultLineWidth);
                if (SetLineWidth(printerContext, defaultLineWidth) != OK) {
                        return(ERROR);
                }
        }

        /* LineCap */
        // �ǥե������
        if (SetLineCap(printerContext, lineCapButt) != OK) {
                return(ERROR);
        }

        /* LineJoin */
        // �ǥե������
        if (SetLineJoin(printerContext, lineJoinMiter) != OK) {
                return(ERROR);
        }

        /* Brush (Stroke/Fill Common) */
        {
                // Create Default Brush.
                Brush brush;
                int defaultColor[4] = { 0, 0, 0, 0 };
                int defaultBgColor[4] = { 255, 255, 255, 0 };
                GraphicsState *gs;

                // Get pointer to current CTM.
                gs = GetGraphicsState(printerContext);
                if (gs == NULL) {
                        return(ERROR);
                }

                brush.colorSpace = cspaceStandardRGB;

                brush.color[0] = defaultColor[0];
                brush.color[1] = defaultColor[1];
                brush.color[2] = defaultColor[2];
                brush.color[3] = defaultColor[3];

                brush.pbrush = NULL;
                brush.xorg = 0;
                brush.yorg = 0;

                // ����Ʊ����ͤ��������ꤵ��Ƥ���ȥ��ޥ�ɤ��Ǥ��ʤ�����
                // ���ꤷ�褦�Ȥ����ͤȰۤʤ��ͤ��ѹ����Ƥ���������Ū�˽����������
                gs->strokeBrush.colorSpace = !cspaceStandardRGB;
                gs->fillBrush.colorSpace = !cspaceStandardRGB;


                // Set Default Brush.
                if (SetStrokeColor(printerContext, &brush) != OK) {
                        return(ERROR);
                }
                if (SetFillColor(printerContext, &brush) != OK) {
                        return(ERROR);
                }
                brush.color[0] = defaultBgColor[0];
                brush.color[1] = defaultBgColor[1];
                brush.color[2] = defaultBgColor[2];
                brush.color[3] = defaultBgColor[3];

                if (SetBgColor(printerContext, &brush) != OK) {
                        return(ERROR);
                }
                gs->useBgBrush = FALSE;
        }

        /* MiterLimit */
        {
                Fix defaultMiterLimit;
                i2Fix(10, defaultMiterLimit);  /* default miterlimit */
                if (SetMiterLimit(printerContext, defaultMiterLimit) != OK) {
                        return(ERROR);
                }
        }

        /* rop */
        {       
                // �ǥե�����ͤ�252
                if (SetROP(printerContext, 252) != OK) {
                        return (ERROR);
                }
        }

        /* PaintMode */
        {       
                // �ǥե�����ͤ�paintModeOpaque
                if (SetPaintMode(printerContext, paintModeOpaque) != OK) {
                        return (ERROR);
                }
        }

        DebugPrint("pdapi: %s,%d end of InitGS()\n", __FUNCTION__, __LINE__);
        return(OK);
}


int SaveGS(int printerContext)
{
        int             result;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        result = PushGraphicsState(printerContext);

        return(result);
}


int RestoreGS(int printerContext)
{
        int             result;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        result = PopGraphicsState(printerContext);

        if (result < 0) {
                errorno = FATALERROR;
                return(ERROR);
        }

        result = OutputCurrentGS(printerContext);
        if (result < 0) {
                errorno = FATALERROR;
        }

        return(result);
}


int QueryColorSpace(int printerContext, ColorSpace *pcspace, int *pnum)
{
        /* ���ݡ��Ȥ��륫�顼���ڡ��� */
        int     num = 1;
        ColorSpace support[] = { cspaceStandardRGB };

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        /* ���顼���ڡ����ο����֤� */
        if (*pnum < num) {
                *pnum = num;

                errorno = PARAMERROR;
                return (ERROR);
        }

        /* ���顼���ڡ����������֤� */
        *pnum = num;
        {
                int i;
                for (i = 0; i < num; i++) {
                        pcspace[i] = support[i];
                }
        }
        return (OK);
}


int SetColorSpace(int printerContext, ColorSpace cspace)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        gs->colorSpace = cspace;

        return(OK);
}


int GetColorSpace(int printerContext, ColorSpace *pcspace)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        *pcspace = gs->colorSpace;

        return(OK);
}


int QueryROP(int printerContext, int *pnum, int *prop)
{
        DebugPrint("pdapi: %s,%d (printerContext=%d, pnum=%d, prop=%p)\n",
                           __FUNCTION__,
                           __LINE__,
                           printerContext,
                           *pnum,
                           prop);

        // ROP�����ɤ�������䤤��碌
        if (prop == NULL) {
                *pnum = 256;
                return (OK);
        }

        // ���Ѳ�ǽ��ROP�����ɤμ���
        if (*pnum < 256) {
                *pnum = 256; // ɬ�פʸĿ��������
                errorno = PARAMERROR;
                return (ERROR);
        }
        
        // 0����255��256�Ĥ��٤ƤΥ����ɤ�ͭ����
        *pnum = 256;
        {
                int i;
                for (i = 0; i < *pnum; i++) {
                        prop[i] = i;
                }
        }
        return (OK);
}


int SetROP(int printerContext, int rop)
{
        GraphicsState *gs;
        char obuf[128];

        DebugPrint("pdapi: %s,%d (printerContext=%d, rop=%d)\n",
                           __FUNCTION__,
                           __LINE__,
                           printerContext,
                           rop);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        
        // ľ���������ͤ�Ʊ�����ϡ�̵�뤹��
        if (gs->rop == rop) {
                return (OK);
        }

        gs->rop = rop;
        
        (void)sprintf(obuf, "MC0,%d", rop);
        DebugPrint("pdapi: %s,%d comm=[%s]\n", __FUNCTION__, __LINE__, obuf);   
        return CheckWrite(printerContext, obuf, strlen(obuf));
}


int GetROP(int printerContext, int *prop)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d (printerContext=%d, prop=%p)\n",
                __FUNCTION__,
                __LINE__,
                printerContext,
                prop);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        *prop = gs->rop;

        return(OK);
}


int SetFillMode(int printerContext, FillMode fillmode)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        gs->fillMode = fillmode;
        
        return(OK);
}


int GetFillMode(int printerContext, FillMode* pfillmode)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        *pfillmode = gs->fillMode;
        
        return(OK);
}


int SetAlphaConstant(int printerContext, float alpha)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int GetAlphaConstant(int printerContext, float *palpha)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int SetLineWidth(int printerContext, Fix width)
{
        int             i;
        float           f;
        char            obuf[128];
        GraphicsState   *gs;
        DeviceInfo      *dev;

        Fix2f(width, f);
        DebugPrint("pdapi: %s,%d printerContext=%d, width=(%d/%f)\n", __FUNCTION__, __LINE__, printerContext, Fix2i(width), f);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        dev = GetDeviceInfo(printerContext);
        if (dev == NULL) {
                return(ERROR);
        }

        // GraphicState�ι���
        memcpy(&(gs->lineWidth), &width, sizeof(Fix));

        // ����°���ѹ��Υ����ɤ�ץ�󥿤�����
        i= Fix2i(gs->lineWidth);
        if (i <= 0) {
                // ����ͤϥ��꡼���롢0��°���ѹ����Ԥʤ��ʤ�
                f = 1.0;
        }

        f = f/dev->resolution*MMETER_PER_INCH; /* width/Reso*Inch */

        // Line°���ѹ����ޥ�ɤ�����
        (void)sprintf(obuf, "WUPW%f", f);
        DebugPrint("pdapi: %s,%d comm=[%s]\n", __FUNCTION__, __LINE__, obuf);   
        return CheckWrite(printerContext, obuf, strlen(obuf));
}


int GetLineWidth(int printerContext, Fix *pwidth)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        *pwidth = gs->lineWidth;

        return(OK);
}


int SetLineDash(int printerContext, Fix pdash[], int num)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int GetLineDash(int printerContext, Fix pdash[], int *pnum)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int SetLineDashOffset(int printerContext, Fix offset)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int GetLineDashOffset(int printerContext, Fix *poffset)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int SetLineStyle(int printerContext, LineStyle linestyle)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int GetLineStyle(int printerContext, LineStyle *plinestyle)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int SetLineCap(int printerContext, LineCap linecap)
{
        GraphicsState *gs;
        char            obuf[128];
        int             cap;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        // GraphicsContext�ι���
        gs->lineCap = linecap;
        
        switch (gs->lineCap) {
                case lineCapButt:
                        cap = 1;
                        break;
                case lineCapRound:
                        cap = 4;
                        break;
                case lineCapSquare:
                        cap = 2;
                        break;
                default:
                        cap = 3; // Triangular
                        break;
        }
        
        // Line°���ѹ����ޥ�ɤ�����
        (void)sprintf(obuf, "LA1,%d", cap);
        DebugPrint("pdapi: %s,%d comm=[%s]\n", __FUNCTION__, __LINE__, obuf);   
        return CheckWrite(printerContext, obuf, strlen(obuf));
}


int GetLineCap(int printerContext, LineCap *plinecap)
{
        GraphicsState *gs;
        
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        
        *plinecap = gs->lineCap;

        return(OK);
}


int SetLineJoin(int printerContext, LineJoin linejoin)
{
        GraphicsState *gs;
        char                    obuf[128];
        int                     join;
        
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        // GraphicsContext�ι���
        gs->lineJoin = linejoin;

        switch (gs->lineJoin) {
                case lineJoinMiter:
                        join = 1;
                        break;
                case lineJoinRound:
                        join = 4;
                        break;
                case lineJoinBevel:
                        join = 5;
                        break;
                default:
                        join = 3;
                        break;
        }

        // Line°���ѹ����ޥ�ɤ�����
        (void)sprintf(obuf, "LA2,%d", join);
        DebugPrint("pdapi: %s,%d comm=[%s]\n", __FUNCTION__, __LINE__, obuf);   
        return CheckWrite(printerContext, obuf, strlen(obuf));
}


int GetLineJoin(int printerContext, LineJoin *plinejoin)
{
        GraphicsState *gs;
        
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        
        *plinejoin = gs->lineJoin;
        return(OK);
}


int SetMiterLimit(int printerContext, Fix miterlimit)
{
        GraphicsState *gs;
        char obuf[128];
        float f;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        // GraphicState�ι���
        memcpy(&(gs->miterlimit), &miterlimit, sizeof(Fix));
        
        Fix2f(miterlimit, f);

        // Line°���ѹ����ޥ�ɤ�����
        (void)sprintf(obuf, "LA3,%f", f);
        DebugPrint("pdapi: %s,%d comm=[%s]\n", __FUNCTION__, __LINE__, obuf);   
        return CheckWrite(printerContext, obuf, strlen(obuf));
}


int GetMiterLimit(int printerContext, Fix *pmiterlimit)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        
        *pmiterlimit = gs->miterlimit;

        return(OK);
}


int SetPaintMode(int printerContext, PaintMode paintmode)
{
        GraphicsState *gs;
        char obuf[128];

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        
        gs->paintMode = paintmode;

        if (paintmode == paintModeOpaque) {
                (void)sprintf(obuf, "TR0");
        }
        else {
                (void)sprintf(obuf, "TR1");
        }
        DebugPrint("pdapi: %s,%d comm=[%s]\n", __FUNCTION__, __LINE__, obuf);   
        return CheckWrite(printerContext, obuf, strlen(obuf));
}


int GetPaintMode(int printerContext, PaintMode *ppaintmode)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }
        
        *ppaintmode = gs->paintMode;

        return(OK);
}


int SetStrokeColor(int printerContext, Brush *brush)
{

        DebugPrint("pdapi: %s,%d printerContext=%d brush.color[1]=%X brush.color[2]=%X brush.color[3]=%X\n", __FUNCTION__, __LINE__, printerContext, brush->color[1], brush->color[2], brush->color[3]);

        GraphicsState *gs;

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        // ľ����Brush��Ʊ�����ϡ�̵�뤹��
        if (IsSameBrush(&(gs->strokeBrush), brush)) {
                return(OK);
        }
        
        // ��Brush�����Ƥ�GraphicsState�ǻ���Brush�ΰ�˥��ԡ�����
        if (CopyBrush(&(gs->strokeBrush), brush)) {
                return(ERROR);
        }
        
        /* ���ޥ�ɤ����� */
        {
                char obuf[64];

                // �ڥ󥫥顼����
                (void)sprintf(obuf, "PC%d,%d,%d,%d",            // PC�͸�ľ��
                                          HP_COLOR_ID_STROKE,
                                          (unsigned char)brush->color[2],
                                          (unsigned char)brush->color[1],
                                          (unsigned char)brush->color[0]);
                if (CheckWrite(printerContext, obuf, strlen(obuf)) != OK) {
                        return(ERROR);
                }
        }

        if (brush->pbrush != NULL) {
                if (SetBrushData(printerContext, brush, HP_COLOR_ID_STROKE) != OK) {
                        errorno = FATALERROR;
                        return(ERROR);
                }
        }

        return (OK);
}

        
int SetFillColor(int printerContext, Brush *brush)
{

        DebugPrint("pdapi: %s,%d printerContext=%d brush.color[1]=%X brush.color[2]=%X brush.color[3]=%X\n", __FUNCTION__, __LINE__, printerContext, brush->color[1], brush->color[2], brush->color[3]);

        GraphicsState *gs;

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        // ľ����Brush��Ʊ�����ϡ�̵�뤹��
        if (IsSameBrush(&(gs->fillBrush), brush)) {
                return(OK);
        }
        
        /* ��Brush�����Ƥ�GraphicsState�ǻ���Brush�˥��ԡ����� */
        if (CopyBrush(&(gs->fillBrush), brush)) {
                return(ERROR);
        }
        
        /* ���ޥ�ɤ����� */
        {
                
                char obuf[64];

                // �ڥ󥫥顼����
                (void)sprintf(obuf, "PC%d,%d,%d,%d",            // PC�͸�ľ��
                                      HP_COLOR_ID_FILL,
                                          (unsigned char)brush->color[2],
                                          (unsigned char)brush->color[1],
                                          (unsigned char)brush->color[0]);
                if (CheckWrite(printerContext, obuf, strlen(obuf)) != OK) {
                        return(ERROR);
                }
        }

        if (brush->pbrush != NULL) {
                if (SetBrushData(printerContext, brush, HP_COLOR_ID_FILL) != OK) {
                        errorno = FATALERROR;
                        return(ERROR);
                }
        }

        return (OK);
}


int SetBgColor(int printerContext, Brush *brush)
{
        DebugPrint("pdapi: %s,%d printerContext=%d brush.color[1]=%X brush.color[2]=%X brush.color[3]=%X\n", __FUNCTION__, __LINE__, printerContext, brush->color[1], brush->color[2], brush->color[3]);

        GraphicsState *gs;

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return(ERROR);
        }

        // ľ����Brush��Ʊ�����ϡ�̵�뤹��
        if (IsSameBrush(&(gs->bgBrush), brush)) {
                return(OK);
        }
        

        CopyBrush(&(gs->bgBrush), brush);

        return(OK);
}



/* ----------------------------------------------------------------
 *
 * Path Operations
 *
 * ---------------------------------------------------------------- */

/* �ѥ�����Ͽ�ֹ� */
typedef enum HPPathId_e {
        HP_PATH_ID_PRINT = 0,
        HP_PATH_ID_CLIP = 1
} HPPathId;

/* �ѥ���������� */
typedef enum HPPathType {
        HP_PATH_TYPE_STROKE = 0,
        HP_PATH_TYPE_FILL = 1,
        HP_PATH_TYPE_STROKEFILL = 2,
        HP_PATH_TYPE_CLIP = 3
} HPPathType;

static int FlashPath(int printerContext, unsigned char id, HPPathType type);
static int CommitRectanglePath(int printerContext, Point point0, Point point1, Fix xellipse, Fix yellipse);


/* ----------------------------------------------------------------
 *
 *      FlashPath
 *
 * Name
 *      FlashPath - �����ȥѥ����ۤ����޷������褹��
 *
 * Arguments
 *      printerContext - OpenPrinter()������줿�ץ�󥿥���ƥ����Ȥ�
 *                                      ���ꤹ�롣
 *      id - �ѥ���Ͽ�ֹ�
 *           (Note) �������ѥ�������Ǥ�ID=0�Τߤ���Ѥ��Ƥ��뤬������
 *           ���Ϥ�ID����Ĥ������ɤ��Τ���Ƚ�Ǥ��Ĥ��ʤ��١������ǽ
 *           �ˤ��Ƥ���
 *      type - �������
 *
 * Description
 *      �����ȥѥ����ۤ����޷������褷�ޤ���������GraphicsState
 *      (current path�ޤ�)���ݻ�����ޤ���
 *      
 *
 * Return Value
 *      ����˽�λ�����OK ���֤���롣���顼�����ä�����-1 ���֤��졢
 *      errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
static int FlashPath(int printerContext, unsigned char id, HPPathType type)
{
        GraphicsState *gs;
        char obuf[64] = "";
        ItemList *node;
        int param;
        int result;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context�������Ǥ��� */
                return (ERROR);
        }

        /* ���ֳ�ǧ */
        if (gs->pathActive == TRUE) {
                /* �ѥ����������Ǥ���(EndPath���ƤФ�Ƥ��ʤ�) */
                errorno = BADREQUEST;
                return (ERROR);
        } else if (gs->pathList == NULL) {
                /* �ѥ��ꥹ�Ȥ�¸�ߤ��ʤ� */
                return (OK);
        }

        switch (type) {
                case HP_PATH_TYPE_STROKE:
                case HP_PATH_TYPE_STROKEFILL:
                        /* �ѥ����襳�ޥ�� */
                        if (!gs->strokeBrush.pbrush) {
                                (void)sprintf(obuf, "SP%dEP", HP_COLOR_ID_STROKE);
                        }
                        else {
                                (void)sprintf(obuf, "SP%dSV22,%dEP", HP_COLOR_ID_STROKE, HP_COLOR_ID_STROKE);
                        }
                        if (type == HP_PATH_TYPE_STROKE) {
                                break;
                        }
                        /* if HP_PATH_TYPE_STROKEFILL fall through!! */

                case HP_PATH_TYPE_FILL:
                        if (gs->fillMode == fillModeEvenOdd) {
                                /* �ѥ����襳�ޥ�� */
                                if (!gs->fillBrush.pbrush) {
                                        (void)sprintf(obuf+strlen(obuf), "SP%dFP", HP_COLOR_ID_FILL);
                                }
                                else {
                                        (void)sprintf(obuf+strlen(obuf), "SP%dFT22,%dFP", 
                                                                HP_COLOR_ID_FILL, HP_COLOR_ID_FILL);
                                }
                        } else if (gs->fillMode == fillModeWinding) {
                                /* �ѥ����襳�ޥ�� */
                                if (!gs->fillBrush.pbrush) {
                                        (void)sprintf(obuf+strlen(obuf), "SP%dFP1;", HP_COLOR_ID_FILL);
                                }
                                else {
                                        (void)sprintf(obuf+strlen(obuf), "SP%dFT22,%dFP1;", 
                                                                HP_COLOR_ID_FILL, HP_COLOR_ID_FILL);
                                }
                        } else {
                                /* ���ݡ��Ȥ��Ƥ��ʤ�path mode�����򤵤줿 */
                                errorno = NOTSUPPORTED;
                                return (ERROR);
                        }
                        break;
                        
                case HP_PATH_TYPE_CLIP:
                        if (gs->fillMode == fillModeEvenOdd) {
                                param = 0;
                                (void)sprintf(obuf, " ");
                        } else if (gs->fillMode == fillModeWinding) {
                                param = 0;
                                (void)sprintf(obuf, " ");
                        } else {
                                /* ���ݡ��Ȥ��Ƥ��ʤ�path mode�����򤵤줿 */
                                errorno = NOTSUPPORTED;
                                return (ERROR);
                        }
                        break;

                default:
                        /* ���ݡ��Ȥ��Ƥ��ʤ�path type�����򤵤줿 */
                        errorno = NOTSUPPORTED;
                        return (ERROR);
        }

        /* �ꥹ�ȤκǸ����˥��ޥ�ɤ��ɲ� */
        /* ���λ������Ĥ����Ƥ��ʤ��ѥ��ϡ����ۤ�����Ĥ����� */
        gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
        if (gs->pathEndPoint == NULL) {
                return (ERROR);
        }

        /* �ѥ���FD�ؽ񤭽Ф� */
        node = gs->pathList;
        while (node != NULL) {
                result = CheckWrite(printerContext, node->item, node->length);
                if (result != OK) {
                        /* �񤭹��߼��� */
                        return (ERROR);
                }
                node = node->next;
        }

        return (OK);
}


/* ----------------------------------------------------------------
 *
 *      CommitRectanglePath
 *
 * Name
 *      CommitRectanglePath - ����ѥ���ѥ��ꥹ����Ͽ����
 *
 * Arguments
 *      printerContext - OpenPrinter()������줿�ץ�󥿥���ƥ����Ȥ���ꤹ�롣
 *      point0 - ������
 *      point1 - �г���
 *      xellipse - �ʱߤο�ʿ������Ĺ��
 *      yellipse - �ʱߤο�ľ������Ĺ��
 *
 * Description
 *      Rectangle��ѥ����ɲä��롣
 *      Corner��xellipse�����yellipse��ɽ��������ʱ߸̤ˤ�ä���³����롣
 *
 * Return Value
 *      ����˽�λ�����OK ���֤���롣���顼�����ä�����-1 ���֤��졢
 *      errorno �˥��顼�����ɤ���Ǽ����롣
 *
 * ---------------------------------------------------------------- */
static int CommitRectanglePath(int printerContext, Point point0, Point point1, Fix xellipse, Fix yellipse)
{
        GraphicsState *gs;
        char obuf[64];

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context�������Ǥ��� */
                return (ERROR);
        }

        (void)sprintf(obuf, "PU%d,%d",
                      (int)ApplyCtmX_Integer((point0.x), (point0.y), gs->ctm),
                      (int)ApplyCtmY_Integer((point0.x), (point0.y), gs->ctm));
                                        
        if (CheckWrite(printerContext, obuf, strlen(obuf)) != OK) {
                return(ERROR);
        }

        /* ������襳�ޥ�� */
        (void)sprintf(obuf, "PD%d,%d,%d,%d,%d,%d,%d,%d",
                      (int)ApplyCtmX_Integer((point0.x), (point1.y), gs->ctm),
                      (int)ApplyCtmY_Integer((point0.x), (point1.y), gs->ctm),
                      (int)ApplyCtmX_Integer((point1.x), (point1.y), gs->ctm),
                      (int)ApplyCtmY_Integer((point1.x), (point1.y), gs->ctm),
                      (int)ApplyCtmX_Integer((point1.x), (point0.y), gs->ctm),
                      (int)ApplyCtmY_Integer((point1.x), (point0.y), gs->ctm),
                      (int)ApplyCtmX_Integer((point0.x), (point0.y), gs->ctm),
                      (int)ApplyCtmY_Integer((point0.x), (point0.y), gs->ctm));
        
        /* �ѥ����ɲä��� */
        gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
        if (gs->pathEndPoint == NULL) {
                return (ERROR);
        }
        return(OK);
}


int NewPath(int printerContext)
{
        GraphicsState *gs;
        char obuf[64];

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context�������Ǥ��� */
                return (ERROR);
        }

        /* �Ť��ѥ����ĤäƤ���к�������������ѥ��򳫻Ϥ��롣path��
           �ϥ��ޥ�ɤϡ��ѥ���񤭽Ф�ľ���˥ѥ�᡼���򥻥åȤ���ɬ
           �פ�����Τǡ������Ǥ϶��ˤ��Ƥ��� */
        if (gs->pathList != NULL) {
                DeleteListAll(gs->pathList);
        }
        gs->pathList = NewList("", 0);
        if (gs->pathList == NULL) {
                errorno = FATALERROR;
                return (ERROR);
        }

        /* �ѥ���������Ǥ�����򼨤��ե饰�򥻥å� */
        gs->pathActive = TRUE;

        /* ������ꥳ�ޥ�� */
        (void)sprintf(obuf, "PM0");

        /* �ꥹ�ȤκǸ����˥��ޥ�ɤ��ɲ� */
        gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
        if (gs->pathEndPoint == NULL) {
                return (ERROR);
        }
        
        return (OK);
}


int EndPath(int printerContext)
{
        GraphicsState *gs;
        char obuf[64];

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context�������Ǥ��� */
                return (ERROR);
        }

        if (gs->pathActive != TRUE) {
                /* NewPath���ƤФ�Ƥ��ʤ��Τˡ�EndPath���ƤФ줿 */
                errorno = BADREQUEST;
                return (ERROR);
        }

        /* �ѥ���Ͽ��λ���ޥ�� */
        (void)sprintf(obuf, "PM2");

        /* �ꥹ�ȤκǸ����˥��ޥ�ɤ��ɲ� */
        gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
        if (gs->pathEndPoint == NULL) {
                return (ERROR);
        }

        /* �ѥ����꤬��λ���Ƥ�����򼨤��ե饰�򥻥å� */
        gs->pathActive = FALSE;
        return (OK);
}


int StrokePath(int printerContext)
{
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return FlashPath(printerContext, HP_PATH_ID_PRINT, HP_PATH_TYPE_STROKE);
}


int FillPath(int printerContext)
{
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);
        
        return FlashPath(printerContext, HP_PATH_ID_PRINT, HP_PATH_TYPE_FILL);
}


int StrokeFillPath(int printerContext)
{
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return FlashPath(printerContext, HP_PATH_ID_PRINT, HP_PATH_TYPE_STROKEFILL);
}


int SetClipPath(int printerContext, ClipRule clipRule)
{
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(OK);
}


#ifndef OLD_API
/* Ver 0.2 pre���ɲ� */
int ResetClipPath( int printerContext)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}
#endif /* OLD_API */


int SetCurrentPoint(int printerContext, Fix x, Fix y)
{
        GraphicsState *gs;
        char obuf[64];

        DebugPrint("pdapi: %s,%d printerContext=%d, x=%d, y=%d\n", __FUNCTION__, __LINE__, printerContext, Fix2i(x), Fix2i(y));

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context�������Ǥ��� */
                return (ERROR);
        }

        if ((gs->pathActive == FALSE) || 
            ((gs->pathActive == TRUE) && (gs->pathList->next == gs->pathEndPoint))) {
                /* �����ȥݥ���Ȼ��ꥳ�ޥ�� */
                (void)sprintf(obuf, "PU%d,%d",
                              (int)ApplyCtmX_Integer(x, y, gs->ctm),
                              (int)ApplyCtmY_Integer(x, y, gs->ctm));

                if (CheckWrite(printerContext, obuf, strlen(obuf)) != OK) {
                        return(ERROR);
                }
        } else {
                /* �����ȥݥ���Ȼ��ꥳ�ޥ�� */
                (void)sprintf(obuf, "PM1PU%d,%d",
                              (int)ApplyCtmX_Integer(x, y, gs->ctm),
                              (int)ApplyCtmY_Integer(x, y, gs->ctm));

                /* �ꥹ�ȤκǸ����˥��ޥ�ɤ��ɲ� */
                gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
                if (gs->pathEndPoint == NULL) {
                        return (ERROR);
                }
        }
        return (OK);
}


int LinePath(int printerContext, int flag, int npoints, Point *points)
{
        GraphicsState *gs;
        char obuf[2048];
        int i;
        int max = npoints - 1;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);
        
        if (npoints < 1) {
                /* ĺ���������� */
                return (ERROR);
        }

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context�������Ǥ��� */
                return (ERROR);
        }

        if (flag == PathClose) {
                (void)sprintf(obuf, "PD");

                /* �ꥹ�ȤκǸ����˥��ޥ�ɤ��ɲ� */
                gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
                if (gs->pathEndPoint == NULL) {
                        return (ERROR);
                }
        } else {
                (void)sprintf(obuf, "PD");

                for (i = 0; i < max; i++) {
                        (void)sprintf(obuf+strlen(obuf), "%d,%d,",
                                (int)ApplyCtmX_Integer((points[i].x), (points[i].y), gs->ctm), /* x */
                                (int)ApplyCtmY_Integer((points[i].x), (points[i].y), gs->ctm)); /* y */
                }
                (void)sprintf(obuf+strlen(obuf), "%d,%dPU",
                        (int)ApplyCtmX_Integer((points[max].x), (points[max].y), gs->ctm), /* x */
                        (int)ApplyCtmY_Integer((points[max].x), (points[max].y), gs->ctm)); /* y */
                                        
                /* �ꥹ�ȤκǸ����˥��ޥ�ɤ��ɲ� */
                gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
                if (gs->pathEndPoint == NULL) {
                        return (ERROR);
                }
        }
        return (OK);
}


int PolygonPath(int printerContext, int npolygons, int *nvertexes, Point *points)
{
        GraphicsState *gs;
        int i;
        char obuf[2048];
        
        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context�������Ǥ��� */
                return (ERROR);
        }

        for (i = 0; i < npolygons; i++) 
        {
                int index = ((i == 0) ? 0 : nvertexes[i-1]);
                int p;
                (void)sprintf(obuf, "PU%d,%dPD",
                        (int)ApplyCtmX_Integer((points[index+0].x), (points[index+0].y), gs->ctm), /* x */
                        (int)ApplyCtmY_Integer((points[index+0].x), (points[index+0].y), gs->ctm)); /* y */

                for (p = 1; p < nvertexes[i]; p++) 
                {
                        (void)sprintf(obuf+strlen(obuf), "%d,%d,",
                                (int)ApplyCtmX_Integer((points[index+p].x), (points[index+p].y), gs->ctm), /* x */
                                (int)ApplyCtmY_Integer((points[index+p].x), (points[index+p].y), gs->ctm)); /* y */

                }
                (void)sprintf(obuf+strlen(obuf), "%d,%d",
                        (int)ApplyCtmX_Integer((points[index+0].x), (points[index+0].y), gs->ctm), /* x */
                        (int)ApplyCtmY_Integer((points[index+0].x), (points[index+0].y), gs->ctm)); /* y */

        }
        (void)sprintf(obuf+strlen(obuf), "PU");

        /* �ꥹ�ȤκǸ����˥��ޥ�ɤ��ɲ� */
        gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
        if (gs->pathEndPoint == NULL) {
                return (ERROR);
        }

        return(OK);
}


int RectanglePath(int printerContext, int nrectangles, Rectangle *rectangles)
{
        Fix fix0;
        int i;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        if (nrectangles <= 0) {
                /* ����������� */
                errorno = PARAMERROR;
                return (ERROR);
        }

        memset(&fix0, 0, sizeof(Fix));
        for (i = 0; i < nrectangles; i++) {
                int result;
                
                result = CommitRectanglePath(printerContext, rectangles[i].p0, rectangles[i].p1, fix0, fix0);
                if (result != OK) {
                        return (ERROR);
                }
        }
        return(OK);
}


int RoundRectanglePath(int printerContext, int nrectangles, RoundRectangle *rectangles)
{
        int i;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        if (nrectangles <= 0) {
                /* ����������� */
                errorno = PARAMERROR;
                return (ERROR);
        }

        for (i = 0; i < nrectangles; i++) {
                int result;
                
                result = CommitRectanglePath(printerContext, rectangles[i].p0, rectangles[i].p1,
                                             rectangles[i].xellipse, rectangles[i].yellipse);
                if (result != OK) {
                        return (ERROR);
                }
        }
        return(OK);
}


#ifdef OLD_API
int BezierPath(int printerContext, int *npoints, Point *points)
#else
int BezierPath(int printerContext, int npoints, Point *points)
#endif /* OLD_API */
{
        GraphicsState *gs;
        char obuf[4096];
        int offset;
#ifdef OLD_API
        int count;
        int i;
#else
        int max = npoints - 1;
#endif /* OLD_API */
        int j;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        /* ��������Ф�(�Ĥ��Ǥ˥ѥ�᡼����ǧ) */
#ifdef OLD_API
        for (count = 0; npoints[count] != 0; count++) {
/*              if (((npoints[count]) % 3) != 0) { */
/*                      /\* �������������ĺ������3���ܿ��Ǥʤ� *\/ */
/*                      DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__); */
/*                      return (ERROR); */
/*              } */
        }
#else
        if ((npoints % 3) != 0) {
                /* �������������ĺ������3���ܿ��Ǥʤ� */
                errorno = PARAMERROR;
                return (ERROR);
        }
#endif /* OLD_API */

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context�������Ǥ��� */
                return (ERROR);
        }

        offset = 0;
#ifdef OLD_API
        for (i = 0; npoints[i] != 0; i++) {
                offset ++;
#endif /* OLD_API */
                /* Bezier�����ɲå��ޥ��(suffix) */
                (void)sprintf(obuf, "PDBZ");
                
#ifdef OLD_API
                for (j = 1; j < npoints[i]-1; j++) {
#else
                for (j = 0; j < max; j++) {
#endif /* OLD_API */
                        (void)sprintf(obuf+strlen(obuf), "%d,%d,",
                                (int)ApplyCtmX_Integer((points[offset].x), (points[offset].y), gs->ctm), /* x */
                                (int)ApplyCtmY_Integer((points[offset].x), (points[offset].y), gs->ctm)); /* y */
                        offset ++;
                }
                (void)sprintf(obuf+strlen(obuf), "%d,%dPU",
                        (int)ApplyCtmX_Integer((points[offset].x), (points[offset].y), gs->ctm), /* x */
                        (int)ApplyCtmY_Integer((points[offset].x), (points[offset].y), gs->ctm)); /* y */
                                        
                /* �ꥹ�ȤκǸ����˥��ޥ�ɤ��ɲ� */
                gs->pathEndPoint = AddList(gs->pathList, obuf, strlen(obuf));
                if (gs->pathEndPoint == NULL) {
                        return (ERROR);
                }

#ifdef OLD_API
                }
#endif /* OLD_API */

        return(OK);

}


int ArchPath(int printerContext, int kind, int dir, Fix bbx0, Fix bby0, Fix bbx1, Fix bby1, Fix x0, Fix y0, Fix x1, Fix y1)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}



/* ----------------------------------------------------------------
 *
 * Raw Data Operations
 *
 * ---------------------------------------------------------------- */
static int StartRaws(int printerContext, int sourceWidth, int sourceHeight, int colorDepth, int destinationWidth, int destinationHeight);
static int WriteRaws(int printerContext, int ndata, void *rawsData);
static int EndRaws(int printerContext);

static int StartRaws(int printerContext, int sourceWidth,
                    int sourceHeight, int colorDepth,
                    int destinationWidth, int destinationHeight)
{
        GraphicsState *gs;
        char obuf[64];
        unsigned long
        int result;
        DeviceInfo *dev;

	gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context������
                   �Ǥ��� */
                return (ERROR);
        }

        dev = GetDeviceInfo(printerContext);
        if (dev == NULL) {
                return(ERROR);
        }

        /* PCL�⡼�ɰܹ� */
        (void)sprintf(obuf, PCL_ESC "%%1A" PCL_ESC "*p0P");
        result = CheckWrite(printerContext, obuf, strlen(obuf));
        if (result != OK) return (ERROR);

        if (colorDepth == 1) {
                result = CheckWrite(printerContext, PCL_ESC "*v6W\00\01\01\00\00\00", 11);
                if (result != OK) return (ERROR);

                if ((gs->fillBrush.color[2] & 255) == 255
                        && (gs->fillBrush.color[1] & 255) == 255
                        && (gs->fillBrush.color[0] & 255) == 255) {
                        (void)sprintf(obuf,
                                      PCL_ESC "*v%da%db%dc1I",
                                      254, 254, 254);
                } else {
                        (void)sprintf(obuf,
                                      PCL_ESC "*v%da%db%dc1I",
                                      (unsigned char)gs->fillBrush.color[2],
                                      (unsigned char)gs->fillBrush.color[1],
                                      (unsigned char)gs->fillBrush.color[0]);
                }
                result = CheckWrite(printerContext, obuf, strlen(obuf));
                if (result != OK) return (ERROR);
        } else if (colorDepth == 4) {
                /* (TBD) */
        } else if (colorDepth == 8) {
                /* (TBD) */
        } else if (colorDepth == 24) {
                result = CheckWrite(printerContext, PCL_ESC "*v6W\00\03\00\10\10\10", 11);
                if (result != OK) return (ERROR);
        } else {
                /* ���ݡ��Ȥ��ʤ�depth���Ϥ��줿 */
                return (ERROR);
        }

        (void)sprintf(obuf,
                      PCL_ESC "*r%ds%dT"
                      PCL_ESC "*r1A",
                      destinationWidth,         /* ���������� */
                      destinationHeight);       /* �������ι⤵ */

        result =  CheckWrite(printerContext, obuf, strlen(obuf));
        if (result != OK) {
                return (ERROR);
        }

        gs->imageWidth = sourceWidth;
        gs->imageHeight = sourceHeight;
        gs->imageDepth = colorDepth;
        gs->imageDestWidth = destinationWidth;
        gs->imageDestHeight = destinationHeight;

        return (OK);
}

static int WriteRaws(int printerContext, int ndata, void *rawsData)
{
        GraphicsState *gs;
        char obuf[64];
        char *writeData;
        int i;
        int bytes_pre_pixel;
        unsigned int width_bytes;
        unsigned int prt_width_bytes;
        int result;
        double mag;

        if (ndata == 0) {
                /* ��������̵�� */
                return (OK);
        }

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context������
                   �Ǥ��� */
                return (ERROR);
        }

        /* �饹����ΥХ��ȿ� */
        width_bytes = ndata / gs->imageHeight;

        if (gs->imageDestWidth != gs->imageWidth) {

                /* 1pixel�դ�ΥХ��ȿ� */
                if (gs->imageDepth < 24) {
                        bytes_pre_pixel = 1;
                } else {
                        bytes_pre_pixel = 3;
                }

                /* ����/�̾���Υ饹����ΥХ��ȿ� */
                if (gs->imageDepth == 1) {
                        prt_width_bytes = (gs->imageDestWidth + 7) >> 3;
                } else {
                        prt_width_bytes = gs->imageDestWidth * bytes_pre_pixel;
                }

                writeData = (char *)malloc(prt_width_bytes * gs->imageHeight);
                if (writeData == NULL) {
                        errorno = FATALERROR;
                        return (ERROR);
                }

                mag = (double)gs->imageDestWidth / (double)gs->imageWidth;

                if (gs->imageDepth == 1) {
                        memset(writeData, 0x0, prt_width_bytes * gs->imageHeight);
                        for (i = 0; i < gs->imageHeight; i++) {
                                int j;
                                unsigned char *pDest = writeData + (prt_width_bytes * i);
                                unsigned char *pSrc = rawsData + (width_bytes * i);
                                for (j = 0; j < gs->imageDestWidth; j++) {
                                        int index = (int)(j / mag);
                                        unsigned char bit = (*(pSrc + index / 8) >> (7 - (index % 8))) & 0x1;
                                        *(pDest + j / 8) |= bit << (7 - (j % 8));
                                }
                        }
                }
                else {
                        memset(writeData, 0xff, prt_width_bytes * gs->imageHeight);
                        for (i = 0; i < gs->imageHeight; i++) {
                                int j;
                                char *pDest = writeData + (prt_width_bytes * i);
                                char *pSrc = rawsData + (width_bytes * i);
                                for (j = 0; j < gs->imageDestWidth; j++) {
                                        char *p = pSrc + (int)(j / mag) * bytes_pre_pixel;
                                        *pDest++ = *p++;
                                        *pDest++ = *p++;
                                        *pDest++ = *p;
                                }
                        }
                }
        }
        else {
                writeData = rawsData;
                prt_width_bytes = width_bytes;
        }

        DebugPrint("pdapi: %s,%d ndata=%d gs->imageHeight=%d prt_width_bytes=%d width_bytes=%d\n",
                   __FUNCTION__, __LINE__, ndata, gs->imageHeight, prt_width_bytes, width_bytes);

        /* �饹��ž�� */
        mag = (double)gs->imageDestHeight / (double)gs->imageHeight;
        for (i = 0; i < gs->imageDestHeight; i++) {
                (void)sprintf(obuf, PCL_ESC "*b%dW", prt_width_bytes);
                result = CheckWrite(printerContext, obuf, strlen(obuf));
                if (result != OK) {
                        break;
                }

                result = CheckWrite(printerContext,
                                        writeData + (prt_width_bytes * (int)(i / mag)), prt_width_bytes);
                if (result != OK) {
                        break;
                }
        }
        if (gs->imageDestWidth != gs->imageWidth) {
                free(writeData);
        }
        return (result);
}

static int EndRaws(int printerContext)
{
        char obuf[64];

        /* GL2�⡼�ɰܹ� */
        (void)sprintf(obuf, PCL_ESC "*rC" PCL_ESC "*p1P" PCL_ESC "%%0B");
        return CheckWrite(printerContext, obuf, strlen(obuf));
}



/* ----------------------------------------------------------------
 *
 * Text Operations
 *
 * ---------------------------------------------------------------- */

int DrawBitmapText(int printerContext, int width, int height, int pitch, void *fontdata)
{
        GraphicsState *gs;
        char obuf[64];
        Fix x;
        Fix y;
        int i;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                return (ERROR);
        }

        i2Fix(0, x);
        i2Fix(-height, y);
        /* Move current point from bottom left to top left. */
        (void)sprintf(obuf, "PRPD%d,%dPA",
                                (int)ApplyCtmX_Integer(x, y, gs->ctm), /* x */
                                (int)ApplyCtmY_Integer(x, y, gs->ctm)); /* y */
        if (OK != CheckWrite(printerContext, obuf, strlen(obuf))) {
                return (ERROR);
        }

        gs->useBgBrush = TRUE;
        if (OK != StartRaster(printerContext, width)) {
                gs->useBgBrush = FALSE;
                return (ERROR);
        }
        gs->useBgBrush = FALSE;

        pitch >>= 3;
        for (i = 0; i < height; i++)
        {
                if (OK != TransferRasterData(printerContext, pitch, fontdata + pitch * i)) {
                        return (ERROR);
                }

        }

        if (OK != EndRaster(printerContext)) {
                return (ERROR);
        }

        return(OK);
}



/* ----------------------------------------------------------------
 *
 * Bitmap Image Operations
 *
 * ---------------------------------------------------------------- */

int DrawImage(int printerContext, int sourceWidth, int sourceHeight, int colorDepth, ImageFormat imageFormat, Rectangle destinationSize, int count, void *imageData)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        result = StartDrawImage(printerContext, sourceWidth, sourceHeight, colorDepth, imageFormat, destinationSize);
        if (result != OK) return (ERROR);

        result = TransferDrawImage(printerContext, count, imageData);
        if (result != OK) return (ERROR);

        result = EndDrawImage(printerContext);
        if (result != OK) return (ERROR);

        return(result);
}


int StartDrawImage(int printerContext, int sourceWidth, int sourceHeight, int colorDepth, ImageFormat imageFormat, Rectangle destinationSize)
{
        GraphicsState *gs;
        int x, y;

        DebugPrint("pdapi: %s,%d: width=%d, height=%d, imageFormat=%d, imageDepth=%d\n", __FUNCTION__, __LINE__, sourceWidth, sourceHeight, imageFormat, colorDepth);


        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context������
                   �Ǥ��� */
                return (ERROR);
        }

        gs->imageFormat = imageFormat;
        gs->imageDepth = colorDepth;

        x = (int)ApplyCtmX_Integer(destinationSize.p0.x, destinationSize.p0.y, gs->ctm)
                - (int)ApplyCtmX_Integer(destinationSize.p1.x, destinationSize.p1.y, gs->ctm);
        x = (int)fabs((double)x);
        y = (int)ApplyCtmY_Integer(destinationSize.p0.x, destinationSize.p0.y, gs->ctm)
                - (int)ApplyCtmY_Integer(destinationSize.p1.x, destinationSize.p1.y, gs->ctm);
        y = (int)fabs((double)y);

        /* ���᡼�����賫�� */
        gs->imageActive = TRUE;

        if (imageFormat == iformatRaw) {
                return StartRaws(printerContext, sourceWidth, sourceHeight, colorDepth, x, y);

        }

        /* ̤���ݡ��� */
        errorno = NOTSUPPORTED;
        return (ERROR);
}


int TransferDrawImage(int printerContext, int count, void *imageData)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context������
                   �Ǥ��� */
                return (ERROR);
        }

        if (gs->imageFormat == iformatRaw) {
                return WriteRaws(printerContext, count, imageData);
        }

        return(OK);
}


int EndDrawImage(int printerContext)
{
        GraphicsState *gs;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context������
                   �Ǥ��� */
                return (ERROR);
        }

        /* ���᡼�����轪λ */
        gs->imageActive = FALSE;

        return EndRaws(printerContext);
}



/* ----------------------------------------------------------------
 *
 * Scan Line Operations
 *
 * ---------------------------------------------------------------- */

int StartScanline(int printerContext, int yposition)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int Scanline(int printerContext, int nscanpairs, int *scanpairs)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int EndScanline(int printerContext)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}



/* ----------------------------------------------------------------
 *
 * Raster Image Operations
 *
 *
 * ---------------------------------------------------------------- */

int StartRaster(int printerContext, int rasterWidth)
{
        int             result;
        GraphicsState *gs;
        char obuf[64];
        result = 0;
        DeviceInfo *dev;

        DebugPrint("pdapi: %s,%d rasterWidth=%d\n", __FUNCTION__, __LINE__, rasterWidth);

        gs = GetGraphicsState(printerContext);
        if (gs == NULL) {
                /* GraphicsState��̵�����⤷����Printer Context������
                   �Ǥ��� */
                return (ERROR);
        }

        dev = GetDeviceInfo(printerContext);
        if (dev == NULL) {
                return(ERROR);
        }

        /* PCL�⡼�ɰܹ� */
        (void)sprintf(obuf, PCL_ESC "%%1A" PCL_ESC "*p0P");
        result = CheckWrite(printerContext, obuf, strlen(obuf));
        if (result != OK) return (ERROR);

        result = CheckWrite(printerContext, PCL_ESC "*v6W\00\03\00\10\10\10", 11);
        if (result != OK) return (ERROR);

        if (gs->useBgBrush == TRUE) {
                (void)sprintf(obuf,
                      PCL_ESC "*v%da%db%dc0I",
                      (unsigned char)gs->bgBrush.color[2],
                      (unsigned char)gs->bgBrush.color[1],
                      (unsigned char)gs->bgBrush.color[0]);
                result = CheckWrite(printerContext, obuf, strlen(obuf));
                if (result != OK) return (ERROR);
        }

        (void)sprintf(obuf,
                      PCL_ESC "*v%da%db%dc1I"
                      PCL_ESC "*r%ds1A",
                      (unsigned char)gs->fillBrush.color[2],
                      (unsigned char)gs->fillBrush.color[1],
                      (unsigned char)gs->fillBrush.color[0],
                      rasterWidth);             /* ���������� */
        result = CheckWrite(printerContext, obuf, strlen(obuf));
        if (result != OK) return (ERROR);

        return(result);
}


int TransferRasterData(int printerContext, int count, unsigned char *data)
{
        int             result;
        char obuf[64];
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        if (count == 0) {
                /* ��������̵�� */
                return (OK);
        }

        /* �饹��ž�� */
        (void)sprintf(obuf, PCL_ESC "*b%dW",
                      count);

        result = CheckWrite(printerContext, obuf, strlen(obuf));
        if (result != OK) {
                /* �񤭹��߼��� */
                return (ERROR);
        }
        result = CheckWrite(printerContext, data, count);

        return(result);
}


int SkipRaster(int printerContext, int count)
{
        char            obuf[64];
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        (void)sprintf(obuf, PCL_ESC "*b%dY",
                      count);

        result = CheckWrite(printerContext, obuf, strlen(obuf));
        if (result != OK) {
                /* �񤭹��߼��� */
                return (ERROR);
        }

        return(result);
}


int EndRaster(int printerContext)
{
        char obuf[64];

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        /* GL2�⡼�ɰܹ� */
        (void)sprintf(obuf,
                      PCL_ESC "*rC"
                      PCL_ESC "*v255a255b255c0I"
                      PCL_ESC "*p1P"
                      PCL_ESC "%%0B");

        return CheckWrite(printerContext, obuf, strlen(obuf));
}



/* ----------------------------------------------------------------
 *
 * Stream Data Operations
 *
 * ---------------------------------------------------------------- */

int StartStream(int printerContext)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int TransferStreamData(int printerContext, int count, void *data)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}


int EndStream(int printerContext)
{
        int             result;
        result = 0;

        DebugPrint("pdapi: %s,%d \n", __FUNCTION__, __LINE__);

        return(result);
}

/* end of HPPageColor.c */
