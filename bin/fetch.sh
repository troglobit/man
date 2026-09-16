#!/bin/sh
# Fetch upstream manual page sources listed in a reporc file.
#
# A miss used to leave a zero byte file behind, which mandoc happily turned
# into a blank published page, so every fetch is now staged and verified
# before it replaces anything.

set -u

RC=${1:-}
if [ -z "$RC" ]; then
	echo "usage: fetch.sh /path/to/reporc" >&2
	exit 1
fi
if [ ! -r "$RC" ]; then
	echo "fetch.sh: cannot read $RC" >&2
	exit 1
fi

TOP=$(git rev-parse --show-toplevel)
WORK=$(mktemp -d)
MANIFEST=$TOP/.manifest

trap 'rm -rf "$WORK"' EXIT INT TERM

: > "$WORK/manifest"
: > "$WORK/failed"

jobs=0

raw()
{
	case $4 in
		.|"") echo "https://raw.githubusercontent.com/$1/$2/$3/$5" ;;
		*)    echo "https://raw.githubusercontent.com/$1/$2/$3/$4/$5" ;;
	esac
}

get()
{
	org=$1 proj=$2 branch=$3 path=$4 file=$5
	subd=man"${file##*.}"
	tmp=$WORK/$subd.$file

	if ! wget -q -O "$tmp" "$(raw "$org" "$proj" "$branch" "$path" "$file")" ||
	   [ ! -s "$tmp" ]; then
		# Plenty of projects have moved off master by now.
		if [ "$branch" = master ] &&
		   wget -q -O "$tmp" "$(raw "$org" "$proj" main "$path" "$file")" &&
		   [ -s "$tmp" ]; then
			branch=main
		else
			rm -f "$tmp"
			echo "$org/$proj $path/$file" >> "$WORK/failed"
			return 1
		fi
	fi

	mkdir -p "$TOP/$subd"
	mv "$tmp" "$TOP/$subd/$file"
	echo "$subd/$file	$org/$proj	$branch	$path" >> "$WORK/manifest"
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

sort -o "$MANIFEST" "$WORK/manifest"

if [ -s "$WORK/failed" ]; then
	echo >&2
	echo "fetch.sh: $(wc -l < "$WORK/failed") manual page(s) could not be fetched:" >&2
	sed 's/^/  /' "$WORK/failed" >&2
	echo >&2
	echo "Fix the path or branch in $RC, or drop the entry." >&2
	exit 1
fi

echo "Fetched $(wc -l < "$MANIFEST") manual pages."
