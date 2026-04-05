const HERE: path = path self .
const HOME: path = '~' | path expand
def main []: [
    nothing -> nothing
] {
    [
        {src: ($HERE | path join config.nu) dst: $nu.config-path}
        {src: ($HERE | path join helix)     dst: ($HOME | path join .config helix)}
    ] | par-each {|r|
        try {
            cp --update --progress --recursive ...($r | values)
            $r | values | do { print $"($in.0) -> ($in.1)" }
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
    try { 
        oh-my-posh init nu --config ($HERE | path join custom.omp.json) --print 
        | save (
            $nu.config-path 
            | path basename --replace vendor
            | path join autoload oh-my-posh.nu
        ) --force --progress
    } catch {
        error make {
            msg: "failed to setup oh-my-posh"
            labels: [
                {text: `source` span: (metadata $HERE).span}
                {text: `output` span: (metadata $nu.config-path).span}
            ]
        }
    }
}
