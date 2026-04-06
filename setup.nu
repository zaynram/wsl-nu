const HERE = path self .

def resolve [...segments: string]: [
    nothing -> path
] { $HERE | path join ...$segments }

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
] {|| do {|src, dst| $dst
        | path dirname
        | if not ($in | path exists) { mkdir $in }
        if ($src | describe) != glob { [$src] } else { $src
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

def configure-posh []: [
    nothing -> record<name: string path: string>
] { ($nu.vendor-autoload-dirs | reverse).0
    | path join oh-my-posh.nu
    | let script
    | resolve custom.omp.json
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

def main []: any -> table {
    [
        {src: (resolve config.nu)           dst: $nu.config-path}
        {src: (resolve helix * | into glob) dst: ($nu.default-config-dir | path basename -r helix)}
        {src: (resolve lib * | into glob)   dst: ($nu.user-autoload-dirs | reverse | get 0) }
    ] | par-each {|r|
        $r | try-copy
    } | flatten | append [
        (configure-posh)
    ] | table
}
