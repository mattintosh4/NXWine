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
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/poll.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include "opvp_rpc_core.h"
#include "opvp_rpc_reqno.h"

#define RPCBUF_INIT_SIZE 1024

/* threshold for using shared memory */
#define RPCSHMEM_THRESHOLD 256

#define SHMEMSTACK_PAGE_SIZE 256

/* next request sequence number */
static int seqNo = 1;

/* currentlly using shmem id stack */
static void **shmemStack = NULL;
static int shmemStackSize;
static int shmemStackPointer;
static int lastPushSeqNo;

typedef struct {
    char *body;
    int size;
    int rIndex; /* index for reading from buffer */
    int wIndex; /* index for writing to buffer */
    int pktTop; /* top of current packet */
    int pktIndex; /* index of reading packet from buffer
                            or writing packet to buffer */
} RPCBuf;

typedef struct {
    int inFd;
    int outFd;
    RPCBuf inBuf;
    RPCBuf outBuf;
} RPCHandle;

/* initialize shared memeory id stack */
static int initShmemStack(void)
{
    /* memory free */
    if (shmemStack) {
      free(shmemStack);
      shmemStack = NULL;
    }

    if ((shmemStack = (void **)malloc(
        SHMEMSTACK_PAGE_SIZE*sizeof(void *))) == NULL) {
	return -1;
    }
    shmemStackSize = SHMEMSTACK_PAGE_SIZE;
    shmemStackPointer = 0;
    lastPushSeqNo = 0;
    return 0;
}

static int pushShmem(void *p)
{
    if (shmemStackPointer >= shmemStackSize) {
	void *newp;
	if ((newp = (void **)realloc(shmemStack,
	      (shmemStackSize+SHMEMSTACK_PAGE_SIZE)*sizeof(void *)))
	      == NULL) {
	    return -1;
	}
	shmemStack = newp;
	shmemStackSize += SHMEMSTACK_PAGE_SIZE;
    }
    shmemStack[shmemStackPointer++] = p;
    lastPushSeqNo = seqNo;
    return 0;
}

static void *newShmem(int size, int *pid)
{
    int id;
    struct shmid_ds dsbuf;
    void *p;

    if ((id = shmget(IPC_PRIVATE,size,0600)) < 0) {
	return NULL;
    }
    if ((int)(p = shmat(id,0,0)) == -1) {
	return NULL;
    }
    shmctl(id,IPC_RMID,&dsbuf);
    if (pushShmem(p) < 0) {
	shmdt(p);
	return NULL;
    }
    *pid = id;
    return p;
}

static void *shmemAttach(int id)
{
    void *p;

    if ((int)(p = shmat(id,0,0)) == -1) {
	return NULL;
    }
    if (pushShmem(p) < 0) {
	shmdt(p);
	return NULL;
    }
    return p;
}

static int cleanShmemStack(void)
{
    int i;

    for (i = 0;i < shmemStackPointer;i++) {
	shmdt(shmemStack[i]);
    }
    shmemStackPointer = 0;
    return 0;
}

/* initalize buffer */
static int rpcbufInit(RPCBuf *bp)
{
    if ((bp->body = malloc(RPCBUF_INIT_SIZE)) == NULL) {
	return -1;
    }
    bp->size = RPCBUF_INIT_SIZE;
    bp->rIndex = bp->wIndex = 0;
    bp->pktTop = bp->pktIndex = 0;
    return 0;
}

/* clean buffer */
static int rpcBufClean(RPCBuf *bp)
{
    if (bp->body != NULL) free(bp->body);
    bp->body = NULL;
    bp->size = 0;
    bp->rIndex = bp->wIndex = 0;
    bp->pktTop = bp->pktIndex = 0;
    return 0;
}

/* initialize RPC struct */
void *oprpc_init(int inFd, int outFd)
{
    RPCHandle *hp;

    if ((hp = malloc(sizeof(RPCHandle))) == NULL) {
	return NULL;
    }
    hp->inFd = inFd;
    hp->outFd = outFd;
    hp->inBuf.body = hp->outBuf.body = NULL;
    if (rpcbufInit(&(hp->inBuf)) < 0) {
	goto errret;
    }
    if (rpcbufInit(&(hp->outBuf)) < 0) {
	rpcBufClean(&(hp->inBuf));
	goto errret;
    }

    /* set readFd Nonblock */
    if (fcntl(inFd, F_SETFL, O_NONBLOCK) < 0) {
	rpcBufClean(&(hp->outBuf));
	rpcBufClean(&(hp->inBuf));
	goto errret;
    }
    if (initShmemStack() < 0) {
	goto errret;
    }
    return (void *)hp;
errret:
    free(hp);
    return NULL;
}

