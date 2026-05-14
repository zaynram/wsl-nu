module apt {
    # Auto-elevating apt wrapper
    export alias sap = sudo apt-get
    # Install a system package using apt.
    export alias agi = sudo apt-get install --yes
    # Update and upgrade the system packages.
    export alias agu = try {
        sudo apt-get update --yes
        sudo apt-get upgrade --yes
    }
    # Run the automated cleanup scripts for apt.
    export alias arm = try {
        sudo apt-get autoremove --yes
        sudo apt-get autoclean --yes
    }
}

overlay use apt
