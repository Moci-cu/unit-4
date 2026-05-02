#!/bin/bash
# Single-pass .desktop reader — one awk invocation for all files
shopt -s nullglob
files=(
    /usr/share/applications/*.desktop
    "$HOME"/.local/share/applications/*.desktop
    /var/lib/flatpak/exports/share/applications/*.desktop
    "$HOME"/.local/share/flatpak/exports/share/applications/*.desktop
    /var/lib/snapd/desktop/applications/*.desktop
)
[ ${#files[@]} -gt 0 ] || exit 0
awk -F= '
FNR==1 {
    if (prev && n && e && nd!="true" && hd!="true")
        print n "|" prev "|" c "|" e
    n=""; e=""; c=""; nd=""; hd=""
    prev = FILENAME; sub(/\.desktop$/,"",prev); sub(/.*\//,"",prev)
}
/^Name=/       && !n  { n=$2; for(i=3;i<=NF;i++) n=n"=" $i }
/^Exec=/       && !e  { e=$2; for(i=3;i<=NF;i++) e=e"=" $i; gsub(/ %[A-Za-z]/,"",e) }
/^Categories=/ && !c  { c=$2 }
/^NoDisplay=/  && !nd { nd=$2 }
/^Hidden=/     && !hd { hd=$2 }
END {
    if (n && e && nd!="true" && hd!="true")
        print n "|" prev "|" c "|" e
}
' "${files[@]}" | sort -u
