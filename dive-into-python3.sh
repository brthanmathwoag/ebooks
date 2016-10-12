#!/bin/bash

booktitle='Dive into Python 3'
bookid='3f95df991-4e1d-4402-be85-8a3808221a07 '
outputfilename='dive-into-python3.epub'

tmpdir='/tmp/dip3'
inputdir="$tmpdir/in"
outputdir="$tmpdir/out"

function main() {
    if [ ! -e "$inputdir" ]; then
        mkdir -p "$inputdir"
        git clone https://github.com/diveintomark/diveintopython3 "$inputdir"
    fi

    if [ ! -e "$outputdir" ]; then
        mkdir -p "$outputdir"
    fi
    rm -rf "$outputdir/*"
    cp "$inputdir/dip3.css" "$outputdir"
    cp -R "$inputdir/i" "$outputdir"
    rm "$outputdir"/i/.htaccess
    cp "$inputdir"/*.html "$outputdir"

    add_explicit_head_and_body
    remove_javascript
    remove_navigation

    echo -n "application/epub+zip" > "$outputdir/mimetype"

    chapters=$(sed -r 's/<\/?(i|code)[^>]*>//g' "$inputdir/index.html" | sed -rn 's/<li.*?><a href=(.*l)>(.*)<\/a>/\1|\2/p')
    build_container_xml
    build_content_opf
    build_toc_ncx

    (
        cd $outputdir
        zip -X0 "$tmpdir/out.epub" mimetype >> /dev/null
        zip -Xur9D "$tmpdir/out.epub" * >> /dev/null
    )

    mv "$tmpdir/out.epub" "$outputfilename"
    kindlegen "$outputfilename"
    

    #currdir=`pwd`
    #cd "$inputdir"
    #sed -i "s/parser\\.parse(data, encoding='utf-8')/parser\\.parse(data)/" "$inputdir/util/validate.py"
    
    #publish
    #cd "$currdir"
}

function add_explicit_head_and_body() {
    sed -ri 's/<meta charset=utf-8>/<html><head><meta charset=utf-8>/' "$outputdir"/*.html
    sed -ri "s/<meta name=viewport content='initial-scale=1\\.0'>/<meta name=viewport content='initial-scale=1\\.0'><\\/head><body>/" "$outputdir"/*.html
    sed -ri 's/<script src=j\/dip3\.js><\/script>/<\/body><\/html>/' "$outputdir"/*.html
    sed -ri 's/<p id=level>.*//g' "$outputdir"/*.html
}

function remove_javascript() {
    sed -ri 's/<script src=[^>]*>[^>]*<\/script>//g' "$outputdir"/*.html
}

function remove_navigation() {
    sed -ri 's/<p class=v>.*//g' "$outputdir"/*.html
    sed -ri 's/<p class=c>.*//g' "$outputdir"/*.html
    sed -ri 's/<p>You are here:.*//g' "$outputdir"/*.html
    sed -ri 's/<form action=http:\/\/www\.google.com\/cse>.*//g' "$outputdir"/*.html
}

function build_container_xml() {
    mkdir -p "$outputdir/META-INF"
    cat << EOF > "$outputdir/META-INF/container.xml"
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
   <rootfiles>
      <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
   </rootfiles>
</container>
EOF
}

function build_content_opf() {
    cat << EOF > "$outputdir/content.opf"
<?xml version='1.0' encoding='utf-8'?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:opf="http://www.idpf.org/2007/opf" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <dc:language>en</dc:language>
    <dc:title>$booktitle</dc:title>
    <dc:identifier id="uuid_id" opf:scheme="uuid">$bookid</dc:identifier>
    <meta name="cover" content="im_title"/>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml" />
    <item href="index.html" id="pre" media-type="application/xhtml+xml"/>
    $(iterate_chapters append_chapter_to_manifest)
    <item href="i/cover.jpg" id="im_title" media-type="image/jpeg" />
    $(append_images_to_manifest)
  </manifest>
  <spine toc="ncx">
    <itemref idref="pre"/>
    $(iterate_chapters append_chapter_to_spine)
  </spine>
  <guide>
    <reference href="indextutorial.html" title="Contents" type="toc"/>
  </guide>
</package>
EOF
}

function build_toc_ncx() {
    cat << EOF > "$outputdir/toc.ncx"
<?xml version='1.0' encoding='utf-8'?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="eng">
  <head>
    <meta content="$bookid" name="dtb:uid"/>
    <meta content="1" name="dtb:depth"/>
    <meta content="0" name="dtb:totalPageCount"/>
    <meta content="0" name="dtb:maxPageNumber"/>
  </head>
  <docTitle>
    <text>$booktitle</text>
  </docTitle>
  <navMap>
    <navPoint id="pre" playOrder="0">
      <navLabel>
        <text>Preamble</text>
      </navLabel>
      <content src="index.html"/>
    </navPoint>
    $(iterate_chapters append_chapter_to_toc)
  </navMap>
</ncx>
EOF
}

function iterate_chapters() {
    i=0
    echo "$chapters" | while read line; do
        filename=$(echo $line | cut -d'|' -f1)
        title=$(echo $line | cut -d'|' -f2)
        ((i=i+1))
        
        $1 "$i" "$filename" "$title"
    done
}

function append_chapter_to_manifest() {
    echo "    <item href=\"$2\" id=\"ch$1\" media-type=\"application/xhtml+xml\"/>"
}

function append_images_to_manifest() {
    i=0
    (
        cd "$outputdir"
        for filename in $(ls i/*.png); do
            ((i=i+1))
            echo "    <item href=\"$filename\" id=\"im$i\" media-type=\"image/png\"/>"
        done
    )
}

function append_chapter_to_spine() {
    echo "    <itemref idref=\"ch$1\"/>"
}

function append_chapter_to_toc() {
    cat <<-EOF
    <navPoint id="nav$1" playOrder="$1">
      <navLabel>
        <text>$3</text>
      </navLabel>
      <content src="$2"/>
    </navPoint>
EOF
}

main
