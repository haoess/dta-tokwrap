##-*- Mode: Makefile -*-
##
## File: Makefile
## Author: Bryan Jurish <jurish@bbaw.de>
## Description:
##  + top-level makefile for corpus preparation via dta-tokwrap
## Usage:
##  + DO NOT edit this file (unless you *really* know what you're doing)
##  + Copy the file "User.mak" which came with the distribution to
##    a new file, e.g. "MyConfig.mak", and edit the new file to suit your
##    needs
##  + Call make with "config=MyConfig.mak" on the command line, e.g.:
##    $ make config=MyConfig.mak all
##  + ... you atta be in buttah ...
##======================================================================

##======================================================================
## Configuration: User

config ?= User.mak
include $(config)

##======================================================================
## Configuration: Defaults

##--------------------------------------------------------------
## Configuration: Defaults: sources & targets

xmldir ?= .
xml    ?= $(wildcard $(xmldir),*.chr.xml) $(wildcard $(xmldir),*.char.xml)
outdir = .
tmpdir = $(outdir)

XML = $(notdir $(xml))

##--------------------------------------------------------------
## Configuration: Defaults: tokwrap

## TOKWRAP_OPTS
##  + all options for dta-tokwrap.perl
TOKWRAP_OPTS = -keep

ifeq "$(inplace)" "yes"
TOKWRAP_OPTS += -inplace
else
TOKWRAP_OPTS += -noinplace
endif

##--------------------------------------------------------------
## Configuration: Defaults: dta-tokwrap.perl: behavior

ifneq "$(dummytok)" ""
ifeq "$(dummytok)" "no"
TOKWRAP_OPTS += -nodummytok -strong-hints
else
TOKWRAP_OPTS += -dummytok -weak-hints
endif
endif

##--------------------------------------------------------------
## Configuration: Defaults: dta-tokwrap.perl: verbosity & logging

ifneq "$(verbose)" ""
TOKWRAP_OPTS += -verbose=$(verbose)
endif

ifneq "$(loglevel)" ""
TOKWRAP_OPTS += -log-level="$(loglevel)"
endif

ifneq "$(logfile)" ""
TOKWRAP_OPTS += -log-file="$(logfile)"
endif

ifneq "$(stderr)" ""
ifeq "$(stderr)" "no"
TOKWRAP_OPTS += -nostderr
else
TOKWRAP_OPTS += -stderr  ##-- default
endif
endif

ifneq "$(trace)" ""
ifeq "$(trace)" "no"
TOKWRAP_OPTS += -notrace
else
TOKWRAP_OPTS += -trace
endif
endif

ifneq "$(profile)" ""
ifneq "$(profile)" "no"
TOKWRAP_OPTS += -profile
else
TOKWRAP_OPTS += -noprofile
endif
endif

##--------------------------------------------------------------
## Configuration: Defaults: programs & in-place execution

PERL = perl

ifeq "$(inplace)" "yes"

PROG_DIR  = ../src/
PROG_DEPS = $(wildcard $(PROG_DIR)*.c) $(wildcard $(PROG_DIR)*.h) $(wildcard $(PROG_DIR)*.l)

TOKWRAP_DIR  = ../DTA-TokWrap
TOKWRAP_SRC  = $(TOKWRAP_DIR)/dta-tokwrap.perl
TOKWRAP      = $(PERL) -Mlib=$(TOKWRAP_DIR)/blib/lib $(TOKWRAP_DIR)/blib/script/dta-tokwrap.perl -i $(TOKWRAP_OPTS)
TOKWRAP_DEPS = $(TOKWRAP_SRC)

else

PROG_DEPS =
PROG_DIR  =

TOKWRAP      =dta-tokwrap.perl $(TOKWRAP_OPTS)
TOKWRAP_DEPS =

endif

##--------------------------------------------------------------
## Configuration: Defaults: archiving & distribution

ARC_TARGETS ?= \
	Makefile \
	Defaults.mak \
	User.mak \
	$(config) \
	$(logfile) \
	$(XML) \
	$(XML:.xml=.t.xml) \
	$(XML:.xml=.s.xml) \
	$(XML:.xml=.w.xml) \
	$(XML:.xml=.a.xml)

