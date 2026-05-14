module extensions {
    # Create an error label from a record mapping label text to metadata.
    #
    # Pipeline input must contain a record with string keys and values containing a span key.
    @category conversions
    export def "into labels" []: record -> list<record<text: string, span: record>> {
        items {|k v| {text: $k span: ($v.span? | default {})} }
    }
    # Alternative error constructor with some convenience enhancments.
    #
    @category core
    export def throw [
        ...words: string, # Text description or information about the error
        --code(-c): oneof<int, string> = `ext::throw::unknown_error`, # The code to use for the error; will be set to 1 if it evaluates to nothing at runtime
        --data(-d): record = {} # Mapping of `text` keys to `metadata` values (i.e. {descriptor: (metadata some_arg)})
        --labels(-l): list<record<text: string span: record>> = [] # Pre-formatted labels mapping values to text labels and metadata spans
        --inner(-i): error # An inner error to propogate through the chain; if omitted error info will originate from this function
    ]: oneof<error any> -> error {
        let struct: record = {
            msg: $"($words | str join ` `)"
            labels: [
                ...$labels
                ...($data | into labels)
            ]
            code: $"($code | default 1)"
            inner: ([$in $inner] | compact)
        }
        match $struct {
            {inner: []} => { error make $struct }
            _ => { error make --unspanned $struct }
        }
    }
    # Wait for the external command to complete and return its output.
    #
    # By default, `stderr` will be returned for non-zero exit codes and
    # `stdout` will be returned otherwise.
    #
    # The `--status` flag will override and disable `--print`.
    # The `--check` flag will cause errors to be thrown regardless of `--print`.
    @category system
    export def --env await [
        closure?: closure # The closure to execute and complete.
        ...rest: string # Arguments to pass to the closure
        --status(-s) # Return `false` for non-zero exit codes; `true` otherwise.
        --check(-c) # Whether to capture errors when running the closure
        --print(-p) # Print standard output or error (non-zero exit codes)
    ]: oneof<nothing any> -> oneof<string bool nothing> {
        let res: record = if $check {
            try {
                $in | do --capture-errors $closure ...$rest
            } catch {
                throw command exited with errors --code await+check::captured_error
            }
        } else {
            $in | do --ignore-errors $closure ...$rest
        } | complete
        let out: string = $res.stdout? | default "" | str trim
        let err: string = $res.stderr? | default "command failed" | str trim
        match $res.exit_code {
            0 if $status => { return true }
            _ if $status => { return false }
            0 if $print => { print $out }
            _ if $print => {
                load-env {last_exit_code: $res.exit_code}
                print --stderr $err
            }
            0 => { return $out }
            _ => { return $err }
        } | ignore
    }
}

overlay use extensions
