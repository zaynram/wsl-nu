module windows {
    # Change to the windows user's desktop directory
    @category filesystem
    def desktop [...rest: path]: nothing -> nothing {
        let desktop: path = $env.userprofile | path join desktop ...$rest
        if ($desktop | path type) != dir {
            error make {
                msg: "target path is not a valid directory"
                label: {
                    text: path
                    span: (metadata $desktop).span
                }
            }
        }
    }
    # Construct a windows path from the input path
    @category filesystem
    def --env "win path" [
        ...segments: oneof<string path>
        --user(-u) # Construct the path relative to the Windows user user
        --drive(-d): string = c # The windows drive to use as the path root
        --cd(-c) # Set the working directory to the windows path
    ]: oneof<path nothing> -> oneof<path nothing> {
        let p: path = (
            $in
            | prepend (if $user { $env.userprofile } | default $'/mnt/($drive)')
            | compact --empty
            | path join ...$segments
        )
        if not $cd { return $p } else { cd $p }
    }
}

load-env {userprofile: (wslpath (try { pwsh.exe -nop -noni -c `$env:USERPROFILE` }))}
overlay use windows
