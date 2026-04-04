export alias la = ls -af
export alias ll = ls -l
export def --wrapped --env sl [exp: glob, ...rest] {
    let dst = try {
        ls $exp
        | where type == dir
        | first 1
        | get name
    }
    if $dst != null { cd $dst.0 } else {
        print $"(ansi red)no matches:(ansi reset) ($exp)"
    }
}
