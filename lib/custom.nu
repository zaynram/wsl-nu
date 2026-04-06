# ——— path ————————————————————————————————————————————————————————————————————
module path {
    export alias pj = path join
    export alias px = path expand
}

# ——— test ————————————————————————————————————————————————————————————————————
module test {
    export alias has-prefix = str starts-with
    export alias has-suffix = str ends-with
}

# ——— repo ————————————————————————————————————————————————————————————————————
module repo {
    export alias gp = git push
    export alias gc = git commit
    export alias clone = gh repo clone
}

# ——— each ————————————————————————————————————————————————————————————————————
module each {
    export alias iter = par-each
    export alias index = enumerate
}

# ——— edit ————————————————————————————————————————————————————————————————————
module edit {
    export alias vsc = try { ^code-insiders }
    export alias mse = try { ^edit }
}

# ——— navigate ————————————————————————————————————————————————————————————————
module navigate {
    export alias la = ls -af
    export alias ll = ls -l
    export alias dev = cd ~/code
    export def --wrapped --env nav [exp: glob, ...rest]: [
        nothing -> nothing
    ] {
        try {
            ls $exp
            | where type == dir
            | get name
            | first 1
            | get 0
            | do {|p| cd $p }
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
module manage {
    export def "plugin install" [name: string, --owner(-o): string]: [
        nothing -> nothing
    ] {
    match $owner {
        null => {
            cargo install $name
        }
        _    => {
            let url = ["https://github.com" $owner $name] | str join '/'
            cargo install --git ($url + .git)
        }
    }
    plugin add $name
    print $"installed ($name)"
}

}

# ——— initializer —————————————————————————————————————————————————————————————
def main []: [
    nothing -> nothing
] {
    overlay use path
    overlay use test
    overlay use repo
    overlay use each
    overlay use edit
    overlay use navigate
    overlay use manage
}