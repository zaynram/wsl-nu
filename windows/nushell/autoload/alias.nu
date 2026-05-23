module alias {
    export use std/clip [copy paste]
    # Replace the current shell instance with a fresh one.
    export alias reload = do { clear --keep-scrollback; exec nu }
    # Check if command(s) are available on PATH.
    #
    # Note that `all` is used for the test so if more than one
    # name is provided then any missing command will return false.
    export alias "on path" = do {|name?: string| append $name
        | compact --empty
        | all { which $in | is-not-empty }
    }
}

overlay use alias