##--------------------------------------------------------------
## Configuration: Defaults: cleanup

CLEAN_DEPS ?=
CLEAN_FILES ?=

REALCLEAN_DEPS ?=
REALCLEAN_FILES ?= \
	$(filter-out $(xml),$(XML)) \
	$(logfile)


##======================================================================
## Rules: top-level

all: t-xml s-xml w-xml a-xml

.SECONDARY: 

##======================================================================
## Rules: show configuration

config:
	@echo "inplace=$(inplace)"
	@echo "TOKWRAP=$(TOKWRAP)"
	@echo "xmldir=$(xmldir)"
	@echo "xml=$(xml)"
	@echo "XML=$(XML)"

##======================================================================
## Rules: link in sources

xml: xml.stamp
xml.stamp: $(xml)
	for f in $(filter-out $(xml),$(XML)); do \
	  rm -f `basename $$f`; \
	  ln -s $$f `basename $$f`; \
	done
	touch $@

%.xml: $(xmldir)/%.xml
	rm -f $@
	ln -s $< $@

no-xml: ; test -z "$(filter-out $(xml),$(XML))" || rm -f $(filter-out $(xml),$(XML))

##======================================================================
## Rules: generic XML stuff

##-- pretty-printing (.fmt)
%.fmt: %
	xmllint --format -o $@ $<
CLEAN_FILES += *.fmt

##-- namespace removal (.nons)
%.nons: % $(RMNS)
	$(RMNS) $< $@
CLEAN_FILES += *.nons

nolog: ; test -z "$(logfile)" || rm -f $(logfile)

##======================================================================
## Rules: mkindex: xml -> xx=(cx,sx,tx)

xx: cx sx tx

cx: $(XML:.xml=.cx)
sx: $(XML:.xml=.sx)
tx: $(XML:.xml=.tx)
no-cx: ; rm -f $(XML:.xml=.cx)
no-sx: ; rm -f $(XML:.xml=.sx)
no-tx: ; rm -f $(XML:.xml=.tx)
no-xx: no-cx no-sx no-tx ; rm -f *.xx xx.stamp

##-- xml -> (cx,sx,tx): batch rule
xx.stamp: $(XML) tokwrap
	$(TOKWRAP) -t mkindex $(XML)
	touch $@

##-- xml -> (cx,sx,tx): individual rule
#%.xx: ; $(MAKE) $*.cx $*.sx $*.tx
%.xx: %.cx %.sx %.tx
%.cx: %.cx %.sx %.tx
%.sx: %.cx %.sx %.tx
%.tx: %.cx %.sx %.tx
%.cx %.sx %.tx: %.xml tokwrap
#	$(TOKWRAP) -t mkindex $<
	$(PROG_DIR)dtatw-mkindex $< $*.cx $*.sx $*.tx
CLEAN_FILES += *.cx *.sx *.tx *.xx *.stamp

sx-fmt: $(XML:.xml=.sx.fmt)
no-sx-fmt: ; rm -f *.sx.fmt

sx-nons: $(XML:.xml=.sx.nons)
no-sx-nons: ; rm -f *.sx.nons *.sx.nons.fmt

sx-nons-fmt: $(XML:.xml=.sx.nons.fmt)
no-sx-nons-fmt: ; rm -f *.sx.nons.fmt
CLEAN_FILES += *.sx.nons *.sx.fmt *.sx.nons.fmt *.sx.fmt.nons

##======================================================================
## Rules: serialization (serialized block index: bx0)

bx0: bx0-iter
#bx0: bx0.stamp

bx0.stamp: xx.stamp tokwrap
	$(TOKWRAP) -t bx0 $(XML)
	touch $@

bx0-iter: $(XML:.xml=.bx0)
%.bx0: %.sx tokwrap
	$(TOKWRAP) -t mkbx0 $*.xml

no-bx0: ; rm -f *.bx0 bx0.stamp
CLEAN_FILES += *.bx0 bx0.stamp

##======================================================================
## Rules: serialized text + index (bx, txt)

serialize: txt

bx: bx-iter
txt: txt-iter
#bx: bx.stamp
#txt: txt.stamp

bx.stamp: bx0.stamp tokwrap
	$(TOKWRAP) -t bx $(XML)
	touch $@

