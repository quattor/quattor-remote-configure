####################################################################
# Distribution Makefile
####################################################################

.PHONY:	configure install clean

all: configure

#
# BTDIR needs to point to the location of the build tools
#
BTDIR := ../../../../quattor-build-tools
#
#
_btincl   := $(shell ls $(BTDIR)/quattor-buildtools.mk 2>/dev/null || \
             echo quattor-buildtools.mk)
include $(_btincl)

LIBFILES = Quattor/Remote/Component Quattor/Remote/ComponentProxy Quattor/Remote/ComponentProxyList Quattor/Remote/Connector Quattor/Remote/Connector/ESX

####################################################################
# Configure
####################################################################

configure: sbin/$(COMP) $(addprefix lib/perl5/,$(addsuffix .pm,$(LIBFILES)))

####################################################################
# Install
####################################################################

install: configure man
	@echo installing...
	@mkdir -p $(PREFIX)/$(QTTR_SBIN)
	@mkdir -p $(PREFIX)/$(QTTR_ETC)
	@mkdir -p $(PREFIX)/$(QTTR_MAN)/man1
	@mkdir -p $(PREFIX)/$(QTTR_MAN)/man$(NCM_MANSECT)
	@mkdir -p $(PREFIX)/$(QTTR_MAN)/man3
	@mkdir -p $(PREFIX)/$(QTTR_PERLLIB)/Quattor
	@mkdir -p $(PREFIX)/$(QTTR_PERLLIB)/Quattor/Remote
	@mkdir -p $(PREFIX)/$(QTTR_PERLLIB)/Quattor/Remote/Connector
	@mkdir -p $(PREFIX)/$(QTTR_LOCKD)
	@mkdir -p $(PREFIX)/$(QTTR_DOC)
	@mkdir -p $(PREFIX)/$(QTTR_ETC)/not.d

	@if [ -f etc/$(COMP).logrotate ]; then \
	    mkdir -p $(PREFIX)/$(QTTR_ROTATED); \
	    install -m 0444 etc/$(COMP).logrotate $(PREFIX)/$(QTTR_ROTATED)/$(COMP); \
	fi
	@install -m 0755 sbin/$(COMP) $(PREFIX)/$(QTTR_SBIN)/$(COMP)
	@install -m 0444 etc/$(COMP).conf $(PREFIX)/$(QTTR_ETC)/$(COMP).conf

	@for i in $(LIBFILES) ; do \
                echo "installing $$i"; \
		install -m 0555 lib/perl5/$$i.pm \
		    $(PREFIX)/$(QTTR_PERLLIB)/$$i.pm ; \
		target=$$(echo $$i | sed -e 's/\//::/g') ; \
		install -m 0444 lib/perl5/$$target.3pm.gz $(PREFIX)/$(QTTR_MAN)/man3/$$target.3pm.gz ; \
	done


	@install -m 0444 $(COMP).1.gz \
			$(PREFIX)$(QTTR_MAN)/man$(MANSECT)/$(COMP).$(MANSECT).gz

	@for i in LICENSE MAINTAINER ChangeLog README ; do \
		install -m 0444 $$i $(PREFIX)/$(QTTR_DOC)/$$i ; \
		install -m 0444 etc/$(COMP).conf \
			    $(PREFIX)/$(QTTR_DOC)/$(COMP).conf.example ; \
	done

man: configure 
	@pod2man $(_podopt) sbin/$(COMP) >$(COMP).1
	@gzip -f $(COMP).1
	@for i in $(LIBFILES); do \
                echo "manifying $$i"; \
		target=$$(echo $$i | sed -e 's/\//::/g') ; \
		pod2man $(_podopt) lib/perl5/$$i.pm > lib/perl5/$$target.3pm ; \
		gzip -f lib/perl5/$$target.3pm ; \
	done

clean::
	@echo cleaning $(NAME) files ...
	@rm -f $(COMP) $(COMP).pod $(NAME).$(NCM_MANSECT) \
		$(addprefix lib/perl5/, $(addsuffix .pm,$(LIBFILES))) \
                $(addprefix CERN-CC/,$(CERN_CC_SOURCES))
	@rm -rf TEST

