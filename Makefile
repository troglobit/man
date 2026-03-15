REPORC = $(shell pwd)/reporc

all: build

fetch:
	./bin/fetch.sh $(REPORC)

build: fetch
	cp -a ext/* .
	./bin/man.sh

clean:
	rm -rf man1 man3 man5 man8