txt.stamp: bx.stamp
	touch $@

bx-iter: $(XML:.xml=.bx)
txt-iter: $(XML:.xml=.txt)

%.bx:  %.bx %.txt
%.txt: %.bx %.txt

%.bx: %.bx0 %.tx tokwrap
	$(TOKWRAP) -t bx $*.xml
%.txt: %.bx0 %.tx tokwrap
	$(TOKWRAP) -t bx $*.xml

no-bx: ; rm -f *.bx bx.stamp *.txt txt.stamp
no-txt: no-bx
CLEAN_FILES += *.bx *.txt bx.stamp txt.stamp

##======================================================================
## Rules: tokenization: dummy, via flex for speed: .t

#tt: t

t: t-iter
#t: t.stamp

t.stamp: txt.stamp tokwrap
	$(TOKWRAP) -t tokenize $(XML)
	touch $@

t-iter: $(XML:.xml=.t)
%.t: %.txt tokwrap
	$(TOKWRAP) -t tokenize $*.xml
#	$(TOKENIZER) $< $@

no-t: ; rm -f *.t t.stamp
CLEAN_FILES += *.t t.stamp

##======================================================================
## Rules: tokenized: master xml output

tokd-xml: t-xml
tt-xml: t-xml

t-xml: t-xml-iter
#t-xml: t-xml.stamp

t-xml.stamp: t.stamp tokwrap
	$(TOKWRAP) -t tok2xml $(XML)
	touch $@

t-xml-iter: $(XML:.xml=.t.xml)
%.t.xml: %.t %.cx %.bx tokwrap
#	$(TOKWRAP) -t tok2xml $*.xml
	$(PROG_DIR)dtatw-tok2xml $< $*.cx $*.bx $@ $*.xml

no-t-xml: ; rm -f *.t.xml t-xml.stamp
no-tokd-xml: no-t-xml
no-tt-xml: no-t-xml
CLEAN_FILES += *.t.xml t-xml.stamp

##======================================================================
## Rules: tokenized: xml-t: master xml output -> .tt

%.t.xml.t: $(XSL_DIR)/dtatw-txml2tt.xsl %.t.xml
	xsltproc --param locations 0 -o "$@" $^
xml-t: $(XML:.xml=.t.xml.t)
no-xml-t: ; rm -f *.t.xml.t
CLEAN_FILES += *.t.xml.t

##======================================================================
## Rules: standoff (via xsl)

##-- standoff: top-level
standoff: standoff-iter
#standoff: standoff.stamp

standoff-iter: s-xml-iter w-xml-iter a-xml-iter

standoff.stamp: t-xml.stamp tokwrap
	$(TOKWRAP) -t standoff $(XML)
	touch $@

no-standoff: no-s-xml no-w-xml no-a-xml ; rm -f standoff.stamp
%-standoff:
	$(MAKE) $*.s.xml $*.w.xml $*.a.xml

##-- standoff: xsl (workaround for broken `dta-tokwrap.perl -t so*xml` with `make -j2`)
standoff-xsl:
	$(MAKE) standoff_t2s.xsl standoff_t2w.xsl standoff_t2a.xsl

standoff_t2s.xsl standoff_t2w.xsl standoff_t2a.xsl: tokwrap
	$(TOKWRAP) -dump-xsl= -

no-standoff-xsl: ; rm -f standoff_t2[swa].xsl
no-xsl: ; rm -f *.xsl
CLEAN_FILES += standoff_t2[swa].xsl mkbx0_*.xsl

##-- standoff: .s.xml
s-xml: s-xml-iter
#s-xml: s-xml.stamp

s-xml.stamp: t-xml.stamp tokwrap
	$(TOKWRAP) -t sosxml $(XML)
	touch $@

s-xml-iter: $(XML:.xml=.s.xml)
#%.s.xml: %.t.xml tokwrap
#	##-- BROKEN with `make -j2`: race condition?
#	$(TOKWRAP) -t sosxml $*.xml
##--
#%.s.xml: standoff_t2s.xsl %.t.xml
#	xsltproc -o $@ $^
##--
%.s.xml: %.t.xml tokwrap
	$(PROG_DIR)dtatw-txml2sxml $< $@ $*.w.xml


