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

## FIXME: install in $(pkglibdir)
lib_LTLIBRARIES = \
	libHPPageColor.la

libHPPageColor_la_CFLAGS = -I$(top_srcdir)/libopvp/
libHPPageColor_la_LDFLAGS = -module -version-info @HPPAGECOLOR_VERSION_INFO@
libHPPageColor_la_SOURCES = \
	HPPageColor.c
