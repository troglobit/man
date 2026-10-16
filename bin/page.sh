#!/bin/sh
# Render one manual page: template/header.html + breadcrumb + contents +
# the mandoc fragment + template/footer.html.
#
#   page.sh man1/foo.1 man1/foo.1.html

set -u

. "$(dirname "$0")/lib.sh"

MANIFEST=$TOP/.manifest
MIRROR=${MIRROR:-https://git.troglobit.com}

src=${1:-} out=${2:-}
if [ -z "$src" ] || [ -z "$out" ]; then
	echo "usage: page.sh manN/name.N manN/name.N.html" >&2
	exit 1
fi

if ! command -v mandoc >/dev/null; then
	echo "Missing mandoc, try: sudo apt install mandoc" >&2
	exit 1
fi

dir=${src%/*}
sect=${dir#man}
file=${src##*/}
name=${file%".$sect"}
body=$WORK/body.html

mandoc -T html -O "fragment,man=../man%S/%N.%S.html" "$src" > "$body"

desc=$(name_desc "$body" | cut -f3)

if [ -n "$desc" ]; then
	title="$name($sect) — $desc"
else
	title="$name($sect)"
fi

# Cross references that point at pages this site does not carry go to
# manpages.debian.org, and .Xr used for a file path is set as a path.
: > "$WORK/fixups.sed"
grep -o 'href="\.\./man[^"]*\.html"' "$body" | sort -u |
while read -r href; do
	target=$(printf '%s' "$href" | sed -e 's/^href="\.\.\///' -e 's/"$//')
	case $target in
		*/index.html) continue ;;
	esac
	[ -e "${target%.html}" ] && continue

	# A stray bracket in an upstream .Xr ends up inside the name, so pick
	# the section and the name out rather than splitting on them.
	xsect=$(printf '%s' "$target" | sed -n 's|^man\([0-9]\).*|\1|p')
	page=${target##*/}
	xname=$(printf '%s' "$page" | sed -e "s/\.$xsect[^.]*\.html\$//" -e 's/\.html$//')
	pattern=$(printf '%s' "$href" | sed 's/[.[\*^$]/\\&/g')

	case $xname in
		""|*/*)
			printf '%s\n' \
			       "s|<a class=\"Xr\" $pattern>\\([^<]*\\)</a>|<span class=\"Pa\">\\1</span>|g" \
			       >> "$WORK/fixups.sed"
			continue
			;;
		*://*)	repl=$(printf '%s' "$xname" | sed 's|/*$|/|') ;;
		*)	repl="https://manpages.debian.org/$xname.$xsect" ;;
	esac

	repl=$(printf '%s' "$repl" | sed 's/[&\\]/\\&/g')
	printf 's|%s|href="%s"|g\n' "$pattern" "$repl" >> "$WORK/fixups.sed"
done

emit_head "$title" "$desc" "$sect" "../" "$BASEURL/$out" > "$out"

cat >> "$out" <<EOT
<nav class="crumbs" aria-label="Breadcrumb"><a href="../index.html">man</a><span class="sep">/</span><a href="index.html">$sect</a><span class="sep">/</span><b>$name</b></nav>
EOT

# id<TAB>text for every .Sh heading, in document order.
awk '
/<h1 class="Sh" id="/	{ grab = 1; buf = "" }
grab			{ buf = buf " " $0 }
grab && /<\/h1>/ {
	grab = 0
	id = buf
	sub(/^.*<h1 class="Sh" id="/, "", id)
	sub(/".*$/, "", id)
	txt = buf
	gsub(/<[^>]*>/, "", txt)
	gsub(/[ \t]+/, " ", txt)
	sub(/^ /, "", txt)
	sub(/ $/, "", txt)
	print id "\t" txt
}' "$body" > "$WORK/toc"

if [ "$(wc -l < "$WORK/toc")" -ge 3 ]; then
	{
		printf '<aside class="toc"><details open><summary>Contents</summary><ol>\n'
		while IFS="$(printf '\t')" read -r id txt; do
			printf '<li><a href="#%s">%s</a></li>\n' \
			       "$(printf '%s' "$id" | esc_html)" \
			       "$(printf '%s' "$txt" | esc_html)"
		done < "$WORK/toc"
		printf '</ol></details></aside>\n'
	} >> "$out"
fi

printf '<article class="page">\n' >> "$out"
sed -f "$WORK/fixups.sed" "$body" >> "$out"

# Where the page came from, looked up through any symlink.
real=$(readlink -f "$src")
real=${real#"$TOP"/}
prov=
[ -f "$MANIFEST" ] &&
prov=$(awk -F'\t' -v f="$real" '$1 == f { print $2 "\t" $3 "\t" $4; exit }' "$MANIFEST")
if [ -n "$prov" ]; then
	proj=$(printf '%s' "$prov" | cut -f1)
	branch=$(printf '%s' "$prov" | cut -f2)
	path=$(printf '%s' "$prov" | cut -f3)
	case $path in
		.|"") blob=$file	;;
		*)    blob=$path/$file	;;
	esac
	# git.troglobit.com mirrors GitHub's blob paths, so the same
	# branch and path reach the file on either.
	cat >> "$out" <<EOT
<p class="src">Maintained in <a href="https://github.com/$proj">$proj</a> as <a href="https://github.com/$proj/blob/$branch/$blob">$blob</a>.  Send corrections there, or read it on the <a href="$MIRROR/github.com/$proj/blob/$branch/$blob">mirror</a>.</p>
EOT
fi

printf '</article>\n' >> "$out"
emit_foot "../" >> "$out"
