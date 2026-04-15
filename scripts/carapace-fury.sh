#!/usr/bin/env bash

function write-list {
    local path="/etc/apt/sources.list.d/fury.list"
    if [ -f "$path" ]; then return 1; fi
    local text="$(cat <<EOF
deb [trusted=yes] https://apt.fury.io/rsteube/ /
EOF
)"
    echo $text | sudo tee $path
}

write-list &&
sudo apt-get update -y &&
sudo apt-get install carapace-bin -y