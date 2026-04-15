#!/usr/bin/env nu
use std/log
use std/util ["path add" null-device]

overlay use ./lib/custom.nu

#MARK: Paths

const HERE = path self .
const AUTO = $nu.user-autoload-dirs | get --optional 0
const LIB = $nu.data-dir | path join modules
const BIN = $HERE | path join scripts

#MARK: Data

const LANGUAGE_SERVERS: list<string> = [
    rust-analyzer
    pyright
    ruff
    typescript-language-server
    oxlint
    prettier
    vscode-langservers-extracted
    yaml-language-server
    marksman
    bash-language-server
    tombi
    nufmt
    nu-lint
]

let pm_info: record<name: string sudo: bool args: list<string>> = match $nu.os-info {
    {family: windows} => ({name: winget  sudo: false          args: [--disable-interactivity]})
    {family: unix}    => ({name: apt-get sudo: (command sudo) args: [--yes]})
}

#MARK: Logging

def "show step" [name: string]: nothing -> nothing {
    log info $"setting up: (ansi c)($name)(ansi rst)"
}

def "show found" [desc: string --noun (-n): string = install]: nothing -> nothing {
    log info $"found existing ($noun): (ansi b)($desc)(ansi rst)"
}

def "show copy" []: [
    record<src: path, dst: string> -> nothing
] {|| values
    | do {|src: path, dst: string|
        $src | path basename | let name: string
        match ($src | path type) {
            dir => (ansi steelblue1b)(ansi bo)
            _   => (ansi steelblue1a)
        } | let style: string
        if $dst =~ $name { $dst } else { $dst | path join $name }
        | str replace $nu.home-dir ~
        | log info $'($style)($name)(ansi rst) -> (ansi rst)(ansi lime)($in)(ansi rst)'
    } ...$in
    | ignore
}

#MARK: Utilities

def command [name: string]: nothing -> bool {
    (which $name | compact | length) > 0
}

def resolve [...segments: string --glob (-g)]: [
    nothing -> path
    nothing -> glob
] {|| prepend $HERE
    | append $segments
    | path join
    | if $glob { $in | into glob } else { $in }
}

def "copy file" []: [
    record<src: glob, dst: string> -> nothing
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
            {src: $f dst: $dst} | show copy
        }
    } catch {
        error make {
            msg: "failed to copy file(s)"
            labels: [
                {text: `source` span: (metadata $src).span}
                {text: `output` span: (metadata $dst).span}
            ]
        }
    } | ignore
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

def "run bash" [...cmdline: string --script(-s): oneof<path glob>]: nothing -> nothing {
    if not (command bash) { return }
    let run = {|cmd: string|
        let args = if $script == null { [-c $cmd] } else { [$cmd] }
        if $pm_info.sudo { 
            ^sudo bash ...$args
        } else { 
            ^bash ...$args
        }
    }
    try {
        cd $BIN
        if $script != null {
            ls --short-names $script | get name | first
        } else {
            $cmdline | str join ' '
        } | let cmd: string
        do $run $cmd | complete
    } | let output: record<stdout: string stderr: string exit_code: int>
    if $env.LAST_EXIT_CODE != 0 and $output.stderr != "" {
        log error $output.stderr
    } else if $output.stdout != "" {
        log info $output.stdout
    } | ignore
}

