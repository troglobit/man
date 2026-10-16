#!/bin/sh
# Generate everything around the manual pages: the section indexes, the
# front page, pages.json for the search box, sitemap.xml, robots.txt and
# the 404 page.  Page descriptions come out of each rendered page's own
# NAME section, so a page only has to be written once.

set -u

. "$(dirname "$0")/lib.sh"

SITE="Troglobit Manual Pages"
META=$WORK/meta

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

section_count()
{
	awk -F'\t' -v s="$1" '$3 == s' "$META" | wc -l
}

# Section directory links for the front and 404 pages.
section_links()
{
	prefix=$1

	for sect in 1 2 3 5 8; do
		count=$(section_count "$sect")
		[ "$count" -gt 0 ] || continue
		cat <<EOT
<a href="${prefix}man$sect/index.html" data-s="$sect"><span class="n">$sect</span><span class="t">$(section_name "$sect")<span class="c">$(pages_count "$count")</span></span></a>
EOT
	done
}

esc_json()
{
	sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# rel<TAB>name<TAB>section<TAB>description<TAB>names for every page.
: > "$META"
set -- man[12358]/*.[12358].html
[ -e "$1" ] && name_desc "$@" | awk -F'\t' -v OFS='\t' '
{
	sect = substr($1, 4, 1)
	name = $1
	sub(/^man[0-9]\//, "", name)
	sub("\\." sect "\\.html$", "", name)
	print $1, name, sect, $3, $2
}' > "$META"

###############################################################################
# Section indexes
###############################################################################

for sect in 1 2 3 5 8; do
	rel=man$sect/index.html
	sn=$(section_name "$sect")
	count=$(section_count "$sect")

	[ "$count" -gt 0 ] || continue

	echo "Updating $rel ..."
	emit_head "Section $sect: $sn" \
		  "$(pages_count "$count") in section $sect of $SITE: $sn." \
		  "$sect" "../" "$BASEURL/$rel" plain > "$rel"

	cat >> "$rel" <<EOT
<nav class="crumbs" aria-label="Breadcrumb"><a href="../index.html">man</a><span class="sep">/</span><b>$sect</b></nav>
<article class="page">
<h1 class="title">Section $sect</h1>
<p class="lead">$sn.  $(pages_count "$count").</p>
<table class="index">
<tbody>
EOT

	awk -F'\t' -v s="$sect" '$3 == s { print }' "$META" | sort -t"$(printf '\t')" -k2,2 |
	awk -F'\t' '
	{
		d = $4
		gsub(/&/, "\\&amp;", d)
		gsub(/</, "\\&lt;", d)
		gsub(/>/, "\\&gt;", d)
		gsub(/"/, "\\&quot;", d)
		u = $1
		sub(/^.*\//, "", u)
		printf "<tr><td class=\"nm\"><a href=\"%s\">%s(%s)</a></td><td class=\"nd\">%s</td></tr>\n", u, $2, $3, d
	}' >> "$rel"

	cat >> "$rel" <<EOT
</tbody>
</table>
</article>
EOT
	emit_foot "../" >> "$rel"
done

###############################################################################
# Front page
###############################################################################

echo "Updating index.html ..."
emit_head "$SITE" \
	  "HTML manual pages for the free software projects of Joachim Wiberg, generated from each project's own sources." \
	  "" "" "$BASEURL/" plain > index.html

cat >> index.html <<'EOT'
<article class="page">
<h1 class="title">UNIX manual pages</h1>
<p class="lead">The manual pages that ship with Joachim Wiberg's free software
projects, rebuilt from each project's own sources.  Pick a section, or search
from the box above.</p>
<nav class="dir">
EOT
section_links "" >> index.html
cat >> index.html <<'EOT'
</nav>
<p class="src">Built with <a href="https://mandoc.bsd.lv/">mandoc</a>.  For the
manual as it was, see the <a href="https://archive.org/details/UNIXManRel5">UNIX
System V User's Manual</a>.</p>
</article>
EOT
emit_foot "" >> index.html

###############################################################################
# Search index
###############################################################################

echo "Updating pages.json ..."
esc_json < "$META" | sort -t"$(printf '\t')" -k2,2 -k3,3 > "$WORK/meta.json"
{
	printf '['
	awk -F'\t' '
	{
		if (NR > 1)
			printf ","
		printf "{\"u\":\"%s\",\"n\":\"%s\",\"s\":\"%s\",\"d\":\"%s\"", \
		       $1, $2, $3, $4
		if ($5 != "" && $5 != $2) {
			n = split($5, a, /, */)
			printf ",\"a\":["
			for (i = 1; i <= n; i++)
				printf "%s\"%s\"", (i > 1 ? "," : ""), a[i]
			printf "]"
		}
		printf "}"
	}' "$WORK/meta.json"
	printf ']\n'
} > pages.json

###############################################################################
# robots.txt, sitemap.xml and the 404 page
###############################################################################

echo "Updating sitemap.xml ..."
{
	printf '<?xml version="1.0" encoding="UTF-8"?>\n'
	printf '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
	printf '<url><loc>%s/</loc></url>\n' "$BASEURL"
	for sect in 1 2 3 5 8; do
		[ "$(section_count "$sect")" -gt 0 ] || continue
		printf '<url><loc>%s/man%s/index.html</loc></url>\n' "$BASEURL" "$sect"
	done
	cut -f1 "$META" | sort |
	while read -r rel; do
		printf '<url><loc>%s/%s</loc></url>\n' "$BASEURL" "$rel"
	done
	printf '</urlset>\n'
} > sitemap.xml

echo "Updating robots.txt ..."
cat > robots.txt <<EOT
User-agent: *
Allow: /

Sitemap: $BASEURL/sitemap.xml
EOT

echo "Updating 404.html ..."
# Served for any path, so this one page links absolutely.
emit_head "Page not found" "That manual page is not on this site." \
	  "" "/" "$BASEURL/404.html" plain > 404.html
cat >> 404.html <<'EOT'
<article class="page">
<h1 class="title">No such manual page</h1>
<p class="lead">Nothing is filed under that name here.  Search from the box
above, or browse a section.</p>
<nav class="dir">
EOT
section_links "/" >> 404.html
cat >> 404.html <<'EOT'
</nav>
</article>
EOT
emit_foot "/" >> 404.html

echo "Done.  $(wc -l < "$META") manual pages."
