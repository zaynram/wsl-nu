# ——— config.nu ———————————————————————————————————————————————————————————————
# manager = cargo
# version = "0.111.0"
# docs = { cli: "config nu --doc | nu-highlight | less -R",
#          web: "https://www.nushell.sh/book/configuration.html" }

# ——— constants ———————————————————————————————————————————————————————————————
const NU_LIB_DIRS = [
    ($nu.data-dir | path join modules)
]

const NU_PLUGIN_DIRS = [
    ($nu.current-exe | path dirname)
    ($nu.data-dir | path join "plugins" | path join (version).version)
    ($nu.config-path | path dirname | path join "plugins")
]

# ——— imports——————————————————————————————————————————————————————————————————
use std/util "path add"

# ——— environment —————————————————————————————————————————————————————————————
load-env {
    visual: (which code-insiders | get path | get --optional 0 | default code)
    editor: (which hx | get path | get --optional 0 | default nano)
    ...([pnpm nupm] | par-each {|el|
        {$'($el)_home': ($nu.data-dir | path dirname | path join $el)}
    } | into record)
}

$env.nu_lib_dirs ++= [
    ($env.nupm_home | path join modules)
]

path add {linux: /home/linuxbrew/.linuxbrew/bin}
path add [
    ($env.pnpm_home)
    ($env.nupm_home | path join scripts)
    ...([.local .pixi .bun .cargo go] | par-each {|el|
        $nu.home-dir | path join $el bin
    })
]
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
            cmd: ([
                $nu.env-path
                $nu.config-path
                ...(try { ls ...$nu.user-autoload-dirs | get name } catch { [] })
            ] | par-each { $'source `($in)`' } | str join '; ')
        }
    }
]
# ——— activation ——————————————————————————————————————————————————————————————
overlay use custom.nu

# ——— main ————————————————————————————————————————————————————————————————————
def --env main []: nothing -> nothing {
    $nu.vendor-autoload-dirs
    | where $it =~ $nu.home-dir
    | first
    | let vendor_auto: path

    try {
        if ($vendor_auto | path type) != dir {
            rm --force $vendor_auto
            mkdir --verbose $vendor_auto
        }
        if (command carapace) {
            load-env {CARAPACE_LENIENT: 1 CARAPACE_BRIDGES: fish}
            let script: path = $vendor_auto | path join carapace.nu
            if ($script | stale) { carapace _carapace nushell | save --force $script }
        }
    } catch {
        error make "failed to refresh vendor autoload scripts"
    }
}

# ——— prompt ——————————————————————————————————————————————————————————————————
if (command fortune) {
    fortune | ansi gradient --fgstart '0x40c9ff' --fgend '0xe81cff' | print
}