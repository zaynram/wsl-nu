module proxied {
    const SETUP_PATH: path = $nu.home-dir | path join code nu setup.nu
    # Convenience wrapper for the automated setup script (~/code/nu/setup.nu)
    export def --wrapped "setup nu" [...rest: string]: nothing -> nothing {
        nu $SETUP_PATH ...$rest
    }
}

overlay use proxied
