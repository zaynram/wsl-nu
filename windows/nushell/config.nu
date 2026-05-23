# ——— config.nu ———————————————————————————————————————————————————————————————
# manager = cargo
# version = "0.112.1"
# docs = { cli: "config nu --doc | nu-highlight | less -R",
#          web: "https://www.nushell.sh/book/configuration.html" }

# ——— constants ———————————————————————————————————————————————————————————————
const NU_LIB_DIRS = [
    ($nu.data-dir | path join modules)
    ($nu.data-dir | path join scripts)
]

const NU_PLUGIN_DIRS = [
    ($nu.current-exe | path dirname)
    ($nu.data-dir | path join plugins | path join (version).version)
    ($nu.config-path | path dirname | path join plugins)
]

for d in ($NU_LIB_DIRS ++ $NU_PLUGIN_DIRS | where not ($it | path exists)) { mkdir $d }

# ——— imports——————————————————————————————————————————————————————————————————
use std/util "path add"

# ——— environment —————————————————————————————————————————————————————————————
load-env {
    visual: (which code-insiders | get --optional 0.path | default code)
    editor: helix.bat
    ...([pnpm nupm] | par-each {|el|
        {($el)_home: ($nu.data-dir | path dirname | path join $el)}
    } | into record)
}

$env.nu_lib_dirs ++= [
    ($env.nupm_home | path join modules)
]

path add [
    ($env.pnpm_home)
    ($env.nupm_home | path join scripts)
    ...(
        [.local .pixi .bun .cargo go]
        | par-each { prepend $nu.home-dir | path join bin }
        | where $"($it | path type)" =~ `dir|symlink`
    )
]
$env.path = ($env.path | split row (char esep) | uniq)

# ——— configuration ———————————————————————————————————————————————————————————
$env.config.buffer_editor = $env.editor
$env.config.edit_mode = "emacs"
$env.config.show_banner = false
$env.config.keybindings ++= [
    {
        name: reload_config
        modifier: none
        keycode: f5
        mode: [emacs vi_normal vi_insert]
        event: {
            send: executehostcommand
            cmd: ([
                ...(try { ls $nu.user-autoload-dirs | get name } | default [])
                $nu.env-path
                $nu.config-path
            ] | par-each --keep-order { $'source `($in)`' } | str join '; ')
        }
    }
]
# ——— activation ——————————————————————————————————————————————————————————————
overlay use custom.nu

try {
    load-env {CARAPACE_LENIENT: 1 CARAPACE_BRIDGES: fish}
    carapace _carapace nushell | save --force (autoload path carapace.nu)
} catch {
    error make "carapace initialization failed"
} finally {
    wsl.exe --exec /usr/games/fortune
    | ansi gradient --fgstart 0x40c9ff --fgend 0xe81cff
    | print
}
