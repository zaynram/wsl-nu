const here = path self .
[
    $nu.config-path
    ~/.config/helix/languages.toml
] | par-each { |dst|
    let map = {
        src: ($here | path join ($dst | path basename))
        dst: ($dst | path expand)
    }
    cp ...($map | values)
    $map | table -c
}
