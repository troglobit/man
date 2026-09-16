#!/bin/sh
# Generate the HTML manual pages, the section indexes and the search index.
#
# Every page is assembled as template/header.html + breadcrumb + contents +
# the mandoc fragment + template/footer.html.  Page descriptions come out of
# each page's own NAME section, so a page only has to be written once.

set -u

GEN=$(command -v mandoc)
if [ -z "$GEN" ]; then
	echo "Missing mandoc, try: sudo apt install mandoc" >&2
	exit 1
fi

TOP=$(git rev-parse --show-toplevel)
HEAD=$TOP/template/header.html
FOOT=$TOP/template/footer.html
MANIFEST=$TOP/.manifest
BASEURL=${BASEURL:-https://man.troglobit.com}
SITE="Troglobit Manual Pages"
MIRROR=${MIRROR:-https://git.troglobit.com}

WORK=$(mktemp -d)
META=$WORK/meta
trap 'rm -rf "$WORK"' EXIT INT TERM

: > "$META"
[ -f "$MANIFEST" ] || : > "$MANIFEST"

pages_count()
{
	if [ "$1" -eq 1 ]; then
		echo "1 page"
	else
		echo "$1 pages"
	fi
}

section_name()
{
	case $1 in
		1) echo "User commands"				;;
		2) echo "System calls"				;;
		3) echo "Library functions"			;;
		5) echo "File formats and conventions"		;;
		8) echo "System administration"			;;
		*) echo "Manual pages"				;;
	esac
}

# Replace %KEY% placeholders in a template without letting sed loose on
# text that legitimately contains slashes, ampersands and backslashes.
fill()
{
	awk -v map="$WORK/map" '
	function rep(s, k, v,   out, p) {
		while ((p = index(s, k)) > 0) {
			out = out substr(s, 1, p - 1) v
			s = substr(s, p + length(k))
		}
		return out s
	}
	BEGIN {
		while ((getline line < map) > 0) {
			i = index(line, "\t")
			key[++n] = substr(line, 1, i - 1)
			val[n]   = substr(line, i + 1)
		}
	}
	{
		for (j = 1; j <= n; j++)
			$0 = rep($0, key[j], val[j])
		print
	}' "$1"
}