no-s-xml: ; rm -f *.s.xml s-xml.stamp
CLEAN_FILES += *.s.xml s-xml.stamp

##-- standoff: .w.xml
w-xml: w-xml-iter
#w-xml: w-xml.stamp

w-xml.stamp: t-xml.stamp tokwrap
	$(TOKWRAP) -t sowxml $(XML)
	touch $@

w-xml-iter: $(XML:.xml=.w.xml)
#%.w.xml: %.t.xml tokwrap
#	##-- BROKEN with `make -j2`: race condition?
#	$(TOKWRAP) -t sowxml $*.xml
##--
#%.w.xml: standoff_t2w.xsl %.t.xml
#	xsltproc -o $@ $^
##--
%.w.xml: %.t.xml programs
	$(PROG_DIR)dtatw-txml2wxml $< $@ $*.xml


no-w-xml: ; rm -f *.w.xml w-xml.stamp
CLEAN_FILES += *.w.xml w-xml.stamp

##-- standoff: .a.xml
a-xml: a-xml-iter
#a-xml: a-xml.stamp

a-xml.stamp: t-xml.stamp tokwrap
	$(TOKWRAP) -t soaxml $(XML)
	touch $@

a-xml-iter: $(XML:.xml=.a.xml)
#%.a.xml: %.t.xml tokwrap
#	##-- BROKEN with `make -j2`: race condition?
#	$(TOKWRAP) -t soaxml $*.xml
##--
#%.a.xml: standoff_t2a.xsl %.t.xml
#	xsltproc -o $@ $^
##--
%.a.xml: %.t.xml tokwrap
	$(PROG_DIR)dtatw-txml2axml $< $@ $*.w.xml

no-a-xml: ; rm -f *.a.xml a-xml.stamp
CLEAN_FILES += *.a.xml a-xml.stamp

##-- running time summary / ex1 (kraepelin) / uhura: scripts
## mkindex      : xml -> cx,sx,tx   1.2s  ~  75.9 Ktok/sec ~ 502.3 Kchr/sec
## mkbx0        : sx -> bx0         0.11s ~ 842.8 Ktok/sec ~   5.6 Mchr/sec
## mkbx         : bx0 -> txt        0.30s ~ 303.4 Ktok/sec ~   2.0 Mchr/sec
## tokenize     : txt -> t          0.08s ~   1.1 Mtok/sec ~   7.5 Mchr/sec
## tok2xml/perl : t -> t.xml       13.13s ~   6.9 Ktok/sec ~  45.9 Kchr/sec  *** SLOW (perl) ***
## sosxml/xsl   : t.xml -> s.xml    1.79s ~  59.8 Ktok/sec ~ 336.8 Kchr/sec
## sowxml/xsl   : t.xml -> w.xml    8.62s ~  10.6 Ktok/sec ~  70.0 Kchr/sec  *** SLOW (xsl) ***
## soaxml/xsl   : t.xml -> a.xml    2.08s ~  43.8 Ktok/sec ~ 289.8 Kchr/sec
## TOTAL                            27.3s ~   3.3 Ktok/sec ~  22.1 Kchr/sec

##-- /carrot: via dta-tokwrap
#  mkindex:    1 doc,  90.6 Ktok,  15.6 Mbyte in   1.4  sec:  63.6 Ktok/sec ~  10.9 Mbyte/sec
#    mkbx0:    1 doc,  90.6 Ktok,  15.6 Mbyte in 105.9 msec: 854.9 Ktok/sec ~ 147.0 Mbyte/sec
#     mkbx:    1 doc,  90.6 Ktok,  15.6 Mbyte in 190.5 msec: 475.4 Ktok/sec ~  81.8 Mbyte/sec
# tokenize:    1 doc,  90.6 Ktok,  15.6 Mbyte in  87.9 msec:   1.0 Mtok/sec ~ 177.1 Mbyte/sec
#  tok2xml:    1 doc,  90.6 Ktok,  15.6 Mbyte in   5.4  sec:  16.8 Ktok/sec ~   2.9 Mbyte/sec
#   sosxml:    1 doc,  90.6 Ktok,  15.6 Mbyte in 380.0 msec: 238.3 Ktok/sec ~  41.0 Mbyte/sec
#   sowxml:    1 doc,  90.6 Ktok,  15.6 Mbyte in 694.3 msec: 130.4 Ktok/sec ~  22.4 Mbyte/sec
#   soaxml:    1 doc,  90.6 Ktok,  15.6 Mbyte in 383.0 msec: 236.5 Ktok/sec ~  40.7 Mbyte/sec
#    TOTAL:    1 doc,  90.6 Ktok,  15.6 Mbyte in  12.5  sec:   7.2 Ktok/sec ~   1.2 Mbyte/sec


