module multiplexer {
    # Attach or create a zellij session for a known project.
    #
    # Known projects are resolved by matching the session name to a directory name under ~/code.
    # To override the session name or working directory, use the --directory/-d flag.
    #
    @category shells
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
            throw "failed to attach (or create) session" --data {
                session: (metadata $session)
            }
        }
    }

    # Detach from a zellij session using the session's name.
    #
    @category shells
    export def detach [
        session?: string # The name of the session to detach from
    ]: nothing -> nothing {
        zellij ...(
            if $session != null { [--session $session] } else { [] }
        ) action detach
    }
    # Run a command in a new zellij pane.
    export alias zr = zellij run
    # Attach to a zellij session.
    export alias za = zellij attach
    # Switch to the next swap layout in a zellij session.
    export alias zs = zellij action next-swap-layout
}

overlay use multiplexer
