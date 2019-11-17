#!/bin/sh -e
# Generates HTML versions of man pages using mandoc

GEN=`which mandoc`
TOP=`git rev-parse --show-toplevel`
HEAD=$TOP/template/header.html
FOOT=$TOP/template/footer.html

for file in `ls $TOP/man[1358]/*.[1358]`; do
    name=`basename $file`
    dir=$(basename `dirname $file`)
    web=$TOP/$dir/$name.html
    echo "Updating $web ..."
    cat $HEAD                        >  $web
    mandoc -T html -O fragment $file >> $web
    cat $FOOT                        >> $web
    sed -i "s/%TITLE%/$name/"           $web
done

for dir in `find $TOP/man[1358] -type d`; do
    cd $dir
    section=`basename $dir | cut -c 4`

    echo "Creating $dir/index.html ..."
    cat $HEAD                        >   index.html
    echo "<ul>"                      >>  index.html
    for file in `find . -name '*.html'`; do
	man=`basename $file .html`
	url=`basename $file`
	echo "<li><a href=\"$url\">$man</a></li>" >> index.html
    done
    echo "</ul>"                     >>  index.html
    cat $FOOT                        >>  index.html
    sed -i "s/%TITLE%/Section $section/" index.html
done
