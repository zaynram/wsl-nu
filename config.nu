# ——— config.nu ———————————————————————————————————————————————————————————————
# manager = homebrew
# version = "0.111.0"
# docs = { cli: "config nu --doc | nu-highlight | less -R",
#          web: "https://www.nushell.sh/book/configuration.html" }

# ——— constants ———————————————————————————————————————————————————————————————
const NU_LIB_DIRS = [
    "~/.local/share/nupm/modules"
    "~/code/nu"
]

const NU_PLUGIN_DIRS = [
    ($nu.current-exe | path dirname)
    ($nu.data-dir | path join "plugins" | path join (version).version)
    ($nu.config-path | path dirname | path join "plugins")
]

# ——— imports——————————————————————————————————————————————————————————————————
use std/util "path add"
overlay use ($NU_LIB_DIRS | get 0 | path basename --replace nupm) --prefix

# ——— environment —————————————————————————————————————————————————————————————
$env.PNPM_HOME = "~/.local/share/pnpm"
path add $env.PNPM_HOME

$env.NUPM_HOME = ($NU_LIB_DIRS | get 0)
path add ($env.NUPM_HOME | path join "scripts")

path add /home/linuxbrew/.linuxbrew/bin/
path add ~/.local/bin
path add ~/.pixi/bin
path add ~/.bun/bin

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
const omp_prompt = '~/code/nu/custom.omp.json'
if ($omp_prompt | path exists) { oh-my-posh init nu --config $omp_prompt }