int oprpc_destroy(void *ap)
{
    RPCHandle *hp = ap;
    rpcBufClean(&hp->inBuf);
    rpcBufClean(&hp->outBuf);
    cleanShmemStack();
    free(hp);
}

/* flush buffer and realloc buffer if needed */
static int oprpc_flushBuffer(RPCHandle *hp, int len)
{
    int wlen = hp->outBuf.wIndex-hp->outBuf.rIndex;
    int mlen;

    while (wlen > 0) {
	int r;

	if ((r = write(hp->outFd,
	   hp->outBuf.body+hp->outBuf.rIndex,wlen)) < 0) {
	    if (errno == EINTR) continue;
	    return -1;
	}
	wlen -= r;
	hp->outBuf.rIndex += r;
    }
    hp->outBuf.rIndex = hp->outBuf.wIndex = 0;

    /* calculate needed size */
    mlen = len + hp->outBuf.pktIndex -  hp->outBuf.pktTop;

    /* move writing packet to the top of buffer */
    if (hp->outBuf.size < mlen) {
	/* not enough buffer size, realloc buffer */
	char *p;

	if ((p = malloc(mlen)) == NULL) {
	    return -1;
	}
	memcpy(p, hp->outBuf.body+hp->outBuf.pktTop,
	  hp->outBuf.pktIndex-hp->outBuf.pktTop);

	free(hp->outBuf.body);
	hp->outBuf.size = mlen;
	hp->outBuf.body = p;
    } else {
	memmove(hp->outBuf.body, hp->outBuf.body+hp->outBuf.pktTop,
	  hp->outBuf.pktIndex-hp->outBuf.pktTop);
    }
    hp->outBuf.pktIndex -= hp->outBuf.pktTop;
    hp->outBuf.pktTop = 0;
    return 0;
}

/* putting packet data to the buffer */
int oprpc_putPkt(void *ap, char *buf, int len)
{
    RPCHandle *hp = ap;

    if (hp->outBuf.size - hp->outBuf.pktIndex < len) {
	/* not enough space in buffer, flush buffer */
	if (oprpc_flushBuffer(hp, len) < 0) {
	    return -1;
	}
    }
    memcpy(hp->outBuf.body+hp->outBuf.pktIndex,buf,len);
    hp->outBuf.pktIndex += len;
    return 0;
}

/* putting pointer */
int oprpc_putPktPointer(void *ap, void *p, int len)
{
    RPCHandle *hp = ap;
    char f;
    int id;
    void *shp;

    if (p == NULL) {
	f = 2;
	if (oprpc_putPkt(ap,&f,1) < 0) {
	    return -1;
	}
	return 0;
    }
    if (len > RPCSHMEM_THRESHOLD &&
	(shp = newShmem(len,&id)) != NULL) {
	f = 1;
	if (oprpc_putPkt(ap,&f,1) < 0) {
	    return -1;
	}
	if (oprpc_putPkt(ap,(char *)&id,sizeof(id)) < 0) {
	    return -1;
	}
	memcpy(shp,p,len);
    } else {
	f = 0;
	if (oprpc_putPkt(ap,&f,1) < 0) {
	    return -1;
	}
	hp->outBuf.pktIndex = ((hp->outBuf.pktIndex+3)/4)*4; /* align 4 */
	if (oprpc_putPkt(ap,p,len) < 0) {
	    return -1;
	}
    }
    return 0;
}

/* start putting a packet to buffer */
int oprpc_putPktStart(void *ap, int sendSeqNo, int reqNo)
{
    RPCHandle *hp = ap;
    int dmy = 0;

    hp->outBuf.pktTop = hp->outBuf.pktIndex = hp->outBuf.wIndex;
    if (oprpc_putPkt(hp,(char *)&dmy,sizeof(dmy)) < 0) {
	return -1;
    }
    if (sendSeqNo < 0) { /* request */
	sendSeqNo = seqNo++;
    }
    if (oprpc_putPkt(hp,(char *)&sendSeqNo,sizeof(sendSeqNo)) < 0) {
	return -1;
    }
    if (oprpc_putPkt(hp,(char *)&reqNo,sizeof(reqNo)) < 0) {
	return -1;
    }
    return sendSeqNo;
}

