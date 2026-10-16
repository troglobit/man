# Shared setup for page.sh and site.sh.  Not a program.

TOP=$(cd "$(dirname "$0")/.." && pwd)
HEAD=$TOP/template/header.html
FOOT=$TOP/template/footer.html
BASEURL=${BASEURL:-https://man.troglobit.com}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM

cd "$TOP" || exit 1

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

# file<TAB>names<TAB>description from the NAME section of each file given,
# a mandoc fragment or a finished page, which embeds the fragment as is.
# mdoc separates names and description with an em dash, man(7) with a
# plain hyphen.
name_desc()
{
	awk '
	function trim(s) { sub(/^ +/, "", s); sub(/ +$/, "", s); return s }
	function emit(   i, names, desc) {
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
		buf = trim(buf)
		if ((i = index(buf, "\037")) > 0) {
			names = substr(buf, 1, i - 1)
			desc = substr(buf, i + 1)
			if ((i = index(desc, "\037")) > 0)
				desc = substr(desc, 1, i - 1)
		} else if ((i = index(buf, " - ")) > 0) {
			names = substr(buf, 1, i - 1)
			desc = substr(buf, i + 3)
		} else {
			names = buf
			desc = ""
		}
		print file "\t" trim(names) "\t" trim(desc)
		buf = ""
		grab = 0
	}
	FNR == 1			{ if (NR > 1) emit(); file = FILENAME }
	/<h1 class="Sh" id="NAME"/	{ grab = 1; next }
	grab && /<\/section>/		{ nextfile }
	grab				{ buf = buf " " $0 }
	END				{ if (NR > 0) emit() }
	' "$@"
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
