module watch {
    const DOT: string = $"(ansi attr_blink_fast)(ansi g)●(ansi rst)"
    const KEYBINDS: list<string> = [
        $"(ansi light_gray) q or ctrl+c to quit(ansi rst)"
        $"(ansi light_gray) o to toggle overlay(ansi rst)"
    ]
    const PROMPT: string = $"\n(ansi attr_dimmed)└──(ansi rst) (ansi violet)$(ansi rst)"
    const ESC: record = {
        home: (ansi --escape H)
        el: (ansi --escape K)
        cnorm: (ansi --escape ?25h)
        civis: (ansi --escape ?25l)
        smcup: (ansi --escape ?1049h)
        rmcup: (ansi --escape ?1049l)
        wrap: (ansi --escape ?7h)
        nowrap: (ansi --escape ?7l)
        clear: (ansi --escape 2J)
    }
    const DASH: string = "─"
    # Run an auto-updating command in a target directory.
    #
    # The dimensions of the console will be passed as the sole argument
    # to both the primary closure, as well as any custom keybind closures,
    # as a `record<height: int width: int>`.
    #
    # Additionally, to control loop behavior from keybinding closures you
    # can return `true` to break (must be explicit literal, not just truthy).
    # For cases where more than one keybind matches the provided input, if any
    # value is exactly `true`, the loop will be broken after all remaining
    # matching closures are executed.
    #
    export def monitor [ # nu-lint-ignore: max_function_body_length

        --cwd (-d): path
        --repr(-r): string # Override the command serialization header value
        --wait(-w): duration # The refresh interval as a duration; used as `input listen` timeout duration
        --hide(-h) # Hide the header by default (can be toggled back on)
        --suppress(-s) # Suppress errors; prints them to stderr but loop continues

        --keybinds(-k): table<code: string, modifiers: list<string>, handler: closure, text: string>  # Additional keybinds and closures for granular behavior control
    ]: closure -> nothing {
        let c: closure = $in
        let t: duration = $wait | default 2sec
        let s: string = $repr | default (
            try { $c | to nuon --serialize --raw-strings | parse "{_} {value} }{_}" | get 0.value } catch { $c | to text }
        ) | str trim

        def "window size" []: nothing -> record<height: int, width: int> {
            {
                height: (tput lines | into int)
                width: (tput cols | into int)
            }
        }

        let custom: list<string> = $keybinds
        | default []
        | par-each --keep-order { $" (ansi blue)($in.text | str trim --left)(ansi rst)" }
        | compact --empty

        let n: int = if ($custom | is-empty) { 1 } else { 2 }

        with-env {
            show: (not $hide)
            pwd: ($cwd | default $env.pwd | path expand)
            ...(window size)
        } {
            def "ansi csr" [bottom: int]: nothing -> string { ansi --escape $"1;($bottom)r" }
            def "ansi cup" [row: int col: int = 0]: nothing -> string { ansi --escape $"($row + 1);($col + 1)H" }

            print --no-newline $"($ESC.smcup)($ESC.nowrap)"

            def --env "monitor iter" []: nothing -> nothing {
                    let viewport = window size
                    let lines: list<string> = if $env.show {
                        $"($DOT) (date now) ($PROMPT) ($s | nu-highlight)" | lines | append ""
                    } else { [] }
                    load-env {
                        render: ($viewport.height - $n - ($lines | length) - 1)
                        lines: $lines
                        csr: (ansi csr ($viewport.height - ($n + 1)))
                        ...$viewport
                    }
            }

            alias measurements = do { $env | select height width }

            def "monitor exec" []: nothing -> string {
                let viewport: record<height: int width: int> = measurements
                let body: list<string> = if not $suppress { do --env $c $viewport } else {
                    try { do $c $viewport } catch {|err| $"(ansi r)($err.msg)(ansi rst)" }
                } | lines | first ($env.render? | default $viewport.height)
                let count: int = $env.render - ($body | length)
                let padded = if $count <= 0 { $body } else { $body | append (1..$count | each { "" }) }
                $env.lines | append $padded | each { $"($in)($ESC.el)" } | str join "\n"
            }

            def "monitor ctrl" []: nothing -> string {
                let viewport: record<height: int width: int> = measurements
                let dot: string = $" (ansi dark_gray)·(ansi rst)"
                let dw: int = $dot | ansi strip | str length

                def fit [width?: int]: list<string> -> string {
                    let entries: list<string> = $in
                    let len: int = $entries | length
                    let vw: int = $width | default $viewport.width
                    let total = $entries | each { $in | ansi strip | str length } | math sum
                    let jw: int = $total + ($dw * (($entries | length) - 1))
                    if $jw <= $vw { return ($entries | str join $dot) }

                    # Implementations for collecting the maximum keybinding
                    # texts that can be displayed before truncation:
                    #
                    # `truncate` - immutable-only w/ nested pipe (zaynram)
                    # `fallback`- mutables w/ for-loop (claude-opus-4.7)

                    def truncate []: nothing -> string {
                        $entries
                        | par-each --keep-order { ansi strip | str length }
                        | do {|ls: list<int>| [0..($len - 1)]
                            | skip while {|i| $ls
                                | slice 0..$i
                                | do {|add: int| math sum
                                    | $in + $add
                                } ($in | length | $in * $dw)
                                | $in <= $vw - 1
                            } | first
                            | do {|rg: range| $entries
                                | slice $rg
                                | str join $dot
                            } 0..($in - 1)
                        } $in
                        | $"($in)(ansi dark_gray)…(ansi rst)"
                    }

                    def fallback []: nothing -> string {
                        mut acc: list<string> = []
                        mut w: int = 0
                        for e in $entries {
                            let ew: int = $e | ansi strip | str length
                            if ($acc | is-empty) { $ew } else { $w + $dw + $ew }
                            | if $in > ($vw - 1) { break } else { $acc ++= [$e]; $w = $in }
                        }
                        $"($acc | str join $dot)(ansi dark_gray)…(ansi rst)"
                    }

                    try { truncate } catch { fallback }
                }

                let r1 = $"(ansi cup ($viewport.height - $n))($ESC.el)($KEYBINDS | fit)"
                if ($custom | is-empty) { return $r1 }
                let r2 = $"(ansi cup ($viewport.height - 1))($ESC.el)($custom | fit)"
                return ($r1 + $r2)
            }

            def --env "monitor keys" []: nothing -> bool { # nu-lint-ignore: print_and_return_data
                let viewport: record<height: int width: int> = measurements
                match (try { input listen --timeout $t --types [key] }) {
                    $x if $x == null or $x.code? == null => { return false }
                    {code: q modifiers: []} => { return true }
                    {code: c modifiers: ['keymodifiers(control)']} => { return true }
                    {code: o modifiers: []} => {
                        $env.show = not $env.show
                        return false
                    }
                    {code: $c modifiers: $m} => {
                        let queue: list = $keybinds | where code == $c and modifiers == $m | get handler
                        if ($queue | is-empty) { return false }
                        print --no-newline $"(ansi csr ($viewport.height - 1))($ESC.cnorm)($ESC.wrap)($ESC.clear)"
                        let value: bool = $queue | each { do $in $viewport } | any {}
                        print --no-newline $"($ESC.nowrap)($ESC.civis)"
                        return $value
                    }
                    _ => { return false }
                }
            }

            alias "monitor done" = print --no-newline $"(ansi csr ($env.height - 1))($ESC.cnorm)($ESC.wrap)($ESC.rmcup)"

            try {
                loop {
                    monitor iter
                    print --no-newline $"($env.csr)($ESC.civis)($ESC.home)(monitor exec)(if $env.show { monitor ctrl } else { clear })"
                    if (monitor keys) { break }
                }
            } catch {|err|
                monitor done
                error make --unspanned {
                    msg: "monitor exited with errors",
                    inner: [$err]
                    label: {text: closure span: (metadata $c).span}
                }
            }
            monitor done
        }
    }