/* end putting a packet to buffer */
int oprpc_putPktEnd(void *ap)
{
    int len,r;
    RPCHandle *hp = ap;

    len = hp->outBuf.pktIndex - hp->outBuf.pktTop - sizeof(int);
    len = ((len+3)/4)*4; /* align 4 */
    *((int *)(hp->outBuf.body+hp->outBuf.pktTop)) = len;
    hp->outBuf.wIndex = hp->outBuf.pktIndex
       = hp->outBuf.pktTop+len+sizeof(int);
    return 0;
}

/* fill buffer and realloc buffer if needed */
static int oprpc_fillBuffer(RPCHandle *hp, int len, int block)
{
    int mlen = hp->inBuf.wIndex - hp->inBuf.pktTop + len;

    /* move reading packet to the top of buffer */
    if (hp->inBuf.size < mlen) {
	/* not enough buffer size, realloc buffer */
	char *p;

	if ((p = malloc(mlen)) == NULL) {
	    return -1;
	}
	memcpy(p, hp->inBuf.body+hp->inBuf.pktTop,
	  hp->inBuf.wIndex-hp->inBuf.pktTop);

	free(hp->inBuf.body);
	hp->inBuf.size = mlen;
	hp->inBuf.body = p;
	hp->inBuf.pktIndex -= hp->inBuf.pktTop;
	hp->inBuf.rIndex -= hp->inBuf.pktTop;
	hp->inBuf.wIndex -= hp->inBuf.pktTop;
	hp->inBuf.pktTop = 0;
    } else if (hp->inBuf.size - hp->inBuf.wIndex < len) {
	memmove(hp->inBuf.body, hp->inBuf.body+hp->inBuf.pktTop,
	  hp->inBuf.wIndex-hp->inBuf.pktTop);
	hp->inBuf.pktIndex -= hp->inBuf.pktTop;
	hp->inBuf.rIndex -= hp->inBuf.pktTop;
	hp->inBuf.wIndex -= hp->inBuf.pktTop;
	hp->inBuf.pktTop = 0;
    }

    while (len > 0) {
	int r;
	struct pollfd pfd;
	int rlen;

	/* wait until data is ready */
	pfd.fd = hp->inFd;
	pfd.events = POLLIN | POLLERR;
	if ((r = poll(&pfd,1,block ? -1 : 0)) <= 0) {
	    if (r < 0 && errno == EINTR) continue;
	    return r;
	}
	if ((pfd.revents & POLLIN) == 0) {
	    return -1;
	}
	rlen = hp->inBuf.size - hp->inBuf.wIndex;
	if ((r = read(hp->inFd,
	   hp->inBuf.body+hp->inBuf.wIndex,rlen)) <= 0) {
	    if (errno == EINTR) continue;
	    return -1;
	}
	len -= r;
	hp->inBuf.wIndex += r;
    }

    return 1;
}

/* flush send buffer */
int oprpc_flush(void *hp)
{
    return oprpc_flushBuffer(hp,0);
}

/* getting data */
int oprpc_getPkt(void *ap, char *buf, int len)
{
    RPCHandle *hp = ap;

    if (hp->inBuf.wIndex - hp->inBuf.pktIndex < len) {
	/* fill buffer */
	if (oprpc_fillBuffer(hp,
	     len-(hp->inBuf.wIndex - hp->inBuf.pktIndex),1) < 0) {
	    return -1;
	}
    }
    memcpy(buf,hp->inBuf.body+hp->inBuf.pktIndex,len);
    hp->inBuf.pktIndex += len;
    return 0;
}

/* getting data */
int oprpc_getPktNonBlock(void *ap, char *buf, int len)
{
    RPCHandle *hp = ap;

    if (hp->inBuf.wIndex - hp->inBuf.pktIndex < len) {
	int r;

	/* fill buffer */
	if ((r = oprpc_fillBuffer(hp,
	     len-(hp->inBuf.wIndex - hp->inBuf.pktIndex),0)) <= 0) {
	    return r;
	}
    }
    memcpy(buf,hp->inBuf.body+hp->inBuf.pktIndex,len);
    hp->inBuf.pktIndex += len;
    return 1;
}

