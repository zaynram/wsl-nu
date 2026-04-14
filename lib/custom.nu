## custom.nu

# ——— path ————————————————————————————————————————————————————————————————————

export module path {
    export alias pj = path join
    export alias px = path expand
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
    export def stale [
        path?: path # path of the file to check
        --max-age (-m): duration = 1day # maximum age of a file before it becomes stale
    ]: [
        nothing -> bool
        path -> bool
        record<name: string, type: string, size: filesize, modified: datetime> -> bool
        list<record<name: string, type: string, size: filesize, modified: datetime>> -> list<bool>
    ] {|| default (try { ls $path | get 0 })
        | each { match ($in | describe) {
                `string` => (if ($in | path exists) { try { ls $in | first } })
                _        => $in
            } | $in == null or ((date now) - $in.modified > $max_age)
        }
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
    # change directory with glob matching
    export def --env nav [
        exp: glob, # glob expression to match target directory against
    ]: nothing -> nothing {
        try { ls $exp --directory
            | get 0
            | into string
            | cd $in
        } catch {
            error make {
                msg: "no directories matched the glob pattern"
                labels: [
                    {text: `expression` span: (metadata $exp).span}
                ]
            } | print
        }
    }
}

export use navigate *

# ——— manage ——————————————————————————————————————————————————————————————————

export module manage {
    export def "plugin install" [
        name: string # the plugin name
        --owner(-o): string = '' # github repository owner
    ]: nothing -> nothing {
        match $owner {
            '' => $name
            _  => [--git $'https://github.com/($owner)/($name).git']
        } | prepend install | cargo ...$in
        plugin add $name
        print $"installed ($name)"
    }
}

export use manage *