##-- carrot, Sun, 03 May 2009 23:12:46 +0200
## tok2xml/perl   :  1 doc,  90.6 Ktok,  15.6 Mbyte in   5.4  sec:  16.8 Ktok/sec ~   2.9 Mbyte/sec
## tok2xml/c-pre1 :  1 doc,  90.6 Ktok,  15.6 Mbyte in 688.0 msec: 223.2 Ktok/sec ~  38.5 Mbyte/sec

##-- carrot, Sun, 03 May 2009 23:12:51 +0200
# sosxml/c:    1 doc,  90.6 Ktok,  15.6 Mbyte in 380.0 msec: 238.3 Ktok/sec ~  41.0 Mbyte/sec
# sowxml/c:    1 doc,  90.6 Ktok,  15.6 Mbyte in 694.3 msec: 130.4 Ktok/sec ~  22.4 Mbyte/sec
# soaxml/c:    1 doc,  90.6 Ktok,  15.6 Mbyte in 383.0 msec: 236.5 Ktok/sec ~  40.7 Mbyte/sec


##======================================================================
## Rules: full processing pipeline

tw-all: tw-all-iter
#tw-all: tw-all.stamp

tw-all-iter: t-xml-iter standoff-iter

tw-all.stamp: $(XML) tokwrap
	$(TOKWRAP) -t all $(XML)
	touch $@
CLEAN_FILES += tw-all.stamp

##-- iter vs. all
## + time make -j2 standoff-iter ~ 971.9 Kbyte/sec
##	real	0m28.879s
##	user	0m45.739s
##	sys	0m1.776s
## + time make TOKWRAP_OPTS="-keep -trace" tw-all ~ 784.5 Kbyte/sec
##	real	0m35.778s
##	user	0m34.778s
##	sys	0m0.984s
## + time make -j1 standoff-iter ~ 609.4 Kbyte/sec
##	real	0m46.060s
##	user	0m44.351s
##	sys	0m1.636s


##======================================================================
## Rules: archiving

arc: $(arcfile)
no-arc: ; rm -rf $(arcfile) $(arcname)
$(arcfile): $(ARC_TARGETS)
	rm -rf $(arcname) $(arcfile)
	mkdir $(arcname)
	for f in $(ARC_TARGETS); do \
	  test -e $(arcname)/$$f || ln -s ../$$f $(arcname)/$$f; \
	done
	tar czhvf $@ $(arcname)
	rm -rf $(arcname)
	@echo "Created archive $@"


##======================================================================
## Rules: utility programs (inplace="yes" only!)

programs: $(PROG_DEPS)
ifeq "$(inplace)" "yes"
	$(MAKE) -C "$(PROG_DIR)" all
else
	true
endif

##======================================================================
## Rules: perl module (inplace="yes" only!)

##--
ifeq "$(inplace)" "yes"

tokwrap: programs pm

pm: $(TOKWRAP_DIR)/Makefile
	$(MAKE) -C $(TOKWRAP_DIR)

$(TOKWRAP_DIR)/Makefile: $(TOKWRAP_DIR)/Makefile.PL
	(cd $(TOKWRAP_DIR); $(PERL) Makefile.PL)

else
##-- ifeq "$(inplace)" "yes": else

tokwrap:
	true

pm:
	true

endif
##-- ifeq "$(inplace)" "yes": endif


##======================================================================
## Rules: cleanup
clean: $(CLEAN_DEPS)
	rm -f $(CLEAN_FILES)

realclean: $(REALCLEAN_DEPS)
	rm -f $(REALCLEAN_FILES)
