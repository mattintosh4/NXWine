##  Makefile.am -- an automake template for a Makefile.in file
##  Copyright (C) 2004  EPSON KOWA Corporation
##
##  This file is part of the 'OpenPrinting Japan' build infra-structure.
##
##  The 'OpenPrinting Japan' build infra-structure is free software.
##  You can redistribute it and/or modify it under the terms of the GNU
##  General Public License as published by the Free Software Foundation;
##  either version 2 of the License or at your option any later version.
##
##  This program is distributed in the hope that it will be useful, but
##  WITHOUT ANY WARRANTY;  without even the implied warranty of FITNESS
##  FOR A PARTICULAR PURPOSE or MERCHANTABILITY.
##  See the GNU General Public License for more details.
##
##  You should have received a verbatim copy of the GNU General Public
##  License along with this program; if not, write to:
##
##      Free Software Foundation, Inc.
##      59 Temple Place, Suite 330
##      Boston, MA  02111-1307  USA

SUBDIRS = doc

EXTRA_DIST = \
	README.jp \
	COPYING \
	pdapi.h

AM_LDFLAGS = @MATH_LIBS@	## FIXME: pdapi.h uses floor in some macros
				##        that it should not provide in the
				##        first place

##  We build two convenience libraries that provide the bulk of each
##  RPC server executable.  One is geared to servers that dlopen the
##  module they need, the other is for servers that link statically
##  with their module.  Modules for the latter should be built as a
##  convenience library (noinst_LTLIBRARIES) as well.
##  There only needs to be a single dlopen based server (because it
##  opens the module passed via the command line that is exec'd by
##  the Ghostscript driver).

server_sources = \
	opvp_common.h \
	opvp_driver.h \
	opvp_rpc_core.c \
	opvp_rpc_core.h \
	opvp_rpc_reqno.h \
	opvp_rpc_server.c \
	opvp_rpc_server.h

noinst_LTLIBRARIES = \
	lib_dlopen_server.la \
	lib_static_server.la

lib_dlopen_server_la_SOURCES = $(server_sources)
lib_dlopen_server_la_CFLAGS = -DDLOPEN_MODULE
lib_dlopen_server_la_LIBADD = @DL_LIBS@

lib_static_server_la_SOURCES = $(server_sources)
lib_static_server_la_CFLAGS = 
