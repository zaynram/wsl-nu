# lsp-inventory.nu
# Run from anywhere: nu lsp-inventory.nu

def main [] {
    # --- candidate binary names and their helix role ---
    let candidates = [
        [name, role, language];
        ["rust-analyzer",           "lsp",       "rust"]
        ["pyright-langserver",      "lsp",       "python"]
        ["pyright",                 "lsp-alt",   "python"]
        ["ruff",                    "lsp+fmt",   "python"]
        ["typescript-language-server", "lsp",    "js/ts"]
        ["oxlint",                  "lsp",       "js/ts"]
        ["prettier",                "formatter", "js/ts/html/css/json"]
        ["vscode-css-language-server",  "lsp",   "css"]
        ["vscode-html-language-server", "lsp",   "html"]
        ["vscode-json-language-server", "lsp",   "json"]
        ["yaml-language-server",    "lsp",       "yaml"]
        ["marksman",                "lsp",       "markdown"]
        ["bash-language-server",    "lsp",       "bash"]
        ["tombi",                   "lsp+fmt",   "toml"]
        ["nufmt",                   "formatter", "nu"]
    ]

    let home = $env.HOME? | default ($env.USERPROFILE? | default "~") | path expand

    # --- search roots ---
    let roots = [
        ($home | path join ".local" "bin")
        ($home | path join ".pixi" "bin")
        ($home | path join ".bun" "bin")
        ($home | path join ".cargo" "bin")
    ]

    let all_roots = (
        $roots
        | append (
            try {
                let toolchain = (rustup show active-toolchain | split row ' ' | first)
                let rustup_home = ($env.RUSTUP_HOME? | default ($home | path join ".rustup"))
                $rustup_home | path join toolchains $toolchain bin
            } catch { "" }
        )
        | append ($env.PATH | split row (char esep))
        | where { |p| $p != "" and ($p | path exists) }
        | uniq
    )

    # --- resolve each candidate ---
    $candidates | each { |c|
        let found = (
            $all_roots | par-each { |root|
                let full = ($root | path join $c.name)
                if ($full | path exists) { $full } else { null }
            }
            | compact
            | first 1
        )

        let resolved = if ($found | length) > 0 { $found | first } else { null }

        {
            binary:   $c.name
            role:     $c.role
            language: $c.language
            found:    ($resolved != null)
            path:     ($resolved | default (which $c.name).0?.path | default "not found")
        }
    }
    | sort-by language
}