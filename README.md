# config

Personal shell setup for Debian-family Linux (tested on Zorin OS 18.1 / Ubuntu 24.04).

A fish-like zsh experience: inline autosuggestions, syntax highlighting, fuzzy
`Tab` completion, smart directory jumping, and a Nerd Font icon prompt.

## Quick start

```bash
git clone git@github.com:khalid0v/config.git ~/Github/config
cd ~/Github/config
./bootstrap.sh
exec zsh
```

Open a **new** terminal window first if the font changes — running windows keep
the old one.

## What it gives you

| Feature | Provided by |
|---|---|
| Dim inline "ghost text" from history (`→` accepts) | `zsh-autosuggestions` |
| Live syntax colours (green strings, red unterminated quotes) | `zsh-syntax-highlighting` |
| Fuzzy `Tab` menu, group headers, `</>` to switch groups, `cd` preview | `fzf-tab` + `fzf` |
| `↑`/`↓` matching a *mid-string* history fragment | `history-substring-search` |
| Case-insensitive completion | `matcher-list` zstyle |
| `z foo` smart directory jump | `zoxide` |
| File-type icons in `ls` | `eza` |
| Icon prompt (folder, git branch, language versions, status) | `starship` |
| Auto-extract archives, `Esc Esc` = `sudo`, copy path | `extract`, `sudo`, `copypath` |

## Requirements

- A Nerd Font in the terminal — the script installs **0xProto Nerd Font Mono**
  and points GNOME Terminal at it.
- `zsh` as the login shell (the script offers to `chsh`).
- Bash is required to run `bootstrap.sh`.

## Script options

| Flag | Effect |
|---|---|
| `--dry-run` | Print what would happen, change nothing |
| `--skip-font` | Don't install the Nerd Font or set the terminal font |
| `--skip-chsh` | Don't change the default login shell |
| `--skip-verify` | Don't run the post-install smoke tests |
| `--with-node` | Also install `fnm` (node version manager) |
| `--uninstall` | Remove the config files this repo owns (repos and packages are left alone) |

Set `NERD_FONT_VERSION` to pin a specific release, e.g. `NERD_FONT_VERSION=v3.5.1 ./bootstrap.sh`.

## Layout

```
bootstrap.sh          provisioning script
home/
  .zshrc              -> installed to ~/.zshrc
  starship.toml       -> installed to ~/.config/starship.toml
```

`home/` is the source of truth. **Edit those, not `~/.zshrc`** — the next
`bootstrap.sh` run overwrites `~/.zshrc` from `home/.zshrc`. Any file it
overwrites is first copied to `<file>.bak-<timestamp>`.

## Idempotency

Every step checks before acting, so re-running is safe and cheap:

- packages are installed only if missing
- oh-my-zsh is cloned only if absent, and never pulled automatically
- plugins are cloned only if absent
- the Nerd Font is downloaded only if no `*NerdFontMono*.ttf` is present
- the terminal font is left alone if it is already a Nerd Font
  (**your chosen size is preserved**)
- `chsh` is skipped if the login shell is already zsh

## Notes and gotchas

- **`eza` needs `--icons=always`.** Ubuntu's build defaults to never and emits
  no glyphs without an explicit value.
- **starship ≥1.26 has no `directory.symbol` key** and no icon by default, so
  the icon is inlined into the module's `format` string in `home/starship.toml`.
- **`ls` is aliased to `eza`.** This will break scripts that call `ls` with
  flags `eza` doesn't support. Delete the `ls` alias in `home/.zshrc` if so.
- **fzf's `Tab` list shows colours, not glyphs.** Icons appear in the *preview*
  pane, via `eza --icons=always`.
- **Apt's `fzf` package ships no shell integration**, so `Ctrl-R` stays as
  plain history search. To get a fuzzy history picker, add fzf's
  `key-bindings.zsh` from its git repo.
- `fzf-tab` must be the last plugin to bind `^I`, and `zsh-autosuggestions`
  must come after it — hence the ordering in `home/.zshrc`.