esc_html()
{
	sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

esc_json()
{
	sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# The NAME section of a mandoc fragment, flattened to "names<US>description".
# mdoc separates the two with an em dash, man(7) with a plain hyphen.
name_line()
{
	awk '
	/<h1 class="Sh" id="NAME"/	{ grab = 1; next }
	grab && /<\/section>/		{ exit }
	grab				{ buf = buf " " $0 }
	END {
		gsub(/<[^>]*>/, "", buf)
		# mdoc gives an em dash, man(7) anything from a plain hyphen
		# to \(hy, \(en or a real dash entity.
		gsub(/&#x201[0-4];|&#821[0-4];|&mdash;|&ndash;/, "\037", buf)
		gsub(/&#x00A0;|&#xA0;|&nbsp;/, " ", buf)
		gsub(/&lt;/, "<", buf)
		gsub(/&gt;/, ">", buf)
		gsub(/&quot;/, "\"", buf)
		gsub(/&amp;/, "\\&", buf)
		gsub(/[ \t]+/, " ", buf)
		sub(/^ /, "", buf)
		sub(/ $/, "", buf)
		print buf
	}' "$1"
}

split_name_desc()
{
	printf '%s\n' "$1" | awk -F'\037' '
	function trim(s) { sub(/^ +/, "", s); sub(/ +$/, "", s); return s }
	NF > 1 { print trim($1) "\t" trim($2); next }
	{
		i = index($0, " - ")
		if (i > 0)
			print trim(substr($0, 1, i - 1)) "\t" trim(substr($0, i + 3))
		else
			print trim($0) "\t"
	}'
}

# id<TAB>text for every .Sh heading, in document order.
headings()
{
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
	}' "$1"
}

# Where a page came from, looked up through any symlink.
provenance()
{
	real=$(cd "$TOP" && readlink -f "$1")
	real=${real#"$TOP"/}
	awk -F'\t' -v f="$real" '$1 == f { print $2 "\t" $3 "\t" $4; exit }' "$MANIFEST"
}

emit_head()
{
	title=$1 desc=$2 section=$3 prefix=$4 canonical=$5 sheet=${6:-}

	{
		printf '%%TITLE%%\t%s\n'       "$(printf '%s' "$title" | esc_html)"
		printf '%%DESCRIPTION%%\t%s\n' "$(printf '%s' "$desc" | esc_html)"
		printf '%%SECTION%%\t%s\n'     "$section"
		printf '%%PREFIX%%\t%s\n'      "$prefix"
		printf '%%CANONICAL%%\t%s\n'   "$canonical"
		printf '%%SHEET%%\t%s\n'       "$sheet"
	} > "$WORK/map"

	fill "$HEAD"
}

emit_foot()
{
	printf '%%PREFIX%%\t%s\n' "$1" > "$WORK/map"
	fill "$FOOT"
}

###############################################################################
# Manual pages
###############################################################################

for src in "$TOP"/man[12358]/*.[12358]; do
	[ -e "$src" ] || continue

	dir=$(basename "$(dirname "$src")")
	sect=${dir#man}
	file=$(basename "$src")
	name=$(basename "$file" ".$sect")
	rel=$dir/$name.$sect.html
	out=$TOP/$rel
	body=$WORK/body.html

	mandoc -T html -O "fragment,man=../man%S/%N.%S.html" "$src" > "$body"

	nd=$(split_name_desc "$(name_line "$body")")
	names=$(printf '%s' "$nd" | cut -f1)
	desc=$(printf '%s' "$nd" | cut -f2)

	if [ -n "$desc" ]; then
		title="$name($sect) — $desc"
	else
		title="$name($sect)"
	fi

	echo "Updating $rel ..."
	emit_head "$title" "$desc" "$sect" "../" "$BASEURL/$rel" > "$out"

	cat >> "$out" <<EOF
<nav class="crumbs" aria-label="Breadcrumb"><a href="../index.html">man</a><span class="sep">/</span><a href="index.html">$sect</a><span class="sep">/</span><b>$name</b></nav>
EOF

	headings "$body" > "$WORK/toc"
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
	cat "$body" >> "$out"

	prov=$(provenance "$dir/$file")
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
		cat >> "$out" <<EOF
<p class="src">Maintained in <a href="https://github.com/$proj">$proj</a> as <a href="https://github.com/$proj/blob/$branch/$blob">$blob</a>.  Send corrections there, or read it on the <a href="$MIRROR/github.com/$proj/blob/$branch/$blob">mirror</a>.</p>
EOF
	fi

	printf '</article>\n' >> "$out"
	emit_foot "../" >> "$out"

	printf '%s\t%s\t%s\t%s\t%s\n' "$rel" "$name" "$sect" "$desc" "$names" >> "$META"
done

###############################################################################
# Section indexes
###############################################################################

for dir in "$TOP"/man[12358]; do
	[ -d "$dir" ] || continue

	sect=$(basename "$dir")
	sect=${sect#man}
	rel=man$sect/index.html
	out=$TOP/$rel
	sn=$(section_name "$sect")
	count=$(awk -F'\t' -v s="$sect" '$3 == s' "$META" | wc -l)

	[ "$count" -gt 0 ] || continue

	echo "Updating $rel ..."
	emit_head "Section $sect: $sn" \
		  "$(pages_count "$count") in section $sect of $SITE: $sn." \
		  "$sect" "../" "$BASEURL/$rel" plain > "$out"

	cat >> "$out" <<EOF
<nav class="crumbs" aria-label="Breadcrumb"><a href="../index.html">man</a><span class="sep">/</span><b>$sect</b></nav>
<article class="page">
<h1 class="title">Section $sect</h1>
<p class="lead">$sn.  $(pages_count "$count").</p>
<table class="index">
<tbody>
EOF

	awk -F'\t' -v s="$sect" '$3 == s { print }' "$META" | sort -t"$(printf '\t')" -k2,2 |
	while IFS="$(printf '\t')" read -r purl pname psect pdesc pnames; do
		cat >> "$out" <<EOF
<tr><td class="nm"><a href="$(basename "$purl")">$pname($psect)</a></td><td class="nd">$(printf '%s' "$pdesc" | esc_html)</td></tr>
EOF
	done

	cat >> "$out" <<EOF
</tbody>
</table>
</article>
EOF
	emit_foot "../" >> "$out"
done

###############################################################################
# Front page
###############################################################################

echo "Updating index.html ..."
emit_head "$SITE" \
	  "HTML manual pages for the free software projects of Joachim Wiberg, generated from each project's own sources." \
	  "" "" "$BASEURL/" plain > "$TOP/index.html"

cat >> "$TOP/index.html" <<'EOF'
<article class="page">
<h1 class="title">UNIX manual pages</h1>
<p class="lead">The manual pages that ship with Joachim Wiberg's free software
projects, rebuilt from each project's own sources.</p>
<nav class="dir">
EOF

for sect in 1 2 3 5 8; do
	count=$(awk -F'\t' -v s="$sect" '$3 == s' "$META" | wc -l)
	[ "$count" -gt 0 ] || continue
	cat >> "$TOP/index.html" <<EOF
<a href="man$sect/index.html" data-s="$sect"><span class="n">$sect</span><span class="t">$(section_name "$sect")<span class="c">$(pages_count "$count")</span></span></a>
EOF
done

cat >> "$TOP/index.html" <<'EOF'
</nav>
<p class="src">Built with <a href="https://mandoc.bsd.lv/">mandoc</a>.  For the
manual as it was, see the <a href="https://archive.org/details/UNIXManRel5">UNIX
System V User's Manual</a>.</p>
</article>
EOF
emit_foot "" >> "$TOP/index.html"

###############################################################################
# Cross references that point at pages this site does not carry
###############################################################################

echo "Repointing external cross references ..."
: > "$WORK/fixups.sed"
grep -oh 'href="\.\./man[^"]*\.html"' "$TOP"/man[12358]/*.html | sort -u |
while read -r href; do
	target=$(printf '%s' "$href" | sed -e 's/^href="\.\.\///' -e 's/"$//')
	[ -e "$TOP/$target" ] && continue

	case $target in
		*/index.html) continue ;;
	esac

	# A stray bracket in an upstream .Xr ends up inside the name, so pick
	# the section and the name out rather than splitting on them.
	sect=$(printf '%s' "$target" | sed -n 's|^man\([0-9]\).*|\1|p')
	page=${target##*/}
	name=$(printf '%s' "$page" | sed -e "s/\.$sect[^.]*\.html\$//" -e 's/\.html$//')
	pattern=$(printf '%s' "$href" | sed 's/[.[\*^$]/\\&/g')

	case $name in
		# .Xr used for a file path.  A path is not a manual page, so
		# drop the link and set it as one.
		""|*/*)
			printf '%s\n' \
			       "s|<a class=\"Xr\" $pattern>\\([^<]*\\)</a>|<span class=\"Pa\">\\1</span>|g" \
			       >> "$WORK/fixups.sed"
			continue
			;;
	esac

	case $name in
		*://*)	repl=$(printf '%s' "$name" | sed 's|/*$|/|') ;;
		*)	repl="https://manpages.debian.org/$name.$sect" ;;
	esac

	repl=$(printf '%s' "$repl" | sed 's/[&\\]/\\&/g')
	printf 's|%s|href="%s"|g\n' "$pattern" "$repl" >> "$WORK/fixups.sed"
done

if [ -s "$WORK/fixups.sed" ]; then
	sed -i -f "$WORK/fixups.sed" "$TOP"/man[12358]/*.html
	echo "  $(wc -l < "$WORK/fixups.sed") cross reference(s) rewritten"
fi

###############################################################################
# robots.txt, sitemap.xml and the 404 page
###############################################################################

echo "Updating sitemap.xml ..."
{
	printf '<?xml version="1.0" encoding="UTF-8"?>\n'
	printf '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
	printf '<url><loc>%s/</loc></url>\n' "$BASEURL"
	for sect in 1 2 3 5 8; do
		[ -f "$TOP/man$sect/index.html" ] || continue
		printf '<url><loc>%s/man%s/index.html</loc></url>\n' "$BASEURL" "$sect"
	done
	cut -f1 "$META" | sort |
	while read -r rel; do
		printf '<url><loc>%s/%s</loc></url>\n' "$BASEURL" "$rel"
	done
	printf '</urlset>\n'
} > "$TOP/sitemap.xml"

echo "Updating robots.txt ..."
cat > "$TOP/robots.txt" <<EOF
User-agent: *
Allow: /

Sitemap: $BASEURL/sitemap.xml
EOF

echo "Updating 404.html ..."
# Served for any path, so this one page links absolutely.
emit_head "Page not found" "That manual page is not on this site." \
	  "" "/" "$BASEURL/404.html" plain > "$TOP/404.html"
cat >> "$TOP/404.html" <<'EOF'
<article class="page">
<h1 class="title">No such manual page</h1>
<p class="lead">Nothing is filed under that name here.  Browse the sections
below.</p>
<nav class="dir">
EOF
for sect in 1 2 3 5 8; do
	count=$(awk -F'\t' -v s="$sect" '$3 == s' "$META" | wc -l)
	[ "$count" -gt 0 ] || continue
	cat >> "$TOP/404.html" <<EOF
<a href="/man$sect/index.html" data-s="$sect"><span class="n">$sect</span><span class="t">$(section_name "$sect")<span class="c">$(pages_count "$count")</span></span></a>
EOF
done
cat >> "$TOP/404.html" <<'EOF'
</nav>
</article>
EOF
emit_foot "/" >> "$TOP/404.html"

echo
echo "Done.  $(wc -l < "$META") manual pages."