    const GSKEEP: list<string> = [
        ignored
        conflicts
        ahead
        behind
        stashes
        repo_name
        branch
        remote
        state
    ]
    # Spawn a git status watcher for the target repository.
    #
    @category source-control
    export def --wrapped "git watch" [ # nu-lint-ignore: max_function_body_length
        ...rest: string # Arguments for the git status invocation; overrides defaults
        --cwd(-c): path # Path to the repository to spawn the process in (defaults to `$env.pwd`)
        --no-tag(-n) # Omit the `tag` value from the `gstat` record
        --interval(-i): duration # Duration to wait between each iteration
    ]: nothing -> nothing {
        let args: list<string> = if ($rest | is-not-empty) { $rest } else { [-s -unormal --renames] }
        let repr: string = $'git status ($args | str join " ")'
        let keep: list<string> = $GSKEEP | append (if not $no_tag { [tag] }) | compact
        let main: closure = {|view: record|
            gstat
            | select ...$keep
            | items {|_ v|
                try { $v | into int | if $in > 0 { error make } } catch { [$_ $v] }
            }
            | into record
            | merge {files: (await { git status ...$args } | nu-highlight)}
            | compact --empty
            | table --width $view.width --theme frameless
        }

        def "input dismiss" [prompt?: string]: nothing -> nothing {
            print ($prompt | default "press any key to dismiss")
            input listen --types [key] | ignore
        }

        $main | monitor --wait $interval --cwd ($cwd | default (pwd)) --repr $repr --keybinds [
            {
                code: c
                modifiers: []
                handler: {||
                    let options: list<string> = [staged tracked all]
                    | par-each --keep-order { $"(ansi g)($in)(ansi rst)" }
                    | append $"(ansi r)none(ansi rst)"
                    let raw: string = $options | input list "select changes to commit" | default none
                    let extra: list<string> = match ($raw | ansi strip) {
                        none => {
                            print --stderr "commit aborted"
                            return
                        }
                        all => {
                            git add --all | ignore
                        }
                        tracked => [--all]
                    } | default []
                    print --no-newline $"(ansi dark_gray)enter commit message: (ansi rst)"
                    await { git commit ...($extra) --message (input) } --check --print
                    input dismiss
                }
                text: 'c to commit'
            }
            {
                code: p
                modifiers: []
                handler: {||
                    let options: list<string> = [$'(ansi g)yes(ansi rst)' $'(ansi r)no(ansi rst)']
                    let raw: string = $options | input list "push changes to remote?" | default no
                    match ($raw | ansi strip) {
                        yes => {
                            await { git push } --check --print
                            input dismiss
                        }
                        _ => {
                            print --stderr "push aborted"
                            return
                        }
                    }
                }
                text: 'p to push'
            }
        ]
    }
}

overlay use watch
