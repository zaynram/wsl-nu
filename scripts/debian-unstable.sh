#!/usr/bin/env bash

function write-list {
    local path="/etc/apt/sources.list.d/debian-unstable.list"
    if [ -f "$path" ]; then return 1; fi
    local text="$(cat <<EOF
deb http://deb.debian.org/debian unstable main
deb-src http://deb.debian.org/debian unstable main
EOF
)"
    echo $text | tee $path
}

function write-preferences {
    local path="/etc/apt/preferences"
    if [ -f "$path" ]; then return 1; fi
    local text="$(cat <<EOF
Package: *
Pin: release a=trixie
Pin-Priority: 500

Package: hx
Pin: release a=unstable
Pin-Priority: 1000

Package: *
Pin: release a=unstable
Pin-Priority: 100
EOF
)"
    echo $text | tee $path
}

write-list &&
write-preferences &&
apt-get update -y &&
apt-get upgrade -y