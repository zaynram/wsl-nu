module configuration {
    const DIR: path = path self .
    const ALIAS_NU: path = path self alias.nu
    # Edit the autoloaded alias definition file
    @category core
    export def "config alias" []: nothing -> nothing { editor $ALIAS_NU }

    const CONFIG_NU: path = path self
    # Edit the autoloaded configuration helper file
    @category core
    export def "config self" []: nothing -> nothing { editor $CONFIG_NU }

    const FILTER_AUTO: string = 'configuration|alias'
    # Interact with a file from an autoload directory.
    #
    # If the `target` argument is omitted, the items in the directory will be listed.
    @category filesystem
    export def "config auto" [
        target?: string # The autoload file to target (can omit `.nu` suffix)
        --vendor(-v) # Use the vendor autoload directory (defaults to user)
    ]: nothing -> oneof<nothing table> {
        let dir: path = if $vendor { $nu.vendor-autoload-dirs? } else { $DIR }
        if $dir == null { error make "could not resolve autoload directory" }
        if $target == null {
            let stems: list = try {
                ls --short-names $dir
                | where name !~ $FILTER_AUTO and type =~ `file|symlink`
                | get name
                | path parse
                | select stem
                | rename name
            } | default [] | uniq | compact --empty
            let items: list = overlay list
            | where name in $stems.name
            | merge $stems
            | default n/a active
            print ($"const path = `($DIR)`" | nu-highlight)
            return $items
        }
        editor ($dir | path join $"($target | str replace .nu '').nu")
    }

    const FILTER_FIND: string = 'nushell|Code - Insiders|google-chrome-for-testing'
    # Edit a non-nushell configuration file.
    #
    # If no `target` is provided, the eligible target candidates are listed instead.
    @category filesystem
    export def "config find" [
        target?: oneof<string path> # The directory name to search for config files under
        --path(-p): path # The path to the config file within the directory
    ]: nothing -> oneof<nothing table> {
        let dir: path = $nu.home-dir | path join .config
        if $target == null {
            let stems: list = try {
                ls --short-names $dir
                | where name !~ $FILTER_FIND and type =~ `dir|symlink`
                | get name
                | path parse
                | select stem
                | rename name
            } | default [] | compact --empty
            print ($"const path = `($dir)`" | nu-highlight)
            return $stems
        }
        let tgt: path = $dir | path join $target
        let qry: glob = $path | default *config* | into glob
        let fp: path = try {
            cd $tgt
            ls $qry | where type == file | first | get name
        }
        if $fp != null { editor $fp } else {
            error make {
                msg: "could not resolve configuration file"
                labels: [
                    {
                        text: target
                        span: (metadata $target).span
                    }
                    {
                        text: path
                        span: (metadata $fp).span
                    }
                ]
            }
        }
    }
}

overlay use configuration
