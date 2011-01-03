VERSION = $(shell sed -e '/Version:/!d' \
                      -e 's/[^0-9.]*\([0-9.]*\).*/\1/' \
                      -e q baracus.spec )

TARBALL = baracus-$(VERSION).tar.bz2

root   ?= ./root
prefix ?= /

.PHONY: clean
clean:
	rm     baracus-*.tar.bz2
	rm -rf baracus-?.*.*

$(TARBALL): Makefile baracus.spec
	git archive --format=tar --prefix=baracus-$(VERSION)/ HEAD:root/ | bzip2 > $(TARBALL)

.PHONY: tar
tar: $(TARBALL)

.PHONY: untar
untar: $(TARBALL)
	tar xf $(TARBALL)

.PHONY: install
install: untar
	mkdir -p    $(prefix)
	rsync -Savu $(root)/* $(prefix)/.
	rm          $(prefix)/var/spool/baracus/www/htdocs/blank.html
	rm    -rf   $(prefix)/usr/share/baracus/utils
	rm    -rf   $(prefix)/var/spool/baracus/templates
	mkdir       $(prefix)/var/spool/baracus/isos
	mkdir       $(prefix)/var/spool/baracus/images
	mkdir       $(prefix)/var/spool/baracus/logs
	mkdir       $(prefix)/var/spool/baracus/pgsql
	mkdir       $(prefix)/var/spool/baracus/www/tmp
	mkdir       $(prefix)/var/spool/baracus/www/htdocs/pool
	mkdir -p    $(prefix)/var/spool/baracus/builds/winstall/import/amd64
	mkdir -p    $(prefix)/var/spool/baracus/builds/winstall/import/x86
