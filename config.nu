# ——— config.nu ———————————————————————————————————————————————————————————————
# manager = homebrew
# version = "0.111.0"
# docs = { cli: "config nu --doc | nu-highlight | less -R",
#          web: "https://www.nushell.sh/book/configuration.html" }

let home = ($env.HOME?
    | default ($env.USERPROFILE?
        | default ("~"
            | path expand
)))

# ——— constants ———————————————————————————————————————————————————————————————
const here = path self .
const NU_PLUGIN_DIRS = [
    ($nu.current-exe | path dirname)
    ($nu.data-dir | path join "plugins" | path join (version).version)
    ($nu.config-path | path dirname | path join "plugins")
]

# ——— imports——————————————————————————————————————————————————————————————————
use std/util "path add"

# ——— environment —————————————————————————————————————————————————————————————
$env.VISUAL = (which code-insiders | get path).0?
$env.EDITOR = (which hx | get path).0?
$env.NUPM_HOME = $home | path join .local share nupm
$env.PNPM_HOME = $home | path join .local share pnpm
$env.NU_LIB_DIRS ++= [
    ($env.NUPM_HOME | path join modules)
    ($home | path join code nu)
]
[
    $env.PNPM_HOME
    ($env.NUPM_HOME | path join scripts)
    /home/linuxbrew/.linuxbrew/bin
    ($home | path join .local)
    ...([.pixi .bun .cargo]
        | par-each {|d| $home | path join $d bin }
        | where ($it | path exists))
] | par-each {|p| path add $p }

$env.path = ($env.path | split row (char esep) | uniq)

# ——— configuration ———————————————————————————————————————————————————————————
$env.config.buffer_editor = "hx"
$env.config.show_banner = false
$env.config.keybindings ++= [
    {
        name: reload_config
        modifier: none
        keycode: f5
        mode: [emacs vi_normal vi_insert]
        event: {
            send: executehostcommand
            cmd: $"source '($nu.env-path)'; source '($nu.config-path)'"
        }
    }
]

# ——— activation ——————————————————————————————————————————————————————————————


# ——— prompt ——————————————————————————————————————————————————————————————————