def "install lsp" [...servers: string]: [
    nothing -> nothing
    list<string> -> nothing
] {|| default []
    | append $servers
    | iter {|lsp| try {
            match $lsp {
                rust-analyzer                => { rustup component add rust-src }
                pyright                      => { pixi global install --expose pyright --expose pyright-langserver pyright }
                ruff                         => { pixi global install ruff }
                marksman                     => { pixi global install marksman }
                tombi                        => { pixi global install tombi }
                typescript-language-server   => { bun --global install typescript typescript-language-server }
                oxlint                       => { bun --global install oxlint }
                prettier                     => { bun --global install prettier }
                vscode-langservers-extracted => { bun --global install vscode-langservers-extracted }
                yaml-language-server         => { bun --global install yaml-language-server }
                bash-language-server         => { bun --global install bash-language-server }
                nufmt                        => { cargo install --git https://github.com/nushell/nufmt }
                nu-lint                      => { cargo install nu-lint }
            }
            {src: $lsp dst: (which $lsp | get 0.path)} | show copy
        } catch {
            log error $'failed to install language server: ($lsp)'
        }
    } | ignore
}

def "dyn install" [package: string --winget-id(-i): string]: nothing -> nothing {
    if $pm_info.name =~ winget and $winget_id != null {
        $winget_id
    } else {
        $package
    } | let target: string
    try {
        if $pm_info.sudo {
            sudo $pm_info.name install $target ...$pm_info.args
        } else {
            ^$pm_info.name install $target ...$pm_info.args
        } | print
    } catch {|err|
        error make {
            msg: "package installation failed"
            code: $env.LAST_EXIT_CODE
            labels: [
                {text: `package manager` span: (metadata $pm_info.name).span}
                {text: `package name`    span: (metadata $target).span}
                {text: `using sudo` span: (metadata $pm_info.sudo).span}
            ]
            inner: [$err]
        }
    } | ignore
}

# MARK: Subcommands

# Install and configure oh-my-posh as the shell prompt handler.
@category prompt
def "main oh-my-posh" []: nothing -> nothing {
    show step oh-my-posh+config

    if (which oh-my-posh | length) > 0 {
        show found $'oh-my-posh (oh-my-posh --version)'
    } else {
        dyn install oh-my-posh
    }
    let script: path = $nu.vendor-autoload-dirs | last | path join oh-my-posh.nu
    let custom: path = (resolve custom.omp.json)
    try {
        oh-my-posh init nu --config $custom --print | save --force $script
        {src: `oh-my-posh.nu` dst: $script} | show copy
    } catch {
        error make {
            msg: "failed to setup oh-my-posh"
            labels: [
                {text: `source` span: (metadata $custom).span}
                {text: `output` span: (metadata $script).span}
            ]
        }
    } | ignore
}

# Install and configure Helix as a modal editor. Tree-sitter grammars can be fetched and built with the --grammar flag.
#
# Language servers can be automatically installed using `nu setup.nu servers`.
@category editor
def "main helix" [
    --grammars (-g) # fetch and build language grammar trees
]: nothing -> nothing {
    show step (if ($grammars) { 'helix+grammars' } else { 'helix' })
    
    let current: string = try { hx --version } catch { '' }
    let target: path = $nu.default-config-dir | path basename --replace helix
    
    if $current =~ '25.07' {
        show found $current
    } else {
        if $pm_info.name =~ apt {
            run bash --script debian-unstable.sh
        }
        dyn install hx --winget-id Helix.Helix
    }
    
    match $nu.os-info.family {
        windows => 'alternate'
        unix    => 'helix'
    } | let dirname: string
    
    try {
        if not ($target | path exists) { mkdir --verbose $target }
        ls --short-names $target | where type == file
    } catch {
        error make "unable to list files in the helix config directory"
    } | get name | iter {|n|
        if $n =~ 'config.toml' {
            {src: (resolve $dirname $n --glob) dst: $target}
        } else {
            {src: (resolve helix $n) dst: ($target | path join $n)}
        } | copy file
    }
    
    if $grammars and (which hx | length) > 0 {
        try { hx --grammar fetch | complete }
        try { hx --grammar build | complete }
    } | ignore
}

# Install and configure Zellij, along with completions if carapace is installed.
@category multiplexer
def "main zellij" []: nothing -> nothing {
    show step zellij
    if (which zellij | length) > 0 {
        zellij --version | show found $in
    } else if (command cargo) {
        try {
            if (command cargo-binstall) {
                cargo binstall zellij
            } else {
                cargo install --locked zellij
            }
        } catch {
            error make 'failed to install zellij (cargo)'
        }
    } else {
        dyn install zellij
    }
    try {
        let target = ($nu.default-config-dir | path basename --replace zellij)
        if not ($target | path exists) { mkdir --verbose $target }
        {src: (resolve zellij *.kdl --glob) dst: $target} | copy file
    } catch {
        error make "failed to write zellij configuration files"
    }
    if $nu.os-info.family == unix and (command carapace) {
        let fish_completions = '/usr/share/fish/vendor_completions.d/'
        try {
            mkdir --verbose $fish_completions
            let tmp = mktemp --suffix .fish
            $"(zellij setup --generate-completion fish)" | save --raw --force $tmp
            run bash mv $"($tmp)" $"($fish_completions | path join zellij.fish)"
            {src: `zellij.fish` dst: $fish_completions} | show copy
        } catch {
            error make "failed to setup zellij completions"
        }
    } | ignore
}

# Install carapace-bin for externally sourced shell completions
@category completion
def "main carapace" []: nothing -> nothing {
    show step carapace
    if (which carapace | length) > 0 {
        show found $"(
            carapace --version
            | parse '{version} ({_}) [{_}]'
            | get --optional 0.version
        )"
    } else if $nu.os-info.family == unix {
        run bash --script carapace-fury.sh
    } else {
        log warning "skipping carapace setup; os is not unix"
    } | ignore
}

