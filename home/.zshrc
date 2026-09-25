# ~/.zshrc -- generated from khalid0v/config (home/.zshrc)
# Re-apply with: ~/Github/config/bootstrap.sh
# Edit the repo copy, not this file, or the next bootstrap will overwrite it.

# ---------------------------------------------------------------- oh-my-zsh

export ZSH="$HOME/.oh-my-zsh"

# The prompt is starship (below), so oh-my-zsh must not load a theme.
ZSH_THEME=""

# Load order matters:
#   zsh-syntax-highlighting  must come before history-substring-search
#   fzf-tab                 must come before zsh-autosuggestions
#   zsh-autosuggestions     must be last (it wraps the accept-line widgets)
plugins=(
  zsh-syntax-highlighting
  history-substring-search
  extract
  copypath
  sudo
  git
  fzf-tab
  zsh-autosuggestions
)

# zsh-completions: extra completions for many commands. Must be prepended to
# fpath BEFORE oh-my-zsh calls compinit.
fpath=("$HOME/.local/share/zsh-completions/src" $fpath)

source "$ZSH/oh-my-zsh.sh"

# ------------------------------------------------------------------- prompt

# starship draws the prompt: folder, git branch, language and status icons.
# Must come after the oh-my-zsh source, otherwise omz's theme wins.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# -------------------------------------------------------------------- icons

# eza draws Nerd Font file-type icons. Must be after the oh-my-zsh source:
# omz's lib already defines `l`, `ll` and `la`, so these have to win.
# --icons=always, not bare --icons: Ubuntu's eza build defaults to never and
# emits nothing without an explicit value.
# NOTE: overriding `ls` will break scripts that call it with flags eza lacks.
# Delete the `ls` alias below if that bites.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=always --group-directories-first'
  alias ll='eza -lah --icons=always --group-directories-first --git'
  alias la='eza -A --icons=always --group-directories-first'
  alias lt='eza --tree --icons=always --level=2'
  alias lm='eza --icons=always --group-directories-first --sort=modified'
fi

# ------------------------------------------------------- smart directories

# zoxide: smart directory jumping (`z foo`). Uses zoxide's own init rather than
# the oh-my-zsh plugin, which conflicts with it.
# _ZO_FZF_OPTS gives the `z` picker a live, iconified preview pane.
if command -v zoxide >/dev/null 2>&1; then
  export _ZO_FZF_OPTS="--preview 'eza --icons=always --color=always --tree --level=1 {}'"
  eval "$(zoxide init zsh)"
fi

# ------------------------------------------------------------- completions

# case-insensitive completion, fish-style
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select

# inline "ghost text" suggestions, dimmed
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# --- fzf-tab: replace the built-in Tab menu with a fuzzy one ---

# group headers, e.g. [files] [directories]
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# must be 'no' or 'select' so fzf-tab can capture the unambiguous prefix
zstyle ':completion:*' menu no
# switch between groups with </> instead of F1/F2
zstyle ':fzf-tab:*' switch-group '<' '>'
# preview directory contents when completing after `cd`.
# --icons=always because the fzf preview pane is not a normal TTY.
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons=always --color=always --group-directories-first $realpath 2>/dev/null | head -20'

# --------------------------------------------------------------- toolchains

# bun
if [[ -d "$HOME/.bun/bin" ]]; then
  export PATH="$HOME/.bun/bin:$PATH"
fi

# fnm (node version manager), auto-switching per .node-version / .nvmrc
if [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
  eval "$("$HOME/.local/share/fnm/fnm" env --shell zsh --use-on-cd)"
fi
