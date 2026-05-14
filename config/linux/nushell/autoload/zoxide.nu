if (which __zoxide_zi | length) == 0 {
    let vendor: path = $nu.vendor-autoload-dirs | last | path join zoxide.nu
    if ($vendor | path exists) { ^$vendor } else {
        error make "zoxide vendor autoload script is missing"
    }
}
module zoxide {
    # Add a directory to the zoxide database.
    alias dir+ = zoxide add
    # Remove a directory from the zoxide database.
    alias dir- = zoxide remove
    # Query the zoxide database.
    alias dir? = zoxide query
    # Edit the zoxide database.
    alias dir! = zoxide edit
    # Set the active working directory (with zoxide).
    # If no arguments are provided, the interactive panel will be shown.
    alias dir = do --env {|...args: string| match ($args | length) {
    0 => { __zoxide_zi }
    _ => { __zoxide_z ...$args }
    } }
}

overlay use zoxide
