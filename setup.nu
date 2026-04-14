#!/usr/bin/env nu
use std/log
overlay use ./lib/custom.nu

const HERE = path self .

#MARK: Helpers

def step [name: string]: nothing -> nothing {
    log info $"setting up: (ansi c)($name)(ansi rst)"
}

def found [desc: string --noun (-n): string = install]: nothing -> nothing {
    log info $"found existing ($noun): (ansi b)($desc)(ansi rst)"
}

def resolve [...segments: string --glob (-g)]: [
    nothing -> path
    nothing -> glob
] {|| prepend $HERE
    | append $segments
    | path join
    | if $glob { $in | into glob } else { $in }
}

def prettify []: [
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

def copy-file []: [
    record<src: glob, dst: string> -> record<name: string, path: string>
] {|| let record | get src | let src | describe | let type
    $record | get dst | let dst
    try { if $type != glob { [$src] } else { $src
            | into string
            | let str
            | path dirname
            | cd $in
            $str | path basename | glob $in
        } | where $it != null | par-each {|f|
            cp --update --recursive $f $dst
            {src: $f dst: $dst} | prettify
        }
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

def "parse version" [format_str: string = "{_} {major}.{minor}.{patch}"]: [
    string -> record<major: int minor: int patch: int pre: string build: string>
] {|| parse $format_str
    | first
    | items {|k v| {($k): (if ($k in [pre build]) { $v } else { $v | into int })} }
    | into record
    | let parts
    | merge (
        [pre build]
        | where ($parts | get --optional $it) == null
        | par-each { {($in): ''} }
        | into record
    )
}

# MARK: Subcommands

# Install and configure oh-my-posh as the shell prompt handler.
@category prompt
def "main oh-my-posh" []: nothing -> nothing {
    if (which oh-my-posh | get --optional 0.path) == null {
        try {
            match $nu.os-info.family {
                `windows` => {
                    pwsh -nop -noni -c "winget install oh-my-posh --disable-interactivity"
                }
                `unix`    => {
                    bash -c "sudo apt-get install oh-my-posh -y"
                }
            }
        } catch {
            error make "failed to install oh-my-posh using system package manager"
        }
    } else {
        print $'(ansi b)oh-my-posh (oh-my-posh --version)(ansi rst) is already installed'
    }
    let script: path = $nu.vendor-autoload-dirs | last | path join oh-my-posh.nu
    let custom: path = (resolve custom.omp.json)
    try {
        oh-my-posh init nu --config $custom --print | save --force $script
        {src: `oh-my-posh.nu` dst: $script}
        | prettify
        | flatten
        | table --theme thin --index false
        | print
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

# Install and configure Helix as a modal editor. Tree-sitter grammars can be fetched and built with the --grammar flag.
#
# Language servers can be automatically installed using `nu setup.nu servers`.
@category editor
def "main helix" [
    --grammars (-g) # fetch and build language grammar trees
]: [
    nothing -> nothing
] {
    let target: path = $nu.default-config-dir | path basename --replace helix
    let version: string = try { hx --version } | default ''
    let files: list<record<path: path, content: string>> = [[path content];
    [
        /etc/apt/sources.list.d/debian-unstable.list,
        (
            [
                "deb http://deb.debian.org/debian unstable main"
                "deb-src http://deb.debian.org/debian unstable main"
            ] | str join "\n"
        )
    ]
    [
        /etc/apt/preferences,
        (
            [
                "Package: *"
                "Pin: release a=trixie"
                "Pin-Priority: 500"
                ""
                "Package: hx"
                "Pin: release a=unstable"
                "Pin-Priority: 1000"
                ""
                "Package: *"
                "Pin: release a=unstable"
                "Pin-Priority: 100"
                ""
            ] | str join "\n"
        )
    ]
]
    let script = $'
list="($files | first | get path)"
if [ ! -f "$list" ]; then
    echo "($files | first | get content)" | sudo tee $list
    echo "wrote unstable list to $list"
else
    echo "found existing unstable list [path=$list]"
fi
preferences="($files | last | get path)"
if [ ! -f "$preferences" ]; then
    echo "($files | last | get content)"
    echo "wrote preferences to $preferences"
else
    echo "found existing preferences [path=$preferences]"
fi
sudo apt-get update -y && sudo apt-get install hx -y
'
    if ($version) =~ '25.07' {
        found $version
    } else if ($files | get path | all { $in | path exists }) {
        found ($files.path | str join ', ') --noun files
    } else {
        try {
            bash -c $script
            print $"(ansi g)installed (helix --version)(ansi rst)"
        } catch {
            error make {
                msg: "failed to update helix from unstable repository"
                labels: [
                    {text: `version`, span: (metadata $version).span}
                    {text: `script`, span: (metadata $script).span}
                ]
            }
        }
    }


    try {
        if not ($target | path exists) {
            mkdir --verbose $target
        } else if (ls $target | first | stale) {
            {src: (resolve helix * --glob) dst: $target}
            | copy-file
            | table --theme thin --index false
        } else {
           $"(ansi y)helix configuration is already up to date(ansi rst)"
        } | print
     } catch {
        error make "failed to write helix configuration files"
    }

    if $grammars and (which hx | get path | first) != null {
        try { hx --grammar fetch }
        try { hx --grammar build }
    }
    return
}

# Install and configure Zellij, along with completions if carapace is installed.
@category multiplexer
def "main zellij" []: [
    nothing -> nothing
] {
    let target: path = $nu.default-config-dir | path basename --replace zellij
    if (which zellij | get --optional 0.path) == null {
        try {
            cargo --list
            | find binstall
            | length
            | if $in > 0 { cargo binstall zellij } else { cargo install --locked zellij }
        } catch {
            error make 'failed to install zellij'
        }
    } else {
        found (zellij --version)
    }

    mut out = []

    try {
        if not ($target | path exists) { mkdir --verbose $target }
       $out ++= [({src: (resolve zellij *.kdl --glob) dst: $target} | copy-file)]
    } catch {
        error make "failed to write zellij configuration files"
    }

     if ($nu.os-info.name == linux) and (which carapace | get --optional 0.path) != null {
        let fish_completions = '/usr/share/fish/vendor_completions.d/'
        let tmp = mktemp --suffix .fish
        try {
            mkdir $fish_completions
            zellij setup --generate-completion fish | save --raw --force $tmp
            bash -c $"sudo mv ($tmp) ($fish_completions | path join zellij.fish)"
            $out ++= [({src: `zellij.fish` dst: $fish_completions} | prettify)]
        } catch {
            error make "failed to setup zellij completions (bridge=fish)"
        }
    }

    $out | flatten | table --theme thin --index false | print
}

# Install carapace-bin for externally sourced shell completions
@category completion
def "main carapace" []: [
    nothing -> nothing
] {
    let text: string = 'deb [trusted=yes] https://apt.fury.io/rsteube/ /'
    let path: string = '/etc/apt/sources.list.d/fury.list'

    if (which carapace | get --optional 0.path) != null {
        found (carapace --version | parse '{version} ({_}) [{_}]' | get version | first)
    } else if ($path | path exists) {
        found $path --noun list
    } else {
        try {
            bash -c $'echo "($text)" | sudo tee "($path)"'
        } catch {
            error make $"failed to write list [path=($path)]"
        }
    }

    try {
        bash -c 'sudo apt-get update -y && sudo apt-get install carapace-bin -y'
    } catch {
        error make "failed to install carapace-bin"
    }
    return
}

# Inventory and (optionally) install language servers consumed by the Helix language configuration.
@category editor
def "main servers" [
    --install (-i) # automatically install missing language servers
]: [
    nothing -> nothing
] {
    let candidates = [[name, role, language];
        [rust-analyzer,                 lsp,        rust]
        [pyright-langserver,            lsp,        python]
        [pyright,                       lsp-alt,    python]
        [ruff,                          lsp+fmt,    python]
        [typescript-language-server,    lsp,        js/ts]
        [oxlint,                        lsp,        js/ts]
        [prettier,                      formatter,  js/ts/html/css/json]
        [vscode-css-language-server,    lsp,        css]
        [vscode-html-language-server,   lsp,        html]
        [vscode-json-language-server,   lsp,        json]
        [yaml-language-server,          lsp,        yaml]
        [marksman,                      lsp,        markdown]
        [bash-language-server,          lsp,        bash]
        [tombi,                         lsp+fmt,    toml]
        [nufmt,                         formatter,  nu]
        [nu-lint,                       lsp,        nu]
    ]
    let installers = [[binary, closure];
        [rust-analyzer,                 { rustup component add rust-src }]
        [pyright,                       { pixi global install --expose pyright --expose pyright-langserver pyright }]
        [pyright-langserver,            null]
        [ruff,                          { pixi global install ruff }]
        [typescript-language-server,    { bun --global install typescript-language-server }]
        [oxlint,                        { bun --global install oxlint }]
        [prettier,                      { bun --global install prettier }]
        [vscode-css-language-server,    { bun --global install vscode-langservers-extracted }]
        [vscode-html-language-server,   null]
        [vscode-json-language-server,   null]
        [yaml-language-server,          { bun --global install yaml-language-server }]
        [marksman,                      { pixi global install marksman }]
        [bash-language-server,          { bun --global install bash-language-server }]
        [tombi,                         { pixi global install tombi }]
        [nufmt,                         { cargo install --git https://github.com/nushell/nufmt }]
        [nu-lint,                       { cargo install nu-lint }]
    ]

    # --- search roots ---
    let roots = [
        (
            $env.RUSTUP_HOME?
            | default ($nu.home-dir | path join .rustup)
            | path join toolchains (rustup show active-toolchain | split words | first) bin
        )
        ...([.local .pixi .bun .cargo] | par-each {|el| $nu.home-dir | path join $el bin })
        ...($env.PATH | split row (char esep))
    ] | where ($it != null and ($it | path exists)) | uniq

    # --- resolve each candidate ---
    $candidates
    | sort-by language
    | par-each --keep-order {|c|
        let resolved: path = $roots | par-each { $in
            | path join $c.name
            | if ($in | path exists) { $in } else { which $c.name | get --optional 0.path }
        } | compact | first
        {
            name: $c.name
            path: ($resolved | default "not found")
            found: ($resolved != null)
        }
    } | if not $install { $in } else { $in
        | let index
        | where not ($it.found? | default false)
        | let missing
        | length
        | if $in == 0 {
            $index | get name | par-each { found $in --noun server } | first
        } else { $missing
            | get binary
            | par-each {|b| ($installers | where binary == $b).0? }
            | where closure != null
            | par-each {|e| get binary | let name
                try { do $e.closure } catch { error make $"failed to install ($name)" }
                {name: $name path: (which $e.binary | get --optional 0.path)}
            }
        }
    } | table --theme thin --index false | print
}

# Show information about the Nushell environment.
@category meta
def "main info" [
    --servers (-s) # evaluate and display the LSP inventory
    --full (-f) # display all supported prettifyation types
]: [
    nothing -> nothing
] {
    if $servers or $full { main servers }
    if $full or not $servers {
        [[name command format];
            [carapace   carapace    "{_} {major}.{minor}.{patch}-{pre}-{build} ({_}) [{_}]"]
            [oh-my-posh oh-my-posh  "{major}.{minor}.{patch}"]
            [helix      hx          "{_} {major}.{minor}.{patch}"]
            [zellij     zellij      "{_} {major}.{minor}.{patch}"]
        ] | par-each {|row|
            let path = which $row.command | get --optional 0.path
            {
                name: $row.name
                path: $path
                version: (
                    if $path != null {
                        let version = ^$path --version | parse version $row.format
                        [
                            ($version | get major minor patch | str join .)
                            ...($version | get pre build | where ($it | str length) > 0)
                        ] | str join -
                    } else {
                        "not installed"
                    }
                )
            }
        } | table --theme thin --index false --expand | print
    }
}

# MARK: Main

# Install the repository's Nushell configuration and module library.
#
def main [
    --all (-a) # Run the full setup suite (caution: opinionated)
    --info (-i) # Show the installed applications and language servers.
]: nothing -> nothing  {

    if $all { step config+modules }

    [[src dst];
        [(resolve config.nu)        ($nu.config-path)]
        [(resolve lib *.nu --glob)  ($nu.data-dir | path join modules)]
    ] | par-each --keep-order { $in | copy-file } | flatten | table --theme thin --index false | print

    if $all {
        step carapace
        main carapace
        step helix+grammars
        main helix --grammars
        step oh-my-posh+config
        main oh-my-posh
        step language-servers
        main servers --install
        step zellij
        main zellij
    } else if $info {
        main info --full
    }
}
