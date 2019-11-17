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
