## custom.nu

# ——— path ————————————————————————————————————————————————————————————————————

export module path {
    export alias pj = path join
    export alias px = path expand
    # Construct a path in an autoloaded directory, with assurance of the directory's existence.
    #
    export def "autoload path" [
        ...segments: string # Path segments to join to the directory.
        --user(-u) # Use the user-autoload-dirs instead of vendor-autoload-dirs
    ]: nothing -> path {
        if $user {
            $nu.user-autoload-dirs
        } else {
            $nu.vendor-autoload-dirs | where ($it | str contains $nu.home-dir)  # nu-lint-ignore: contains_to_regex_op
        } | first
        | let directory: path
        | path type
        | if $in == dir {
            $directory
        } else { try {
                rm --force $directory
                mkdir $directory
            } catch {
                error make "directory creation failed"
            }
            $directory
        } | path join ...$segments
    }
}

export use path *

# ——— test ————————————————————————————————————————————————————————————————————

export module test {
    export alias has-prefix = str starts-with
    export alias has-suffix = str ends-with
}

export use test *

# ——— repo ————————————————————————————————————————————————————————————————————

export module repo {
    export alias gp = git push
    export alias gc = git commit
    export alias clone = gh repo clone
}

export use repo *

# ——— each ————————————————————————————————————————————————————————————————————

export module each {
    export alias iter = par-each
    export alias index = enumerate
}

export use each *

# ——— edit ————————————————————————————————————————————————————————————————————

export module edit {
    export alias code = ^code-insiders
}

export use edit *

# ——— info ————————————————————————————————————————————————————————————————————

export module info {
    export alias la = ls --all --full-paths
    export alias ll = ls --full-paths
    export alias ld = ls --directory
    # Check if a command exists on PATH
    #
    @category information
    export def command [
        name: string # The command name to check for
    ]: nothing -> bool {
        (which $name | compact --empty | length) > 0
    }
    # Check if a file is older than a set duration.
    #
    @category information
    export def stale [
        path?: path # Path of the file to check
        --max-age (-m): duration = 1day # Time since last modification to consider stale
    ]: [
        oneof<
            nothing
            path
            record<name: string, type: string, size: filesize, modified: datetime>
        > -> bool
        table<name: string, type: string, size: filesize, modified: datetime> -> list<bool>
    ] {|x: oneof<nothing path record table>| describe | let type: string
        match $type {
            `nothing`   => {
                if $path != null {
                    try { ls $path } | default []
                } else {
                    error make "a path or record must be provided"
                }
            }
            `string`    => (try { ls $x } | default [])
            _           => (if $type =~ record { [$x] } else { $x })
        } | par-each --keep-order {|r| $r == null or ((date now) - $r.modified) > $max_age }
    }
}

export use info *

# ——— http ————————————————————————————————————————————————————————————————————

export module http {
    export alias curl = http get --raw
}

export use http *

# ——— navigate ————————————————————————————————————————————————————————————————

export module navigate {
    export alias dev = try { cd ~/code }
    # Change directory with glob matching
    #
    @category location
    export def --env nav [
        pattern: glob, # Glob pattern to match target directory against
    ]: nothing -> nothing {
        try {
            ls $pattern --directory --full-paths
            | get 0.name
            | cd $in
        } catch {
            error make {
                msg: "no directories matched the glob pattern"
                labels: [
                    {text: `pattern` span: (metadata $pattern).span}
                ]
            }
        }
    }
}

export use navigate *

# ——— manage ——————————————————————————————————————————————————————————————————

export module manage {
    # Install a plugin using cargo and automatically add it
    #
    @category plugins
    export def "plugin install" [
        name: oneof<path, string> # The name of the plugin (must start with 'nu_plugin_')
        --owner(-o): string # The owner of the repository to install from
    ]: nothing -> nothing {
        match $owner {
            null => [$name]
            _    => [--git $'https://github.com/($owner)/($name).git']
        } | let args: list<string>
        try {
            cargo install ...$args
            plugin add (
                $env.CARGO_HOME?
                | default ($nu.home-dir | path join .cargo)
                | path join bin $name
            )
        } catch {|err|
            error make {
                msg: "plugin installation failed"
                labels: [
                    {text: `plugin`     span: (metadata $name).span}
                    {text: `arguments`  span: (metadata $args).span}
                ]
                inner: [$err]
            }
        }
    }
}

export use manage *
