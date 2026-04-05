export def "plugin install" [name: string, --owner(-o): string]: nothing -> nothing {
    match $owner {
        null => { cargo install $name }
        _ => {
            let url = ["https://github.com" $owner $name] | str join '/'
            cargo install --git ($url + .git)
        }
    }
    plugin add $name
    print $"installed ($name)"
}
