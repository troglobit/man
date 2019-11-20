#!/bin/sh -e
# Generates HTML versions of man pages using mandoc

GEN=`which mandoc`
TOP=`git rev-parse --show-toplevel`
HEAD=$TOP/template/header.html
FOOT=$TOP/template/footer.html
MHEAD=$TOP/template/header.man
MFOOT=$TOP/template/footer.man

for file in `ls $TOP/man[12358]/*.[12358]` index.man; do
    name=`basename $file .man`
    dir=$(basename `dirname $file`)
    web=$TOP/$dir/$name.html
    echo "Updating $web ..."
    cat $HEAD                        >  $web
    mandoc -T html -O fragment -O man="../man%S/%N.%S.html" $file >> $web
    cat $FOOT                        >> $web
    sed -i "s/%TITLE%/$name/"           $web
done

for dir in `find $TOP/man[12358] -type d`; do
    cd $dir
    section=`basename $dir | cut -c 4`
    case $section in
	1)
	    sn="User commands"
	    vol="USR"
	    ;;
	2)
	    sn="System calls"
	    vol="KM"
	    ;;
	3)
	    sn="Library functions"
	    vol="PS1"
	    ;;
	5)
	    sn="File formats and conventions"
	    vol="SMM"
	    ;;
	8)
	    sn="Superuser and system administration commands"
	    vol="SMM"
	    ;;
	*)
	    sn=""
	    vol="LOCAL"
	    ;;
    esac
    echo "Creating $dir/index.man"
    cat $MHEAD > index.man
    for file in `find . -name '*.html' |sort`; do
	nm=`basename $file .html`
	if [ "$nm" = "index" ]; then
	    continue
	fi
	man=`basename $nm .$section`
	url=`basename $file`
	echo ".It" >> index.man
	echo ".Lk $url $man($section)" >> index.man
    done
    cat $MFOOT >> index.man
    sed -i "s/%TITLE%/Section $section $vol/" index.man
    sed -i "s/%DESC%/Section $section: $sn/" index.man

    echo "Creating $dir/index.html ..."
    cat $HEAD                        >   index.html
    mandoc -T html -O fragment index.man >> index.html
    cat $FOOT                        >>  index.html
    sed -i "s/%TITLE%/Section $section/" index.html
done
