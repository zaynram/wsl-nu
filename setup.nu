#!/usr/bin/env nu
use std/log
use std/util ["path add" null-device]

overlay use ./lib/custom.nu

#MARK: Paths

const HERE = path self .
const BIN = $HERE | path join scripts
const LIB = $nu.data-dir | path join modules

if not ($LIB | path exists) {
    try { mkdir --verbose $LIB }
}

#MARK: Data

const LANGUAGE_PACKAGES: list<string> = [
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
    jq-lsp
    fish-lsp
    svelteserver
    rumdl
    ty
    pylsp
    markdown-oxide
    jedi-language-server
    kdlfmt
    texlab
    just-lsp
    bibtex-tidy
    yamlfmt
]

let pm_info: record<name: string sudo: bool args: list<string>> = match $nu.os-info {
    {family: windows} => ({name: winget  sudo: false          args: [--disable-interactivity]})
    {family: unix}    => ({name: apt-get sudo: (command sudo) args: [--yes]})
}

#MARK: Logging

def "show step" [name: string --verb(-v): string = processing]: nothing -> nothing {
    log info $"($verb): (ansi c)($name)(ansi rst)"
}

def "show found" [desc: string --noun (-n): string = version]: nothing -> nothing {
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

def --wrapped "pixi global" [...rest: string]: nothing -> nothing {
    if (command pixi) {
        ^pixi global ...$rest
    } else if (command uv) {
        uv tool ...([($rest | first) ($rest | last)] | compact --empty | uniq)
    } else {
        error make "no global tool installer detected"
    }
}

def resolve [...segments: string --glob (-g)]: [
    nothing -> oneof<path glob>
] {|| prepend $HERE
    | append $segments
    | path join
    | if $glob { $in | into glob } else { $in }
}

def "copy file" []: [
    record<src: oneof<glob path>, dst: path> -> nothing
] {|| let r: record<src: oneof<glob path> dst: path>
    try {
        match ($r.src | describe) {
            glob => { $r.src
                | into string
                | let s: string
                | path dirname
                | cd $in
                $s | path basename | glob $in
            }
            _    => [$r.src]
        } | compact | iter {
            cp --update --recursive $in $r.dst
            {src: $in dst: $r.dst} | show copy
        }
    } catch {
        error make {
            msg: "failed to copy file(s)"
            labels: [
                {text: `source`      span: (metadata $r.src).span}
                {text: `destination` span: (metadata $r.dst).span}
            ]
        }
    }
    ignore
}

def "dyn output" [descriptor: string = "operation" target?: string]: [
    record<stdout:string stderr: string exit_code: int> -> nothing
] {|| let output: record<stdout:string stderr: string exit_code: int>
    if $target == null { '' } else { $"($target)/" }
    | let prefix: string
    show step (ansi c)($prefix)($descriptor)(ansi rst) --verb "awaiting completion"
    match $output {
        {exit_code: 0}           => { log info (ansi g)ok(ansi rst) }
        {stderr: $e} if $e != "" => { log error $e }
        {exit_code: $c}          => { log error ("exited with code:")($c) }
    }; ignore
}

def "run bash" [...cmdline: string --no-elevate(-n) --script(-s): oneof<path glob>]: nothing -> nothing {
    if not (command bash) { error make "could not detect bash executable" }
    match $script {
        null => { $cmdline | str join ' ' }
        _    => { try { cd $BIN; ls --short-names $script | get --optional 0.name } }
    } | if $in == null { return } else if $script == null { [-c $in] } else { [$in] }
    | let args: list<string>
    try {
        if not $no_elevate and (command sudo) { ^sudo bash ...$args } else { ^bash ...$args }
        | complete | dyn output
    }
}

def "setup languages" [...packages: string]: [ # nu-lint-ignore: max_function_body_length
    oneof<nothing list<string>> -> nothing
] {|| default []
    | append $packages
    | iter {|pkg| try {
            log info $"installing package: (ansi b)($pkg)(ansi rst)"
            match $pkg {
                jq-lsp                       => { brew install jq-lsp }
                rust-analyzer                => { rustup component add rust-src }
                pyright                      => { pixi global install --expose pyright --expose pyright-langserver pyright }
                ruff                         => { pixi global install ruff }
                marksman                     => { pixi global install marksman }
                tombi                        => { pixi global install tombi }
                ty                           => { pixi global install ty }
                jedi-language-server         => { pixi global install jedi-language-server }
                pylsp                        => { pixi global install --expose pylsp python-lsp-server }
                yamlfmt                      => { pixi global install yamlfmt }
                typescript-language-server   => { bun add --global typescript typescript-language-server }
                oxlint                       => { bun add --global oxlint }
                prettier                     => { bun add --global prettier }
                vscode-langservers-extracted => { bun add --global vscode-langservers-extracted }
                yaml-language-server         => { bun add --global yaml-language-server }
                bash-language-server         => { bun add --global bash-language-server }
                svelteserver                 => { bun add --global svelte-language-server }
                fish-lsp                     => { bun add --global fish-lsp }
                kdlfmt                       => { bun add --global kdlfmt }
                bibtex-tidy                  => { bun add --global bibtex-tidy }
                nufmt                        => { cargo install --git https://github.com/nushell/nufmt }
                nu-lint                      => { cargo install nu-lint }
                rumdl                        => { cargo install rumdl }
                just-lsp                     => { cargo install just-lsp }
                texlab                       => { cargo install --git https://github.com/latex-lsp/texlab }
                lldb-dap                     => { dyn install lldb --winget-id LLVM.LLVM }
                markdown-oxide               => {
                    if (command cargo-binstall) {
                        cargo binstall --git https://github.com/feel-ix-343/markdown-oxide markdown-oxide
                    } else if (command cargo) {
                        cargo install --locked --git https://github.com/Feel-ix-343/markdown-oxide.git markdown-oxide
                    } else if (command winget) {
                        winget install FelixZeller.markdown-oxide --disable-interactivity
                    } else if (command brew) {
                        brew install markdown-oxide
                    }
                }
            } | complete | dyn output install $pkg
        } catch {
            log error $'package install failed: ($pkg)'
        }
    }
}

def "dyn install" [package: string --winget-id(-i): string]: nothing -> nothing {
    let retarget_win: bool = $pm_info.name =~ winget and $winget_id != null
    let target: string = if $retarget_win { $winget_id } else { $package }
    let parts: record<command: string args: list<string>> = if $pm_info.sudo {
        {command: `sudo`, args: [$pm_info.name install $target]}
    } else {
        {command: $pm_info.name args: [install $target]}
    }
    try {
        ^$parts.command ...$parts.args
        | complete
        | if $in.exit_code > 0 {
            error make {
                msg: $in.stderr
                code: $in.exit_code
                labels: [
                    {text: `command`    span: (metadata $parts.command).span}
                    {text: `arguments`  span: (metadata $parts.args).span}
                ]
            }
        } else {
            $in | dyn output install $target
        }
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
    }
}

def "pkg installed" [name: string]: nothing -> bool {
    (command $name) or ([
        { try { bun --global list } }
        { try { pixi global list } }
        { try { cargo --list } }
    ] | any { (do $in | to text) =~ $name })
}

# MARK: Subcommands

# Install and configure oh-my-posh as the shell prompt handler.
@category prompt
def "main oh-my-posh" []: nothing -> nothing {
    show step oh-my-posh/install
    if (which oh-my-posh | length) > 0 {
        show found $'oh-my-posh (oh-my-posh --version)'
    } else {
        dyn install oh-my-posh
    }

    show step oh-my-posh/config
    $nu.vendor-autoload-dirs
    | last
    | path join oh-my-posh.nu
    | let script: path

    try {
        oh-my-posh init nu --config (resolve custom.omp.json) --print
        | save --force $script
        {src: `oh-my-posh.nu` dst: $script} | show copy
    } catch {
        error make {
            msg: "failed to setup oh-my-posh"
            labels: [
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
]: nothing -> nothing {
    show step helix/install

    if (command hx) {
        show found (hx --version)
    } else {
        if $pm_info.name =~ apt { run bash --script debian-unstable.sh }
        dyn install hx --winget-id Helix.Helix
    }

    show step helix/config

    $nu.default-config-dir
    | path basename --replace helix
    | let target: path

    try {
        if not ($target | path exists) { mkdir --verbose $target }
        ls --short-names $target | where type == file
    } catch {
        error make "unable to list files in the helix config directory"
    } | get name | iter {|n|
        let use_alt: bool = $n =~ `config` and $nu.os-info.family == windows
        {
            src: (if $use_alt { resolve alternate $n } else { resolve helix $n })
            dst: ($target | path join $n)
        } | copy file
    }

    show step helix/grammars

    if $grammars and (command hx) {
        try { hx --grammar fetch | complete | dyn output fetch grammars }
        try { hx --grammar build | complete | dyn output build grammars }
    }
}

# Install and configure Zellij, along with completions if carapace is installed.
@category multiplexer
def "main zellij" []: nothing -> nothing { # nu-lint-ignore: max_function_body_length
    show step zellij/install
    if (command zellij) {
        show found (zellij --version)
    } else if not (command cargo) {
        dyn install zellij
    } else {
        let args: list<string> = if (command cargo-binstall) { [binstall] } else { [install --locked] }
        try { cargo ...$args zellij } catch { error make 'failed to install zellij (cargo)' }
    }

    show step zellij/config
    try {
        $nu.default-config-dir
        | path basename --replace zellij
        | let target: path
        if not ($target | path exists) { mkdir --verbose $target }
        {src: (resolve zellij *.kdl --glob) dst: $target} | copy file
    } catch {
        error make "failed to write zellij configuration files"
    }

    if $nu.os-info.family == unix and (command carapace) {
        show step zellij/completions

        [/ usr share fish completions]
        | path join
        | let fish_completions: path
        | path join zellij.fish
        | let destination: path

        if ($destination | path type) == file {
            show found $destination --noun completions
        } else {
            try {
                mktemp --suffix .fish | let tmp: path
                if ($fish_completions | path type) != dir { mkdir $fish_completions }
                $"(zellij setup --generate-completion fish)\n" | save --raw --force $tmp
                run bash mv $tmp $destination
                {src: `zellij.fish` dst: $fish_completions} | show copy
                rm $tmp --force
            } catch {
                error make "failed to setup zellij completions"
            }
        }
    }
}

# Install carapace-bin for externally sourced shell completions
@category completion
def "main carapace" []: nothing -> nothing {
    show step carapace/install
    if (command carapace) {
        show found $"(
            carapace --version
            | parse '{version} ({_}) [{_}]'
            | get --optional 0.version
        )"
    } else if ($nu.os-info.family == unix) {
        run bash --script carapace-fury.sh
    } else {
        log warning "skipping carapace setup; os is not unix"
    }
}

# Inventory and (optionally) install language packages consumed by the Helix configuration.
@category editor
def "main languages" [
    --install (-i) # automatically install missing language servers, debuggers, and formatters
]: nothing -> nothing {
    show step languages/inventory
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
        $LANGUAGE_PACKAGES
        | sort --natural
        | iter --keep-order { {name: $in found: (pkg installed $in)} }
        | let data: table<name: string found: bool>

        if not $install { $data | table --index false | print } else { $data
            | where not found
            | get name
            | let missing: list<string>
            if ($missing | length) == 0 {
                log info $"(ansi g)all language packages are installed(ansi rst)"
            } else {
                show step language-servers/install
                $missing | setup languages
            }
        }
    }; ignore
}

# Show information about the Nushell environment.
@category meta
def "main info" [
    --languages (-l) # evaluate and display the LSP inventory
    --full (-f) # display all supported show copyation types
]: [
    nothing -> nothing
] {
    if $languages or $full { main languages }

    if $full or not $languages {
        show step external-packages/inventory
        [[name command];
            [carapace   carapace ]
            [oh-my-posh oh-my-posh]
            [helix      hx]
            [zellij     zellij]
        ] | par-each {|row| {
                name: $row.name
                path: (which $row.command | get --optional 0.path)
                installed: (command $row.command)
            }
        } | table --index false --expand | print
    }; ignore
}

# Save or update a file in the repository from this machine's copy.
#
@category meta
def "main save" [
    source: path # Path to a file to save or update in the repository.
    --dirname(-d): path # The directory name to organize the file under in the repository.
]: nothing -> nothing {
    if ($source | path type) != file { error make "source must be a file" }

    if $dirname == null { $source
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
    } | let destination: path

    {src: $source dst: $destination} | copy file | ignore
}

# MARK: Main

# Install the repository's Nushell configuration and module library.
# Supports running all subcommands with defaults as well.
#
def main [
    --config(-c) # Install the Nushell configuration on this host
    --autoload(-l) # Install the autoloaded files (defs/aliases) on this host
    --modules(-m) # Install the Nushell modules on this host
    --all(-a) # Run all setup functions, not just the base set. Enables all other flags.
]: nothing -> nothing {
    [[str flag]; [`config` $config] [`autoload` $autoload] [`modules` $modules]]
    | where flag or $all
    | get str
    | let desc: list<string>
    if ($desc | length) > 0 { $desc | str join + } else { main info }
    if not $config or $all { [] } else {
        [{src: (resolve config.nu) dst: $nu.config-path}]
    } | if not $autoload or $all { $in } else {
        $in | append {src: (resolve auto *.nu --glob) dst: (autoload path --user)}
    } | if not $modules or $all { $in } else {
        $in | append {src: (resolve lib *.nu --glob)  dst: $LIB}
    } | iter --keep-order { copy file }

    if $all {
        main languages --install
        main helix --grammars
        main zellij
        main carapace
        main oh-my-posh
    }
}