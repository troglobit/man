UNIX Manual Pages
=================

Scripts, Makefiles and other glue that make up https://man.troglobit.com,
which holds HTML versions of UNIX manual pages for projects of @troglobit.

Building
--------

    make            fetch the sources and build the site
    make build      rebuild from the sources already fetched
    make serve      build, then preview on http://localhost:8000
    make clean      remove everything generated

Needs `mandoc`, `wget` and GNU make:

    sudo apt install mandoc wget make

`bin/fetch.sh` reads `reporc` and pulls each manual page straight from its
project.  An entry is

    repo [org/]project[@branch] path file...

where `org` defaults to `troglobit`, `branch` to `master` with a fall back to
`main`, and `path` is the directory inside the repository, or `.` for the root.
A page that cannot be fetched fails the build rather than publishing blank.

`bin/man.sh` then renders every page with mandoc and wraps it in
`template/header.html` and `template/footer.html`.  It also writes the section
indexes, the front page, `sitemap.xml`, `robots.txt` and `404.html`.  Page descriptions come from each page's own NAME
section, so nothing has to be written twice.

Manual pages that are not carried here, but are referenced in a SEE ALSO, are
repointed at manpages.debian.org.  `BASEURL` overrides the canonical site URL,
for staging.

Pages in `ext/` are third party and are copied in verbatim before the build.

----

Please report bugs and spelling errors separately with each project at
https://github.com/troglobit/, preferably as a pull-request.
