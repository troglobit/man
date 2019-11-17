
all: fetch build

fetch:
	./bin/fetch.sh

build:
	./bin/man.sh

clean:
	rm -rf man1 man3 man5 man8
