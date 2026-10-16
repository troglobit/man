# man.troglobit.com
#
#   make          fetch sources and build the site
#   make REPO=kg  fetch only one project, then build
#   make build    rebuild from the sources already fetched
#   make serve    build, then preview on http://localhost:8000
#   make clean    remove everything generated

REPORC  = $(CURDIR)/reporc
PORT   ?= 8000

EXT    := $(patsubst ext/%,%,$(wildcard ext/man[12358]/*.[12358]))
SRC    := $(sort $(wildcard man[12358]/*.[12358]) $(EXT))
HTML   := $(SRC:=.html)
DIRS   := $(patsubst %/,%,$(sort $(dir $(SRC))))
SITE   := index.html 404.html pages.json sitemap.xml robots.txt \
	  $(addsuffix /index.html,$(DIRS))
TMPL   := template/header.html template/footer.html bin/lib.sh

all: fetch
	@$(MAKE) --no-print-directory build

fetch:
	./bin/fetch.sh $(REPORC) $(REPO)

build: $(SITE)

serve: build
	@echo "Serving $(CURDIR) on http://localhost:$(PORT)/ -- ^C to stop"
	@python3 -m http.server $(PORT) --bind 127.0.0.1

clean:
	rm -rf $(DIRS) $(SITE) .manifest .pages

# Third party pages are kept in ext/ and copied in before the build.
$(EXT): %: ext/%
	@mkdir -p $(@D)
	cp $< $@

# A cross reference is repointed when its page is missing here, and the
# provenance line comes from reporc, so every page follows both.
$(HTML): %.html: % bin/page.sh $(TMPL) reporc .pages | $(SRC)
	./bin/page.sh $< $@

$(SITE) &: $(HTML) .pages bin/site.sh $(TMPL)
	./bin/site.sh

# The set of pages, written only when it changes.
.pages: FORCE
	@echo $(SRC) | cmp -s - $@ || echo $(SRC) > $@

FORCE:
.PHONY: all fetch build serve clean FORCE