/* getting pointer */
int oprpc_getPktPointer(void *ap, void **p, int len)
{
    RPCHandle *hp = ap;
    char f;
    int id;

    if (oprpc_getPkt(ap,&f,1) < 0) {
	return -1;
    }
    switch (f) {
    case 0:
	hp->inBuf.pktIndex = ((hp->inBuf.pktIndex+3)/4)*4; /* align 4 */
	if (len >= 0 && hp->inBuf.wIndex - hp->inBuf.pktIndex < len) {
	    /* not need fill buffer, because already read whole packet */
	    /* so this case is an illegal packet error */
	    /* when len < 0, no check */
	    return -1;
	}
	*p = hp->inBuf.body+hp->inBuf.pktIndex;
	if (len >= 0) hp->inBuf.pktIndex += len;
	break;
    case 1:
	if (oprpc_getPkt(ap,(char *)&id,sizeof(id)) < 0) {
	    return -1;
	}
	if ((*p = shmemAttach(id)) == NULL) {
	    return -1;
	}
	break;
    case 2:
	*p = NULL;
	break;
    default:
	return -1;
	break;
    }

    return f;
}

int oprpc_addInPktIndex(void *ap, int len)
{
    RPCHandle *hp = ap;
    hp->inBuf.pktIndex += len;
}

/* getting string */
int oprpc_getStr(void *ap, char **sp)
{
    RPCHandle *hp = ap;
    int len;

    if (oprpc_getPktPointer(ap,(void **)sp,-1) < 0) {
	return -1;
    }
    if (*sp != NULL) {
	len = strlen(*sp);
	hp->inBuf.pktIndex += len + 1;
    }
    return 0;
}

/* start getting a packet from buffer */
int oprpc_getPktStart(void *ap)
{
    RPCHandle *hp = ap;
    int size;
    int gSeqNo;

    if (oprpc_flush(hp) < 0) {
	return -1;
    }
    hp->inBuf.pktTop = hp->inBuf.pktIndex = hp->inBuf.rIndex;
    if (oprpc_getPkt(hp,(char *)&size,sizeof(size)) < 0) {
	return -1;
    }
    if (hp->inBuf.wIndex - hp->inBuf.pktIndex < size) {
	/* read whole packet */
	if (oprpc_fillBuffer(hp,
	     size - (hp->inBuf.wIndex - hp->inBuf.pktIndex),1) < 0) {
	    return -1;
	}
    }
    if (oprpc_getPkt(hp,(char *)&gSeqNo,sizeof(gSeqNo)) < 0) {
	return -1;
    }
    if (gSeqNo >= lastPushSeqNo) {
	cleanShmemStack();
    }
    return gSeqNo;
}

/* start getting a packet from buffer */
int oprpc_getPktStartNonBlock(void *ap)
{
    RPCHandle *hp = ap;
    int size;
    int gSeqNo;
    int r;

    if (oprpc_flush(hp) < 0) {
	return -1;
    }
    hp->inBuf.pktTop = hp->inBuf.pktIndex = hp->inBuf.rIndex;
    if ((r = oprpc_getPktNonBlock(hp,(char *)&size,sizeof(size))) <= 0) {
	return r;
    }
    if (hp->inBuf.wIndex - hp->inBuf.pktIndex < size) {
	/* read whole packet */
	if ((r = oprpc_fillBuffer(hp,
	     size - (hp->inBuf.wIndex - hp->inBuf.pktIndex),0)) <= 0) {
	    return r;
	}
    }
    if (oprpc_getPkt(hp,(char *)&gSeqNo,sizeof(gSeqNo)) < 0) {
	return -1;
    }
    if (gSeqNo >= lastPushSeqNo) {
	cleanShmemStack();
    }
    return gSeqNo;
}

/* end getting a packet from buffer */
int oprpc_getPktEnd(void *ap)
{
    RPCHandle *hp = ap;

    hp->inBuf.rIndex +=
      *((int *)(hp->inBuf.body+hp->inBuf.pktTop))+sizeof(int);
    return 0;
}

/* put error response */
int oprpc_putError(void *ap, int seqNo, int errNo, int reqNo)
{
    if (oprpc_putPktStart(ap, seqNo, errNo) < 0) {
	return -1;
    }
    if (oprpc_putInt(ap,&reqNo) < 0) {
	return -1;
    }
    return oprpc_putPktEnd(ap);
}
