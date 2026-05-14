#!/usr/bin/env nu --stdin
use std/log
use std/util ["path add" null-device]

overlay use ./share/nushell/modules/custom.nu

const ROOT: path = path self .
const LIB = $nu.data-dir | path join modules

if not ($LIB | path exists) {
    try { mkdir --verbose $LIB }
}

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
    {family: windows} => ({
        name: winget
        sudo: false
        args: [--disable-interactivity]
    })
    {family: unix}    => ({
        name: apt-get
        sudo: (command sudo)
        args: [--yes]
    })
}

let vendor: path = $nu.vendor-autoload-dirs | where $it =~ (whoami) | first
if $vendor == null { error make "unable to resolve vendor autoload directory" }
if not ($vendor | path exists) { mkdir --verbose $vendor }

let user: path = $nu.user-autoload-dirs | first
if $user == null { error make "unable to detect user autoload directory" }
if not ($user | path exists) { mkdir --verbose $user }

def "show step" [name: string, --verb(-v): string = processing]: nothing -> nothing {
    log info $"($verb): (ansi c)($name)(ansi rst)"
}

def "show found" [desc: string, --noun(-n): string = version]: nothing -> nothing {
    log info $"found existing ($noun): (ansi b)($desc)(ansi rst)"
}

def "show copy" []: record<src: string, dst: string> -> nothing {
    let src: path = $in.src
    let dst: path = $in.dst
    let unstyled: string = $src | path basename
    let styled: string = $'(ansi steelblue1b)(if ($src | path type) == dir { ansi bo })($unstyled)(ansi rst)'
    let target: path = if $dst =~ $unstyled { $dst } else {
        dst | path join $unstyled
    } | str replace $nu.home-dir ~
    log info $'($styled) -> (ansi rst)(ansi lime)($target)(ansi rst)'
}

def command [name: string]: nothing -> bool {
    which $name | is-not-empty
}

def --wrapped "pixi global" [...rest: string]: nothing -> nothing {
    if (command pixi) {
        ^pixi global ...$rest
    } else if (command uv) {
        uv tool ...([
            ($rest | first)
            ($rest | last)
        ] | compact --empty | uniq)
    } else {
        error make "no global tool installer detected"
    }
}

def resolve [...segments: string]: nothing -> glob {
    $ROOT | path join ...$segments | into glob
}

def "copy file" []: record<src: glob, dst: string> -> nothing {
    let r: record<src: glob dst: path> = $in
    let files: list<path> = try {
        cd $ROOT
        ls --full-paths $r.src | get name
    } | default [] | compact
    try {
        for f in $files {
            cp --update --recursive $f $r.dst
            {src: $f, dst: $r.dst} | show copy
        }
    } catch {
        error make {
            msg: "failed to copy file(s)"
            labels: [
                {
                    text: `source`
                    span: (metadata $r.src).span
                }
                {
                    text: `destination`
                    span: (metadata $r.dst).span
                }
            ]
        }
    }
}

def "dyn output" [descriptor: string = "operation", target?: string]: record<stdout: string, stderr: string, exit_code: int> -> nothing {
    let output: record = $in
    let prefix: string = if $target == null { '' } else { $"($target)/" }
    show step (ansi c)($prefix)($descriptor)(ansi rst) --verb "awaiting completion"
    match $output {
        {exit_code: 0}           => { log info (ansi g)ok(ansi rst) }
        {stderr: $e} if $e != "" => { log error $e }
        {exit_code: $c}          => { log error ("exited with code:")($c) }
    }
    return
}

def "run bash" [--no-elevate(-n), ...command: string]: nothing -> nothing {
    if not (command bash) { error make "could not detect bash executable" }
    if not $no_elevate and (command sudo) {
        ^sudo bash -c ...$command
    } else {
        ^bash -c ...$command
    } | complete | dyn output
}

