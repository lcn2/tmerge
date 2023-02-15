#!/bin/make
# @(#)Makefile	1.2 04 May 1995 02:06:57
#
# tmerge - merge one tree into another
#
# @(#) $Revision: 1.2 $
# @(#) $Id: Makefile,v 1.2 2015/09/06 08:20:16 root Exp $
# @(#) $Source: /usr/local/src/bin/tmerge/RCS/Makefile,v $
#
# Copyright (c) 2005 by Landon Curt Noll.  All Rights Reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby granted,
# provided that the above copyright, this permission notice and text
# this comment, and the disclaimer below appear in all of the following:
#
#       supporting documentation
#       source copies
#       source works derived from this source
#       binaries derived from this source or from derived source
#
# LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
# USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# chongo (Landon Curt Noll, http://www.isthe.com/chongo/index.html) /\oo/\
#
# Share and enjoy! :-)


SHELL= /bin/sh

TOPNAME= bin
INSTALL= install

DESTDIR= /usr/local/bin

TARGETS= tmerge

all: ${TARGETS}

tmerge: tmerge.pl
	rm -f $@
	cp $? $@
	chmod 0555 $@

configure:
	@echo nothing to configure

clean quick_clean quick_distclean distclean:

clobber quick_clobber: clean
	rm -f tmerge

install: all
	${INSTALL} -m 0555 ${TARGETS} ${DESTDIR}
