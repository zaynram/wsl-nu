const here = path self .
[
    {
        src: ($here | path join config.nu)
        dst: $nu.config-path
    },
    {
        src: ($here | path join helix languages.toml)
        dst: ("~/.config/helix/languages.toml" | path expand)
    }
    {
        src: ($here | path join helix config.toml)
        dst: ("~/.config/helix/config.toml" | path expand)
    }
] | par-each { |map|
    cp ...($map | values)
    $map | table -c
}
