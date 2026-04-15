# Edit the autoloaded alias definition file
@category configuration
def "config alias" []: nothing -> nothing {
    ^$env.config.buffer_editor (path self | path basename --replace alias.nu)
}

# Edit the autoloaded function definition file
@category configuration
def "config def" []: nothing -> nothing { ^$env.config.buffer_editor (path self) }

# Convenience wrapper for the automated setup script (~/code/nu/setup.nu)
#
# If no subcommand is provided, arguments are passed to the script's main function.
# If a single subcommand is provided with --command(-c), then the arguments will be forwarded to that function.
#   * This is the same behavior as passing the subcommand and arguments without the flag.
# If a selection of subcommands is provided using --pick(-p)/--omit(-o), arguments will not be passed.
#
# To view more specific help information, you can pass --help as a string with the subcommand(s).
@category configuration
def --wrapped "setup nu" [
    ...rest: string # Arguments to pass through to function. Subcommands: [save|info|carapace|helix|oh-my-posh|servers|zellij]
    --pick(-p): list<string> # Selection of subcommands to run. Choices: [carapace|helix|oh-my-posh|servers|zellij]
    --omit(-o): list<string> # Selection of subcommands to skip. Choices: [carapace|helix|oh-my-posh|servers|zellij]
]: nothing -> nothing {
    [
        carapace
        helix
        oh-my-posh
        servers
        zellij
    ] | let subcommands: list<string>

    {|sub?: string| nu ...(
            $nu.home-dir
            | path join code nu setup.nu
            | append [$sub ...$rest]
            | compact --empty
        )
    } | let run: closure

    if $pick == null and $omit == null { do $run } else {
        let omit = $omit | default []
        let pick = $pick | default $subcommands
        $subcommands
        | where ($it in $pick and not ($it in $omit))
        | iter { do $run $in }
    }
}

# Run a command in an elevated Bash session.
@category elevation
def "sudo bash" [...args: string]: [
    nothing -> record<stdout: string stderr: string exit_code: int>
    list<string> -> record<stdout: string stderr: string exit_code: int>
] {|| default []
    | prepend ['#!/usr/bin/env bash' ($args | str join ' ')]
    | str join "\n"
    | let content: string
    mktemp --suffix .sh
    | let tmp: path
    try { $content | save $tmp } catch {
        error make {
            msg:"failed to write temporary script"
            labels: [
                {text: `path`    span: (metadata $tmp).span}
                {text: `content` span: (metadata $content).span}
            ]
        }
    }
    try { sudo (which bash | get 0.path) $tmp } | complete
}

# Run a command or closure in an elevated Nushell session.
@category elevation
def "sudo nu" [
    closure: closure # The closure to execute
]: [
    any -> nothing
    any -> any
] {|| to nuon | let input

    try { $closure | to nuon --serialize | from nuon } catch {
        error make "failed to deserialize command"
    } | let command

    try {
        $input | sudo (which nu | get 0.path) --stdin --commands $command
    } catch {|err|
        error make {
            msg: "command completed with errors"
            code: $env.LAST_EXIT_CODE
            labels: [
                {text: `command` span: (metadata $command).span}
                {text: `input`   span: (metadata $input).span}
            ]
            inner: [$err]
        }
    }
}

# Attach or create a zellij session for a known project.
#
# Known projects are resolved by matching the session name to a directory name under ~/code.
# To override the session name or working directory, use the --directory/-d flag.
@category multiplexer
def attach [
    session: string # The desired session name to create or attach to
    --no-editor(-n) # Sets the session layout to 'no-editor' instead of 'hx-editor'
    --directory(-d): path # Override the directory to spawn the process in
]: nothing -> nothing {
    let target: path = if $directory != null { $directory } else {
        [$nu.home-dir code $session] | path join
    }
    match ($target | path type) {
        dir => {
            try { cd $target } catch { error make 'failed to change to target directory' }
            try { zellij attach --create-background $session | out+err>/dev/null }
            if $no_editor { 'no-editor' } else { 'hx-editor' }
            | do { zellij --session $session action override-layout $in }
            zellij attach $session
        }
        _ => (error make {
                msg: 'invalid target directory'
                labels: [
                    {
                        text: session
                        span: (metadata $session).span
                    }
                    {
                        text: target
                        span: (metadata $target).span
                    }
                ]
            })
    }
}

# Detach from a zellij session using the session's name.
@category multiplexer
def detach [
    session: string # The name of the session to detach from
]: nothing -> nothing {
    zellij --session $session action detach
}
