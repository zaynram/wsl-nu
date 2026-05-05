if (which __zoxide_zi | length) == 0 {
    ^($nu.vendor-autoload-dirs | last | path join zoxide.nu)
}

# Set the active working directory (with zoxide).
# If no arguments are provided, the interactive panel will be shown.
alias sd = do --env {|...args: string| match ($args | length) {
    0 => { __zoxide_zi }
    _ => { __zoxide_z ...$args }
} }

# Add a directory to the database (zoxide).
alias ad = zoxide add
# Remove a directory from the database (zoxide)
alias rd = zoxide remove
# Query the database (zoxide).
alias qd = zoxide query
