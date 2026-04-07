const HERE = path self .
const MODULES = $nu.data-dir | path join modules
const HELIX = $nu.default-config-dir | path basename -r helix

def resolve [...segments: string --glob (-g)]: [
    nothing -> path
    nothing -> glob
] {|| prepend $HERE
    | append $segments
    | path join
    | if $glob { $in | into glob } else { $in }
}

def inform []: [
    record<src: string, dst: string> -> record<name: string, path: string>
] {|| do {|src, dst| $src
        | path basename
        | let name
        if $dst =~ $name { $dst } else { $dst | path join $name }
        | str replace $nu.home-dir ~
        | {
            name: (match ($in | path type) {
                file => (ansi steelblue1a)
                _    => (ansi steelblue1b)(ansi bo)
            } | append [$name (ansi rst)] | str join)
            path: $'(ansi lime)($in)(ansi rst)'
        }
    } ...($in | values)
}

def try-copy []: [
    record<src: glob, dst: string> -> list<record<name: string, path: string>>
] {|| do {|src, dst| $src
        | describe
        | if $in != glob { [$src] } else { $src
            | into string
            | let str
            | path dirname
            | cd $in
            $str | path basename | glob $in
        } | par-each {|f|
            try { cp --update --recursive $f $dst
                {src: $f dst: $dst} | inform
            } catch {
                error make {
                    msg: "failed to copy file(s)"
                    labels: [
                        {text: `source` span: (metadata $src).span}
                        {text: `output` span: (metadata $dst).span}
                    ]
                }
            }
        }
    } ...($in | values)
}

def configure-posh []: nothing -> record<name: string path: string> {
    $nu.vendor-autoload-dirs
    | reverse
    | get 0
    | path join oh-my-posh.nu
    | let script
    resolve custom.omp.json
    | let custom
    | try { oh-my-posh init nu --config $in --print
        | save $script --force --progress
        {src: 'oh-my-posh.nu' dst: $script} | inform
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

def main []: any -> table { [
        {src: (resolve config.nu)       dst: $nu.config-path}
        {src: (resolve helix * --glob)  dst: $HELIX}
        {src: (resolve lib *.nu --glob) dst: $MODULES }
    ] | par-each {|r| get dst
        | path type
        | if $in != file { mkdir $r.dst }
        $r | try-copy
    } | append (configure-posh) | flatten
}
