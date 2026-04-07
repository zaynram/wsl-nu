## custom.nu

# ——— path ————————————————————————————————————————————————————————————————————

export module path {
    export alias pj = path join
    export alias px = path expand
}

# ——— test ————————————————————————————————————————————————————————————————————

export module test {
    export alias has-prefix = str starts-with
    export alias has-suffix = str ends-with
}

# ——— repo ————————————————————————————————————————————————————————————————————

export module repo {
    export alias gp = git push
    export alias gc = git commit
    export alias clone = gh repo clone
}

# ——— each ————————————————————————————————————————————————————————————————————

export module each {
    export alias iter = par-each
    export alias index = enumerate
}

# ——— edit ————————————————————————————————————————————————————————————————————

export module edit {
    export alias code = ^code-insiders
}

# ——— info ————————————————————————————————————————————————————————————————————

export module info {
    export alias la = ls --all --full-paths
    export alias ll = ls --full-paths
    export alias ld = ls --directory
}

# ——— navigate ————————————————————————————————————————————————————————————————

export module navigate {
    export alias dev = cd ~/code
    export def --wrapped --env nav [
        exp: glob,
        ...rest
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

# ——— manage ——————————————————————————————————————————————————————————————————

export module manage {
    export def "plugin install" [
        name: string,
        --owner(-o): string
    ]: nothing -> nothing {
        match $owner {
            null => $name
            _    => [--git $'https://github.com/($owner)/($name).git']
        } | prepend install | cargo ...$in
        plugin add $name
        print $"installed ($name)"
    }
}

# ——— main ————————————————————————————————————————————————————————————————————

export use path *
export use test *
export use repo *
export use each *
export use edit *
export use info *
export use navigate *
export use manage *