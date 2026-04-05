const HERE = path self .
def resolve [...segments: string]: [
    nothing -> path
] { $HERE | path join ...$segments }
def main []: [
    nothing -> nothing
] {
    let hx = $nu.default-config-dir | path basename --replace helix
    [
        {src: (resolve config.nu) dst: $nu.config-path}
        {src: (resolve hx)        dst: $hx}
    ] | par-each {|el| try {
            cp --update --progress --recursive $el.src $el.dst
            [
                ($el.src | path basename),
                ($el.dst | path relative-to $nu.home-dir)
            ] | str join " -> ~/"
        } catch {
            error make {
                msg: "failed to copy file"
                labels: [
                    {text: `source` span: (metadata $in.0?).span}
                    {text: `output` span: (metadata $in.1?).span}
                ]
            }
        }
    } | where $it != null | print
    let custom = resolve custom.omp.json
    let script = $nu.vendor-autoload-dirs | last 1 | path join oh-my-posh.nu
    try { 
        oh-my-posh init nu --config $custom --print 
        | save $script --force --progress
    } catch {
        error make {
            msg: "failed to setup oh-my-posh"
            labels: [
                {text: `source` span: (metadata $custom).span}
                {text: `output` span: (metadata $script).span}
            ]
        }
    }
}
