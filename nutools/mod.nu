export def init-plugin [--owner(-o): string]: string -> string {
    let name = $in
    if $'($owner)' != '' {
        cargo install --git $'https://github.com/($owner)/($name).git'
    } else {
        cargo install $name
    }
    plugin add ("~/.cargo/bin" | path join $name)
    return $'(ansi green)added(ansi reset) ($name)'
}