def "setup languages" [...packages: string]: [ # nu-lint-ignore: max_function_body_length
    oneof<nothing list<string>> -> nothing
] {
    default []
    | append $packages
    | par-each {|pkg| try {
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

def "dyn install" [package: string, --winget-id(-i): string]: nothing -> nothing {
    let retarget_win: bool = $pm_info.name =~ winget and $winget_id != null
    let target: string = if $retarget_win { $winget_id } else { $package }
    let parts: record<command: string args: list<string>> = if $pm_info.sudo {
        {
            command: `sudo`
            args: [$pm_info.name install $target]
        }
    } else {
        {
            command: $pm_info.name
            args: [install $target]
        }
    }
    try {
        ^$parts.command ...$parts.args
        | complete
        | if $in.exit_code > 0 {
            error make {
                msg: $in.stderr
                code: $in.exit_code
                labels: [
                    {
                        text: `command`
                        span: (metadata $parts.command).span
                    }
                    {
                        text: `arguments`
                        span: (metadata $parts.args).span
                    }
                ]
            }
        } else {
            $in | dyn output install $target
        }
    } catch {|err| error make {
        msg: "package installation failed"
        code: $env.LAST_EXIT_CODE
        labels: [
            {
                text: `package manager`
                span: (metadata $pm_info.name).span
            }
            {
                text: `package name`
                span: (metadata $target).span
            }
            {
                text: `using sudo`
                span: (metadata $pm_info.sudo).span
            }
        ]
        inner: [$err]
    } }
}

def "pkg installed" [name: string]: nothing -> bool {
    (command $name) or ([
        { try { bun --global list } }
        { try { pixi global list } }
        { try { cargo --list } }
    ] | any { (do $in | to text) =~ $name })
}

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
    let script: path = $vendor | path join oh-my-posh.nu

    try {
        oh-my-posh init nu --config (resolve config custom.omp.json) --print
        | save --force $script
        {src: `oh-my-posh.nu`, dst: $script} | show copy
    } catch {
        error make {
            msg: "failed to setup oh-my-posh"
            labels: [
                {
                    text: `output`
                    span: (metadata $script).span
                }
            ]
        }
    }
}

# Install and configure Zellij, along with completions if carapace is installed.
@category multiplexer
def "main zellij" []: nothing -> nothing {
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
        let target: path = $nu.default-config-dir | path basename --replace zellij
        if not ($target | path exists) { mkdir --verbose $target }
        {
            src: (resolve zellij *.kdl)
            dst: $target
        } | copy file
    } catch {
        error make "failed to write zellij configuration files"
    }

    if $nu.os-info.family == unix and (command carapace) {
        show step zellij/completions

        let fish_completions: path = [/ usr share fish completions] | path join
        let destination: path = $fish_completions | path join zellij.fish

        if ($destination | path type) == file {
            show found $destination --noun completions
        } else {
            try {
                mktemp --suffix .fish | let tmp
                if ($fish_completions | path type) != dir { mkdir $fish_completions }
                $"(zellij setup --generate-completion fish)\n" | save --raw --force $tmp
                run bash mv $tmp $destination
                {src: `zellij.fish`, dst: $fish_completions} | show copy
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
    } else if $nu.os-info.family == unix {
        log info "copy `apt/sources.list.d/fury.list` to `/etc/apt/sources.list.d`"
        log info "then install with `sudo apt-get update; sudo apt-get install carapace-bin`"
    } else {
        log warning "skipping carapace setup; os is not unix"
    }
}

# Inventory and (optionally) install language packages consumed by the Helix configuration.
@category editor
def "main languages" [ # nu-lint-ignore: print_and_return_data
    --install (-i) # automatically install missing language servers, debuggers, and formatters
]: nothing -> nothing {
    show step languages/inventory
    with-env {
        PATH: $env.path
        RUSTUP_HOME: ($env.RUSTUP_HOME? | default ($nu.home-dir | path join .rustup))
    } {
        try {
            let toolchain: string = rustup show active-toolchain | split words | first
            path add ($env.RUSTUP_HOME | path join toolchains $toolchain bin)
        }
        $env.path = ($env.path | split row (char esep) | uniq | where ($it | path exists))

        # --- resolve each candidate ---
        let data: table<name: string found: bool> = $LANGUAGE_PACKAGES
        | sort --natural
        | par-each --keep-order { {name: $in found: (pkg installed $in)} }

        if not $install {
            $data | table --index false | print
        } else {
            let missing: list = $data | where not $it.found | get name
            if ($missing | length) == 0 {
                log info $"(ansi g)all language packages are installed(ansi rst)"
            } else {
                show step language-servers/install
                $missing | setup languages
            }
        }

        return
    }
}

# Show information about the Nushell environment.
@category meta
def "main info" [ # nu-lint-ignore: print_and_return_data
    --languages (-l) # evaluate and display the LSP inventory
    --full (-f) # display all supported show copyation types
]: [
    nothing -> nothing
] {
    if $languages or $full { main languages }
    if $full or not $languages {
        show step external-packages/inventory
        [[name, command]; [carapace, carapace], [oh-my-posh, oh-my-posh], [helix, hx], [zellij, zellij]] | par-each {|row| {
                name: $row.name
                path: (which $row.command | get --optional 0.path)
                installed: (command $row.command)
            }
        } | table --index false --expand | print
    }
    return
}

# Save or update a file in the repository from this machine's copy.
#
@category meta
def "main save" [
    source: path # Path to a file to save or update in the repository.
    --dirname(-d): path # The directory name to organize the file under in the repository.
]: nothing -> nothing {
    if ($source | path type) != file { error make "source must be a file" }
    let destination: path = if $dirname == null {
        $source
        | path parse
        | match $in {
            {stem: 'config', extension: 'nu'} => { $ROOT }
            {parent: $LIB, extension: 'nu'} => {
                $ROOT | path join lib
            }
            {parent: $parent} => {
                $parent | path dirname --replace $ROOT
            }
        }
    } else {
        let target: path = $ROOT | path join $dirname
        if not ($target | path exists) {
            try { mkdir --verbose $target } catch { error make }
        }
        return $target
    }
    {src: $source, dst: $destination} | copy file | return
}

# Setup the nushell configuration and data files.
def "main nushell" []: table<name: string, data: record> -> nothing {
    if ($in | is-empty) { (main info | return) }
    for row in $in {
        show step $row.name
        $row.data | copy file
    }
}

let mapping: table<name: string default: closure> = [[name, default]; [languages, {|| main languages --install }], [zellij, {|| main zellij }], [carapace, {|| main carapace }], [oh-my-posh, {|| main oh-my-posh }]]

# Install the repository's Nushell configuration and module library.
# Supports running all subcommands with defaults as well.
#
def main [
    --config(-c) # Install the Nushell configuration on this host
    --autoload(-a) # Install the autoloaded files (defs/aliases) on this host
    --modules(-m) # Install the Nushell modules on this host
    --shell(-s) # Install all Nushell files; enables [--config --autoload --modules]
    --no-exec(-n) # Return the data for the default setup values and exit
    --default(-d) # Run all setup functions, not just the base set. Enables all other flags.
    --pick(-p): list<string> = [] # Selection of the possible subcommands to run. Does nothing if `--all` is provided. Can be combined with `--shell`.
]: nothing -> nothing {
    let data: table = [[name, flag, data]; [config, $config, {
        src: (resolve config $nu.os-info.name nushell config.nu)
        dst: $nu.default-config-dir
    }], [autoload, $autoload, {
        src: (resolve config $nu.os-info.name nushell autoload *.nu)
        dst: $user
    }], [modules, $modules, {
        src: (resolve config $nu.os-info.name nushell modules *.nu)
        dst: $LIB
    }]] | where $it.flag or $shell or $default | select name data

    if $no_exec { return ($data | table --expand --index false) } else {
        $data | main nushell
    }

    let subcommands: list<closure> = if $default {
        $mapping
    } else if ($pick | is-not-empty) {
        $mapping | where name in $pick
    } | get default

    for sub in $subcommands { do $sub }
}
