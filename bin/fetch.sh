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
    org=$2
    proj=$3
    path=$4
    file=$5

    mkdir -p $subd
    wget -nv -O $subd/$file https://raw.githubusercontent.com/$org/$proj/master/$path/$file &
}

repo()
{
    arg=$1
    path=$2
    shift 2

    case "$arg" in
	*/*)
	    org="${arg%%/*}"
	    proj="${arg##*/}"
	    ;;
	*)
	    org="troglobit"
	    proj="$arg"
	    ;;
    esac

    echo "Fetching man pages from $org/$proj ..."

    for file in $*; do
	subd=man"${file##*.}"
	fetch $subd $org $proj $path $file
    done
}

. $1

wait
