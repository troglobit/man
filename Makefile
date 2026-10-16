# man.troglobit.com
#
#   make          fetch sources and build the site
#   make REPO=kg  fetch only one project, then build
#   make build    rebuild from the sources already fetched
#   make serve    build, then preview on http://localhost:8000
#   make clean    remove everything generated

REPORC  = $(CURDIR)/reporc
PORT   ?= 8000

GENERATED = index.html 404.html pages.json sitemap.xml robots.txt .manifest

all: fetch build

fetch:
	./bin/fetch.sh $(REPORC) $(REPO)

build:
	cp -a ext/* .
	./bin/man.sh

serve: build
	@echo "Serving $(CURDIR) on http://localhost:$(PORT)/ -- ^C to stop"
	@python3 -m http.server $(PORT) --bind 127.0.0.1

clean:
	rm -rf man1 man3 man5 man8
	rm -f man2/*.html
	rm -f $(GENERATED)

.PHONY: all fetch build serve clean
