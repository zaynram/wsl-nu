module definitions {
    # Create an error label from a record mapping label text to metadata.
    #
    # Pipeline input must contain a record with string keys and values containing a span key.
    @category builtin
    export def labels []: record -> list<record<text: string, span: record>> {
        items {|k v| {text: $k span: ($v.span? | default {})} }
    }

    # Alternative error constructor with some convenience enhancments.
    #
    @category builtin
    export def throw [
        message: string = 'something went wrong', # Text description or information about the error
        --code(-c): oneof<nothing, int, string>, # The code to use for the error; will be set to 1 if it evaluates to nothing at runtime
        --labels(-l): oneof<record, list<record<text: string, span: record>>> = {} # Pre-formatted labels or a record mapping text to metadata records
        --inner(-i): error # An inner error to propogate through the chain; if omitted error info will originate from this function
    ]: oneof<error any> -> error {
        let struct: record = {
            msg: $message
            labels: (
                if ($labels | describe) =~ list { $labels } else {
                    $labels | labels
                }
            )
            code: ($code | default 1 | into string)
            inner: ([$in $inner] | compact --empty)
        }
        if ($struct.labels | length) > 0 { error make $struct } else { error make --unspanned $struct }
    }
    # Wait for the external command to complete and return its standard output.
    #
    @category builtin
    export def await [
        closure?: closure # The closure to execute and complete.
        --check(-c) # Whether to raise an error for non-zero exit codes
    ]: nothing -> string {
        let output: any = do --ignore-errors $closure | complete
        if not $check or $output.exit_code? == 0 {
            $output.stdout
        } else {
            let msg: string = $output.stderr? | default "command completed with errors"
            throw $msg --code $output.exit_code --labels {
                command: (metadata $closure)
            }
        }
    }

    const SETUP_PATH: path = $nu.home-dir | path join code nu setup.nu
    const SETUP_COMMANDS: list<string> = [carapace helix oh-my-posh servers zellij]
    def setup [...args: string]: nothing -> nothing { nu $SETUP_PATH ...($args | compact --empty) }
    # Convenience wrapper for the automated setup script (~/code/nu/setup.nu)
    #
    # If no subcommand is provided, arguments are passed to the script's main function.
    # If a single subcommand is provided with --command(-c), then the arguments will be forwarded to that function.
    #   * This is the same behavior as passing the subcommand and arguments without the flag.
    # If a selection of subcommands is provided using --pick(-p)/--omit(-o), arguments will not be passed.
    #
    # To view more specific help information, you can pass --help as a string with the subcommand(s).
    #
    @category configuration
    export def --wrapped "setup nu" [
        ...rest: string # Arguments to pass through to function. Subcommands: [save|info|carapace|helix|oh-my-posh|languages|zellij]
        --pick(-p): list<string> # Selection of subcommands to run. Choices: [carapace|helix|oh-my-posh|languages|zellij]
        --omit(-o): list<string> # Selection of subcommands to skip. Choices: [carapace|helix|oh-my-posh|languages|zellij]
    ]: nothing -> nothing {
        if $pick == null and $omit == null { setup ...$rest } else {
            let omit: list<string> = $omit | default []
            let pick: list<string> = $pick | default $SETUP_COMMANDS
            $SETUP_COMMANDS
            | where ($it in $pick and not ($it in $omit))
            | iter { setup $in ...$rest }
        }
    }

    # Run a command in an elevated Bash session.
    #
    @category elevation
    export def "sudo bash" [
        --script(-s): path, # Path to a bash script to invoke
        ...args: string # Joined as spaces and run as a command (if no script) else passed to script
    ]: oneof<nothing, list<string>> -> nothing {
        if $script != null {
            try {
                ^sudo bash $script ...$args
            } catch {|| throw "script invocation exited with errors" --labels {
                script: $script
                args: ($args | str join ' ')
            } }
        } else {
            let content: string = ($in
                | default []
                | prepend '#!/usr/bin/env bash'
                | append ($args | str join ' ')
                | str join "\n")
            let tmp: path = mktemp --suffix .sh
            try {
                $content | save --force $tmp
                ^sudo bash $tmp
            } catch {|| throw "command exited with errors" --labels {
                command: ($args | str join ' ')
                tempfile: $tmp
            } } finally {
                rm --force $tmp
            }
        }
    }

    # Run a command or closure in an elevated Nushell session.
    #
    @category elevation
    export def "sudo nu" [
        closure: closure # The closure to execute
    ]: any -> oneof<nothing, any> {
        to nuon | let input
        let command: string = try {
            $closure | to nuon --serialize | from nuon
        } catch {
            throw "failed to deserialize command"
        }

        try {
            $input | sudo (which nu | get 0.path) --stdin --commands $command
        } catch {|| throw "command completed with errors" --labels ({
                command: (metadata $closure) input: (metadata $input)
            }) }
    }

    # Attach or create a zellij session for a known project.
    #
    # Known projects are resolved by matching the session name to a directory name under ~/code.
    # To override the session name or working directory, use the --directory/-d flag.
    #
    @category multiplexer
    export def attach [
        session: string # The desired session name to create or attach to.
        --project(-p) # Resolve the session name against the projects folder. Prioritized over --directory.
        --directory(-d): path # Override the directory to spawn the process in. Does nothing if --project is passed.
    ]: nothing -> nothing {
        try {
            match [$project $directory] {
                [true, $d]  => {
                    [$nu.home-dir code $session] | path join
                }
                [false, $d] => {
                    $d | default $env.pwd
                }
            } | cd $in
            await { zellij attach $session --create-background }
            zellij --session $session action override-layout main
            zellij attach $session
        } catch {
            throw "failed to attach (or create) session" --labels {
                session: (metadata $session)
            }
        }
    }

    # Detach from a zellij session using the session's name.
    #
    @category multiplexer
    export def detach [
        session?: string # The name of the session to detach from
    ]: nothing -> nothing {
        zellij ...(
            if $session != null { [--session $session] } else { [] }
        ) action detach
    }

    const DOT: string = $"(ansi attr_blink_fast)(ansi g)●(ansi rst)"
    const KEYBINDS: string = $"(ansi attr_dimmed)press q to quit, h to toggle header, or any other key to redraw.(ansi rst)"
    const PROMPT: string = $"(ansi attr_dimmed)└──(ansi rst) (ansi blue)$(ansi rst)"
    # Run an auto-updating command in a target directory.
    #
    export def monitor [
        --cwd (-d): path # The directory to spawn the command in; uses cwd if omitted
        --repr(-r): string # Override the command serialization header value
        --wait(-w): duration # The refresh interval as a duration; used as `input listen` timeout duration
        --hide(-h) # Hide the header by default (can be toggled back on)
    ]: closure -> nothing {
        let c: closure = $in
        let s: string = $repr | default (
            $c
            | to nuon --serialize --raw-strings
            | parse "{_} {command} }{_}"
            | get --optional 0.command
            | str trim
        )
        let t: duration = $wait | default 2sec
        with-env {pwd: ($cwd | default $env.pwd) head: (not $hide)} {
            tput smcup
            try {
                loop {
                    tput home
                    if $env.head { print $"($DOT) (date now)\n($PROMPT) ($s | nu-highlight)\n($KEYBINDS)\n" }
                    print --no-newline (do $c)
                    match (try { input listen --timeout $t --types [key] } catch {}) {
                        {code: q} => { break }
                        {code: c modifiers: $m} if $m.0? =~ control => { break }
                        {code: $x} => { clear; if $x == h { $env.head = not $env.head } }
                    }
                }
            } catch {|err|
                tput -x rmcup
                throw --inner $err "monitor exited with errors"
            }
            tput -x rmcup
        }
    }

    # Spawn a git status watcher for the target repository.
    #
    @category source-control
    export def "git watch" [
        ...args: string # Arguments for the git status invocation; overrides defaults
        --repository(-r): path # Path to the repository to spawn the process in (defaults to cwd)
        --no-tag(-n) # Disable flag resolution from the `gstat` plugin
        --interval(-i): duration # Duration to wait between each iteration
    ]: nothing -> nothing {
        let args: list<string> = if ($args | length) > 0 { $args } else { [-s -unormal --renames] }
        {
            if $no_tag { gstat --no-tag } else { gstat }
            | items {|k v| if $k !~ '(wt|idx)_' { [$k $v] } }
            | into record
            | merge {state: (git status ...$args | nu-highlight)}
            | compact --empty
            | table --width (tput cols | into int) --theme frameless
        }
        | monitor --wait $interval --cwd ($repository | default $env.pwd) --repr $'git status ($args | str join " ")'
    }

    const ALIAS_NU: path = path self alias.nu
    # Edit the autoloaded alias definition file
    #
    @category configuration
    export def "config alias" []: nothing -> nothing { ^$env.config.buffer_editor $ALIAS_NU }

    const DEF_NU: path = path self
    # Edit the autoloaded function definition file
    #
    @category configuration
    export def "config def" []: nothing -> nothing { ^$env.config.buffer_editor $DEF_NU }

    # Interact with a file from an autoload directory.
    #
    # If the `target` argument is omitted, the items in the directory will be listed.
    @category configuration
    export def "config auto" [
        target?: string # The autoload file to target (can omit `.nu` suffix)
        --vendor(-v) # Use the vendor autoload directory (defaults to user)
    ]: nothing -> oneof<nothing table> {
        let dir: path = if $vendor { $nu.vendor-autoload-dirs } else { $nu.user-autoload-dirs } | first
        if $target == null {
            try {
                ls $dir | where name !~ 'def|alias'
            }
        } else {
            editor ($dir | path join $"($target | str replace .nu '').nu")
        }
    }

    # Edit a non-nushell configuration file.
    #
    # If the `dirname` argument is omitted, the eligible items are listed instead.
    @category configuration
    export def config [
        target?: oneof<string path> # The directory name to search for config files under
        --path(-p): path # The path to the config file within the directory
    ]: nothing -> oneof<nothing table> {
        let dir: path = $nu.home-dir | path join .config
        if $target != null {
            try {
                cd ($dir | path join $target)
                let fp: path = (
                    ls ($path | default *config* | into glob)
                    | where type == file
                    | get 0.name
                )
                if $fp != null { editor $fp } else {
                    throw "could not resolve configuration file" --labels {target: $target, path: $fp}
                }
            } catch { error make }
        } else {
            try {
                ls $dir | where name !~ nushell
            }
        }
    }
}

overlay use definitions
