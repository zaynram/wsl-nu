module aliases {
    # List the full paths matching the glob expression.
    export alias dir = do {|exp: glob = .|
        try {
            ls --full-paths $exp | get --optional name | compact --empty | uniq
        } catch {
            error make $"No paths matched the glob expression: ($exp)"
        }
    }
    # Set the content of the system clipboard.
    export alias scb = wl-copy
    # Get the contents of the system clipboard.
    export alias gcb = wl-paste
    # Switch to the next swap layout in a zellij session.
    export alias zs = zellij action next-swap-layout
    # Run a command in a new zellij pane.
    export alias zr = zellij run
    # Attach to a zellij session.
    export alias za = zellij attach
    # Install a system package using apt.
    export alias agi = sudo apt-get install
    # Update and upgrade the system packages.
    export alias agu = do {
        try {
            sudo apt-get update --yes
            sudo apt-get upgrade --yes
        }
    }
    # Replace the current shell instance with a fresh one.
    export alias enu = do {
        clear
        exec nu
    }
}

overlay use aliases
