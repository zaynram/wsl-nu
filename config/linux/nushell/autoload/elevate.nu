module elevate {
    # Run a command in an elevated Bash session.
    #
    @category shells
    export def "sudo bash" [
        --script(-s): path, # Path to a bash script to invoke
        ...args: string # Joined as spaces and run as a command (if no script) else passed to script
    ]: oneof<nothing, list<string>> -> nothing {
        if $script != null {
            try {
                ^sudo bash $script ...$args
            } catch {
                throw "script invocation exited with errors" --data {
                    script: $script
                    args: ($args | str join ' ')
                }
            }
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
            } catch {
                throw "command exited with errors" --data {
                    command: ($args | str join ' ')
                    tempfile: $tmp
                }
            } finally {
                rm --force $tmp
            }
        }
    }

    # Run a command or closure in an elevated Nushell session.
    #
    @category shells
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
        } catch {
            throw "command completed with errors" --data {
                command: (metadata $closure)
                input: (metadata $input)
            }
        }
    }
}

overlay use elevate
