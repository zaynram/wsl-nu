const here = path self .
const home = '~' | path expand
[
    {
        src: ($here | path join config.nu)
        dst: $nu.config-path
    },
    {
        src: ($here | path join helix languages.toml)
        dst: ($home | path join .config helix languages.toml)
    }
    {
        src: ($here | path join helix config.toml)
        dst: ($home | path join .config helix config.toml)
    }
] | par-each { |map|
    cp ...($map | values)
    print ($map | table -c)
}

oh-my-posh init nu --config (
    $here
    | path join custom.omp.json
) --print
| save (
    $home
    | path join (
        $nu.config-path
        | path dirname
    ) vendor autoload custom.omp.json
) --force

print (ansi green)done(ansi reset)
