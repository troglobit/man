#!/bin/sh
# Fetch upstream manual page sources listed in a reporc file.
#
# Every fetch is staged and verified before it replaces anything, since
# mandoc turns an empty file into a blank published page.  A page that
# comes back unchanged is left alone, so its mtime still tells make what
# needs rebuilding.
#
# Project names after the reporc file limit the fetch to those projects.

set -u

RC=${1:-}
if [ -z "$RC" ]; then
	echo "usage: fetch.sh /path/to/reporc [project ...]" >&2
	exit 1
fi
if [ ! -r "$RC" ]; then
	echo "fetch.sh: cannot read $RC" >&2
	exit 1
fi
shift
ONLY=$*

# The dot command looks a bare name up in PATH.
case $RC in
	/*) ;;
	*)  RC=$PWD/$RC ;;
esac

TOP=$(git rev-parse --show-toplevel)
WORK=$(mktemp -d)
MANIFEST=$TOP/.manifest

trap 'rm -rf "$WORK"' EXIT INT TERM

: > "$WORK/manifest"
: > "$WORK/failed"
: > "$WORK/changed"
: > "$WORK/seen"
[ -f "$MANIFEST" ] || : > "$MANIFEST"

jobs=0

raw()
{
	case $4 in
		.|"") echo "https://raw.githubusercontent.com/$1/$2/$3/$5" ;;
		*)    echo "https://raw.githubusercontent.com/$1/$2/$3/$4/$5" ;;
	esac
}

# Download $1 to $2, unless the ETag $3 still holds.  Prints the ETag on
# a download and nothing on a match.
download()
{
	url=$1 tmp=$2 etag=$3

	if [ -n "$etag" ]; then
		set -- -H "If-None-Match: $etag"
	else
		set --
	fi

	code=$(curl -s "$@" -o "$tmp" -D "$tmp.hdr" -w '%{http_code}' "$url") || return 1
	case $code in
		200) [ -s "$tmp" ] && sed -n 's/^etag: *//Ip' "$tmp.hdr" | tr -d '\r' ;;
		304) ;;
		*)   return 1 ;;
	esac
}

get()
{
	org=$1 proj=$2 branch=$3 path=$4 file=$5
	subd=man"${file##*.}"
	rel=$subd/$file
	dst=$TOP/$rel
	tmp=$WORK/$subd.$file
	etag=$(awk -F'\t' -v f="$rel" '$1 == f { print $5; exit }' "$MANIFEST")
	[ -s "$dst" ] || etag=

	if ! new=$(download "$(raw "$org" "$proj" "$branch" "$path" "$file")" "$tmp" "$etag"); then
		# Plenty of projects have moved off master by now.
		if [ "$branch" = master ] &&
		   new=$(download "$(raw "$org" "$proj" main "$path" "$file")" "$tmp" "$etag"); then
			branch=main
		else
			echo "$org/$proj $path/$file" >> "$WORK/failed"
			return 1
		fi
	fi

	if [ -n "$new" ]; then
		etag=$new
		mkdir -p "$TOP/$subd"
		if ! cmp -s "$tmp" "$dst"; then
			mv "$tmp" "$dst"
			echo "$rel" >> "$WORK/changed"
		fi
	fi

	echo "$rel	$org/$proj	$branch	$path	$etag" >> "$WORK/manifest"
}

repo()
{
	spec=$1
	path=$2
	shift 2

	case $spec in
		*@*) branch="${spec##*@}"; spec="${spec%@*}" ;;
		*)   branch=master ;;
	esac

	case $spec in
		*/*) org="${spec%%/*}"; proj="${spec##*/}" ;;
		*)   org=troglobit;     proj="$spec"       ;;
	esac

	case " $ONLY " in
		"  "|*" $proj "*|*" $org/$proj "*) ;;
		*) return ;;
	esac

	echo "$org/$proj" >> "$WORK/seen"
	echo "Fetching $org/$proj ..."

	for file in "$@"; do
		get "$org" "$proj" "$branch" "$path" "$file" &

		# Be a good citizen: a couple of dozen repos at once is plenty.
		jobs=$((jobs + 1))
		if [ $((jobs % 8)) -eq 0 ]; then
			wait
		fi
	done
}

. "$RC"
wait

if [ ! -s "$WORK/seen" ]; then
	echo "fetch.sh: no project matching '$ONLY' in $RC" >&2
	exit 1
fi

if [ -s "$WORK/failed" ]; then
	echo >&2
	echo "fetch.sh: $(wc -l < "$WORK/failed") manual page(s) could not be fetched:" >&2
	sed 's/^/  /' "$WORK/failed" >&2
	echo >&2
	echo "Fix the path or branch in $RC, or drop the entry." >&2
	exit 1
fi

# Projects not fetched this run keep their old entries.
awk -F'\t' 'NR == FNR { seen[$1]; next } !($2 in seen)' "$WORK/seen" "$MANIFEST" \
	>> "$WORK/manifest"
sort -o "$MANIFEST" "$WORK/manifest"

echo "Fetched $(wc -l < "$MANIFEST") manual pages, $(wc -l < "$WORK/changed") changed."
