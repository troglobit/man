#!/bin/sh
# https://raw.githubusercontent.com/[USER-NAME]/[REPOSITORY-NAME]/[BRANCH-NAME]/[FILE-PATH]

RC=$1

if [ "x$RC" = "x" ]; then
    echo "usage: fetch.sh /path/to/reporc"
    exit 1
fi

fetch()
{
    subd=$1
    proj=$2
    path=$3
    file=$4

    mkdir -p $subd
    wget -nv -O $subd/$file https://raw.githubusercontent.com/troglobit/$proj/master/$path/$file &
}

repo()
{
    proj=$1
    path=$2
    shift 2

    echo "Fetching man pages from $proj ..."

    for file in $*; do
	subd=man"${file##*.}"
	fetch $subd $proj $path $file
    done
}

. $1

wait