# Inventory and (optionally) install language servers consumed by the Helix language configuration.
@category editor
def "main servers" [
    --install (-i) # automatically install missing language servers
]: nothing -> nothing {
    if $install { show step language-servers }
    with-env {
        PATH: $env.path
        RUSTUP_HOME: ($env.RUSTUP_HOME? | default ($nu.home-dir | path join .rustup))
    } {
        try {
            rustup show active-toolchain
            | split words
            | first
            | let toolchain: string
            path add ($env.RUSTUP_HOME | path join toolchains $toolchain bin)
        }
        $env.path = ($env.path | split row (char esep) | uniq | where ($it | path exists))
        # --- resolve each candidate ---
        $LANGUAGE_SERVERS
        | sort --natural
        | iter --keep-order {|name| which $name
            | get --optional 0.path
            | let path: path
            if $name =~ vscode-.+ {
                (bun list --global | find $name | length) > 0
            } else {
                $path != null
            } | let found: bool
            {name: $name found: $found}
        } | let data: table<name: string found: bool>
        if $install { $data
            | where not found
            | get name
            | if ($in | length) > 0 { $in | install lsp } else {
                log info $"(ansi g)all servers are installed(ansi rst)"
            }
        } else { $data
            | table --index false
            | print
        }
    } | ignore
}

# Show information about the Nushell environment.
@category meta
def "main info" [
    --servers (-s) # evaluate and display the LSP inventory
    --full (-f) # display all supported show copyation types
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
        } | table --index false --expand | print
    } | ignore
}

# Save or update a file in the repository from this machine's copy.
#
@category meta
def "main save" [
    source: path # Path to a file to save or update in the repository.
    --dirname(-d): path # The directory name to organize the file under in the repository.
]: nothing -> nothing {
    if ($source | path type) != file { error make "source must be a file" }
    let destination: path = if $dirname == null { $source
        | path parse
        | match $in {
            {stem: 'config' extension: 'nu'} => { $HERE }
            {parent: ($LIB) extension: 'nu'} => { $HERE | path join lib }
            {parent: $parent}                => { $parent | path dirname --replace $HERE }
        }
    } else { $HERE
        | path join $dirname
        | let target: path
        | path exists
        | if not $in { try { mkdir --verbose $target } catch { error make } }
        $target
    }
    {src: $source dst: $destination}
    | copy file
    | ignore
}

# MARK: Main

# Install the repository's Nushell configuration and module library.
#
def "main base" [
    --config(-c) # Install the Nushell configuration on this host
    --autoload(-l) # Install the autoloaded files (defs/aliases) on this host
    --modules(-m) # Install the Nushell modules on this host
]: nothing -> nothing  {
    [[str flag]; [`config` $config] [`autoload` $autoload] [`modules` $modules]]
    | where flag
    | get str
    | let base: list<string>
    show step ($base | str join +)
    if not $config { [] } else {
        [{src: (resolve config.nu) dst: $nu.config-path}]
    } | if not $autoload { $in } else {
        $in | append {src: (resolve auto *.nu --glob) dst: (try { mkdir $AUTO }; $AUTO)}
    } | if not $modules { $in } else {
        $in | append {src: (resolve lib *.nu --glob)  dst: (try { mkdir $LIB }; $LIB)}
    } | iter --keep-order { copy file } | ignore
}

# Run the full setup suite (caution: opinionated)
#
def main [--all(-a)]: nothing -> nothing {
    main base --config --autoload --modules
    if $all {
        main servers --install
        main helix --grammars
        main zellij
        main carapace
        main oh-my-posh
    }
}