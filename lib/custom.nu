## == Aliases ==
export alias la = ls -af
export alias ll = ls -l
export alias gp = git push
export alias gc = git commit
export alias pj = path join
export alias px = path expand

export alias prefix = str starts-with
export alias suffix = str ends-with

export alias dev = cd ~/code
export alias iter = par-each

## == Functions ==
export def --wrapped --env sl [exp: glob, ...rest] {
    let dst = try { ls $exp }
        | default []
        | where type == dir
        | first 1
        | get name

    if $dst != null { cd $dst.0 } else {
        print $"(ansi red)no matches:(ansi reset) ($exp)"
    }
}

export def main [] { }
