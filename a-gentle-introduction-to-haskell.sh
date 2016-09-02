#!/bin/bash

booktitle='A Gentle Introduction to Haskell Version 98'
bookid='3dbc527d-5174-4a3c-b61e-dc60c224da12'
outputfilename='haskell-98-tutorial.epub'

tmpdir='/tmp/gith'
inputdir="$tmpdir/in"
outputdir="$tmpdir/out"

function main() {
    mkdir -p $tmpdir
    if [ ! -e "$tmpdir/haskell.tar.gz" ]; then
        wget --output-document "$tmpdir/haskell.tar.gz" 'https://www.haskell.org/tutorial/haskell-98-tutorial-html.tar.gz'
    fi

    tar -xf "$tmpdir/haskell.tar.gz" -C "$tmpdir"
    rm -rf "$inputdir"
    mv "$tmpdir/haskell-98-tutorial-html" "$inputdir"

    rm -rf "$outputdir"
    mkdir -p "$outputdir/META-INF"
    cp $inputdir/*.* "$outputdir/"
    remove_headers_and_footers
    fix_index
    fix_links_to_onlinereport
    
    echo -n "application/epub+zip" > "$outputdir/mimetype"

    chapters=$(sed -rn 's/<LI><a href=\"(.*)\">(.*)<\/a>/\1;\2/p' "$inputdir/index.html")
    build_container_xml
    build_content_opf
    build_toc_ncx

    (
        cd $outputdir
        zip -X0 "$tmpdir/out.epub" mimetype >> /dev/null
        zip -Xur9D "$tmpdir/out.epub" * >> /dev/null
    )

    mv "$tmpdir/out.epub" "$outputfilename"
    kindlegen -gif "$outputfilename"
}

function remove_headers_and_footers() {
    sed -i 's/\(<hr>\)\?<body bgcolor=\"#ffffff\"><i>A Gentle Introduction to Haskell.*//' $outputdir/*.html
}

function fix_index() {
    sed -i 's/HTML/EPUB/' "$outputdir/index.html"
    sed -i 's/.*code.*//' "$outputdir/index.html"
}

function fix_links_to_onlinereport() {
    sed -i 's/..\/onlinereport/https:\/\/www.haskell.org\/onlinereport/g' $outputdir/*.html
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

function build_titlepage() {
    cat << EOF > "$outputdir/title.html"
<html>
    <head>
        <title>$booktitle</title>
        <style>body { text-align: center; }</style>
    </head>
    <body>
        <img src="title.gif" />
    </body>
</html>
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
    <item href="index.html" id="pre" media-type="application/xhtml+xml"/>
    $(iterate_chapters append_chapter_to_manifest)
    <item href="title.gif" id="im_title" media-type="image/gif" />
    $(append_images_to_manifest)
  </manifest>
  <spine toc="ncx">
    <itemref idref="pre"/>
    $(iterate_chapters append_chapter_to_spine)
  </spine>
  <guide>
    <reference href="indextutorial.html" title="Contents" type="toc"/>
    <!--<reference href="titlepage.xhtml" title="Cover" type="cover"/>-->
    <reference href="index.html" title="start" type="text"/>
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
    <navPoint id="pre" playorder="0">
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
        filename=$(echo $line | cut -d';' -f1)
        title=$(echo $line | cut -d';' -f2)
        ((i=i+1))
        
        $1 "$i" "$filename" "$title"
    done
}

function append_chapter_to_manifest() {
    echo "    <item href=\"$2\" id=\"ch$1\" media-type=\"application/xhtml+xml\"/>"
}

function append_images_to_manifest() {
    i=0
    for filename in $(ls $outputdir/fig*.gif); do
        ((i=i+1))
        echo "    <item href=\"$filename\" id=\"im$i\" media-type=\"image/gif\"/>"
    done
}

function append_chapter_to_spine() {
    echo "    <itemref idref=\"ch$1\"/>"
}

function append_chapter_to_toc() {
    cat <<-EOF
    <navPoint id="nav$1" playorder="$1">
      <navLabel>
        <text>$3</text>
      </navLabel>
      <content src="$2"/>
    </navPoint>
EOF
}

main

