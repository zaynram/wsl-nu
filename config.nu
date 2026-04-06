# ——— config.nu ———————————————————————————————————————————————————————————————
# manager = homebrew
# version = "0.111.0"
# docs = { cli: "config nu --doc | nu-highlight | less -R",
#          web: "https://www.nushell.sh/book/configuration.html" }

# ——— constants ———————————————————————————————————————————————————————————————
const DATA = $nu.data-dir | path dirname
const NU_PLUGIN_DIRS = [
    ($nu.current-exe | path dirname)
    ($nu.data-dir | path join "plugins" | path join (version).version)
    ($nu.config-path | path dirname | path join "plugins")
]

# ——— immutables ——————————————————————————————————————————————————————————————

# ——— imports——————————————————————————————————————————————————————————————————
use std/util "path add"

# ——— environment —————————————————————————————————————————————————————————————
$env.VISUAL = (try { which code-insiders | get path | get 0 })
$env.EDITOR = (try { which hx | get path | get 0 } | default nano)

$env.NUPM_HOME = [$DATA nupm] | path join
path add ([$env.NUPM_HOME scripts] | path join)
$env.PNPM_HOME = [$DATA pnpm] | path join
path add $env.PNPM_HOME

$env.NU_LIB_DIRS ++= [
    ([$env.NUPM_HOME modules] | path join)
    ([$nu.home-dir code nu lib] | path join)
]

[.pixi .bun .cargo]
| par-each { [$nu.home-dir $in bin] | path join }
| append "/home/linuxbrew/.linuxbrew/bin"
| where ($it | path exists)
| par-each { path add $in }

$env.path = ($env.path | split row (char esep) | uniq)

# ——— configuration ———————————————————————————————————————————————————————————
$env.config.buffer_editor = $env.EDITOR
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
try { print $"(ansi cyan)(fortune)(ansi reset)" }
