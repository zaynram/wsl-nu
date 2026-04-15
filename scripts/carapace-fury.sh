#!/usr/bin/env bash

function write-list {
    local path="/etc/apt/sources.list.d/fury.list"
    if [ -f "$path" ]; then return 1; fi
    local text="$(cat <<EOF
deb [trusted=yes] https://apt.fury.io/rsteube/ /
EOF
)"
    echo $text | tee $path
}

write-list &&
apt-get update -y &&
apt-get install carapace-bin -y