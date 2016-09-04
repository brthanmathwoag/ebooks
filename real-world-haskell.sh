#!/bin/bash

booktitle='Real World Haskell'
bookid='8f73e19b-3f86-4ba2-9aaa-90d30d3fdae4'
outputfilename='real-world-haskell.epub'

tmpdir='/tmp/rwh'
inputdir="$tmpdir/in"
outputdir="$tmpdir/out"
htmldir="$outputdir/read"
figsdir="$outputdir/figs"

function main() {
    mkdir -p $tmpdir
    if [ ! -e "$inputdir" ]; then
        wget -r --directory-prefix="$tmpdir" 'http://book.realworldhaskell.org/read/'
        mv "$tmpdir/book.realworldhaskell.org" "$inputdir"
    fi
    
    rm -rf "$outputdir"
    mkdir -p "$outputdir/META-INF"
    
    mkdir -p "$htmldir"
    cp $inputdir/read/*.html "$htmldir/"
    
    mkdir -p "$figsdir"
    cp $inputdir/read/figs/* "$figsdir/"
    cp "$inputdir/support/rwh-200.jpg" "$outputdir/"
    cp $inputdir/support/figs/* "$figsdir/"
    fix_image_paths
    fix_rss_anchors
    remove_scripts
    remove_headers_and_footers
    
    echo "application/epub+zip" > "$outputdir/mimetype"
    
    chapters=$(sed -rn 's/.*<a href=\"(.*)\">(.*)<\/a><\/li>.*/\1;\2/p' "$inputdir/read/index.html")

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
}

function fix_image_paths() {
	sed -i 's/src=\"\/support\/figs\//src=\"..\/figs\//g' $outputdir/read/*.html
	sed -i 's/src=\"figs\//src=\"..\/figs\//g' $outputdir/read/*.html
}

function fix_rss_anchors() {
	sed -i 's/href=\"\/feeds\//href=\"http:\/\/book.realworldhaskell.org\/feeds\//g' $outputdir/read/*.html
}

function remove_scripts() {
    sed -ri 's/<script.*?\/script>//g' $outputdir/read/*.html
}

function remove_headers_and_footers() {
    sed -ri 's/<div class=\"navheader\"><table.*?<\/table><\/div>//g' $outputdir/read/*.html
    sed -ri 's/<div class=\"navheader\"><h2.*?<\/span><\/h2><\/div>//g' $outputdir/read/*.html

    sed -ri 's/<div class=\"navfooter\".*?<\/div>//g' $outputdir/read/*.html

    sed -ri 's/<div class=\"rwhfooter\">.*//g' $outputdir/read/*.html
    sed -ri 's/\s+John Goerzen. This work is licensed under a.*//g' $outputdir/read/*.html
        sed -ri 's/\s+    Commons Attribution-Noncommercial 3.0 License.*?<\/div>//g' $outputdir/read/*.html
}

function build_container_xml() {
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
    <item href="read/index.html" id="ch0" media-type="application/xhtml+xml"/>
    <item href="rwh-200.jpg" id="im_title" media-type="image/jpeg" />
    $(iterate_chapters append_chapter_to_manifest)
    $(append_images_to_manifest)
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch0"/>
    $(iterate_chapters append_chapter_to_spine)
  </spine>
  <guide>
    <reference href="read/index.html" title="Contents" type="toc"/>
    <reference href="read/why-functional-programming-why-haskell.html" title="start" type="text"/>
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
    <navPoint id="nav0" playorder="0">
      <navLabel>
        <text>Preamble</text>
      </navLabel>
      <content src="read/index.html"/>
    </navPoint>
    $(iterate_chapters append_chapter_to_toc)
  </navMap>
</ncx>
EOF
}

function iterate_chapters() {
    i=0
    echo "$chapters" | while read line; do
        filename=$(echo $line | cut -d';' -f1)
        title=$(echo $line | cut -d';' -f2)
        ((i=i+1))
        
        $1 "$i" "$filename" "$title"
    done
}

function append_chapter_to_manifest() {
    echo "    <item href=\"read/$2\" id=\"ch$1\" media-type=\"application/xhtml+xml\"/>"
}

function append_images_to_manifest() {
    i=0
    for filename in $(ls $figsdir/*.*); do
		extension=$(echo $filename | sed -r 's/.*\.(.*)/\1/')
        ((i=i+1))
        echo "    <item href=\"figs/$filename\" id=\"im$i\" media-type=\"image/$extension\"/>"
    done
}

function append_chapter_to_spine() {
    echo "    <itemref idref=\"ch$1\"/>"
}

function append_chapter_to_toc() {
    cat << EOF
    <navPoint id="nav$1" playorder="$1">
      <navLabel>
        <text>$3</text>
      </navLabel>
      <content src="read/$2"/>
    </navPoint>
EOF
}

main

