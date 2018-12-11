all:

clean:

install:
	install -D selfextr.sh $(DESTDIR)/usr/bin/selfextr
	install -D README.m4 $(DESTDIR)/usr/share/doc/selfextr/README
	install -D LICENSE $(DESTDIR)/usr/share/doc/selfextr/LICENSE
uninstall:
	rm -f $(DESTDIR)/usr/bin/selfextr
	rm -rf $(DESTDIR)/usr/share/doc/selfextr
