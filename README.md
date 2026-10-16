UNIX Manual Pages
=================

Scripts, Makefiles and other glue that make up https://man.troglobit.com,
which holds HTML versions of UNIX manual pages for projects of @troglobit.

Building
--------

    make            fetch the sources and build the site
    make REPO=kg    fetch only the pages of one project, then build
    make build      rebuild from the sources already fetched
    make serve      build, then preview on http://localhost:8000
    make clean      remove everything generated

Needs `mandoc`, `curl` and GNU make 4.3 or later:

    sudo apt install mandoc curl make

`bin/fetch.sh` reads `reporc` and pulls each manual page straight from its
project.  An entry is

    repo [org/]project[@branch] path file...

where `org` defaults to `troglobit`, `branch` to `master` with a fall back to
`main`, and `path` is the directory inside the repository, or `.` for the root.
A page that cannot be fetched fails the build rather than publishing blank.
Pages are fetched conditionally, with the ETag kept in `.manifest`, and a
page that comes back unchanged is left untouched.  A page dropped from
`reporc` is removed on the next fetch.  `REPO` names one or more projects,
by `project` or `org/project`, to fetch only those.

`bin/page.sh` renders one page with mandoc and wraps it in
`template/header.html` and `template/footer.html`.  `bin/site.sh` then writes
the section indexes, the front page, `pages.json` for the search box,
`sitemap.xml`, `robots.txt` and `404.html`.  Page descriptions come from each
page's own NAME section, so nothing has to be written twice.

Only pages whose source, template or script changed are rendered again, so
`make` after a fetch only re-renders what the fetch changed.  `make -j`
renders pages in parallel.

Manual pages that are not carried here, but are referenced in a SEE ALSO, are
repointed at manpages.debian.org.  `BASEURL` overrides the canonical site URL,
for staging.

Pages in `ext/` are third party and are copied in verbatim before the build.

----

Please report bugs and spelling errors separately with each project at
https://github.com/troglobit/, preferably as a pull-request.
