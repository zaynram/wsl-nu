const HERE = path self .
const HOME = '~' | path expand

def batch-copy []: [
    list<record<src: path dst: path>> -> nothing
] { par-each {|r|
        try {
            mkdir ($r.dst | path dirname)
            cp $r.src $r.dst --update --progress
        } catch {
            error make {
                msg: "failed to copy file"
                labels: [
                    {text: `source` span: (metadata $r.src).span}
                    {text: `output` span: (metadata $r.dst).span}
                ]
            }
        }
    }
}

def main []: [
    nothing -> nothing
] {
    let from = $HERE | path join helix
    let to = $HOME | path join .config helix
    try {
        ls --short-names ($HERE | path join helix *.toml)
        | par-each { {src: ($from | path join $in) dst: ($to | path join $in)} }
        | append {src: ($HERE | path join config.nu), dst: $nu.config-path}
        | batch-copy
    }
    let custom = $HERE | path join custom.omp.json
    let script = $nu.config-path | path basename --replace vendor/autoload/oh-my-posh.nu
    try { oh-my-posh init nu --config $custom --print | save $script }
}
