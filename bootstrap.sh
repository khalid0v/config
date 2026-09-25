#!/usr/bin/env bash
#
# bootstrap.sh -- provision a fish-like zsh setup on Debian/Ubuntu/Zorin.
#
# Installs packages, oh-my-zsh and its plugins, a Nerd Font, and the config
# files in home/ (which become ~/.zshrc and ~/.config/starship.toml).
#
# Every step is idempotent: running it twice is a no-op, and any file it
# overwrites is backed up to <file>.bak-<timestamp> first.
#
# Usage: ./bootstrap.sh [options]
#   --dry-run         print what would happen, change nothing
#   --skip-font       don't install the Nerd Font or set the terminal font
#   --skip-chsh       don't change the default login shell
#   --skip-verify     don't run the post-install smoke tests
#   --with-node       also install fnm (node version manager)
#   --uninstall       remove the config files this repo owns
#   -h, --help        show this help
#
set -Eeuo pipefail

# ------------------------------------------------------------------ settings

NERD_FONT_REPO="ryanoasis/nerd-fonts"
NERD_FONT_ASSET="0xProto.zip"
NERD_FONT_VERSION="${NERD_FONT_VERSION:-}"   # empty = latest release
TERMINAL_FONT_NAME="0xProto Nerd Font Mono"
TERMINAL_FONT_SIZE=12

OMZ_DIR="$HOME/.oh-my-zsh"
FZFTAB_DIR="$OMZ_DIR/custom/plugins/fzf-tab"
ZCOMPL_DIR="$HOME/.local/share/zsh-completions"
FONTS_DIR="$HOME/.local/share/fonts"

PKGS=(zsh zsh-common fzf zoxide eza git curl unzip xz-utils)

DRY_RUN=0
SKIP_FONT=0
SKIP_CHSH=0
SKIP_VERIFY=0
WITH_NODE=0
UNINSTALL=0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_HOME="$SCRIPT_DIR/home"

# ------------------------------------------------------------------ helpers

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_B=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_BLU=$'\033[34m'
else
  C_RESET=""; C_B=""; C_DIM=""; C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""
fi

step()  { printf '%s==>%s %s%s%s\n' "$C_BLU" "$C_RESET" "$C_B" "$*" "$C_RESET"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    %s✓%s %s\n' "$C_GRN" "$C_RESET" "$*"; }
skip()  { printf '    %s•%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
warn()  { printf '    %s!%s %s\n' "$C_YEL" "$C_RESET" "$*" >&2; }
die()   { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

run() {
  if (( DRY_RUN )); then
    printf '    %s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

# Back up a file before overwriting it. No-op if it does not exist.
backup() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  local dest
  dest="$f.bak-$(date +%Y%m%d-%H%M%S)"
  run cp -a "$f" "$dest" || return 0
  ok "backed up $f -> $(basename "$dest")"
}

# ---------------------------------------------------------------- arg parse

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=1 ;;
    --skip-font)   SKIP_FONT=1 ;;
    --skip-chsh)   SKIP_CHSH=1 ;;
    --skip-verify) SKIP_VERIFY=1 ;;
    --with-node)   WITH_NODE=1 ;;
    --uninstall)   UNINSTALL=1 ;;
    -h|--help)     sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)             die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

trap 'printf "\n%serror:%s %s failed at line %s\n" "$C_RED" "$C_RESET" "${BASH_SOURCE[0]}" "$LINENO" >&2' ERR

# ----------------------------------------------------------------- preflight

step "Preflight"

# shellcheck disable=SC1091
[[ -r /etc/os-release ]] || die "cannot read /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID_LIKE:-}" != *debian* && "${ID:-}" != *debian* ]]; then
  die "${PRETTY_NAME:-unknown} is not Debian-family; this script targets Ubuntu/Zorin/Debian"
fi
ok "${PRETTY_NAME:-debian} (${VERSION_ID:-?})"

[[ -d "$SRC_HOME" ]] || die "missing $SRC_HOME -- run this from inside the config repo"
have git || die "git is required"
ok "git $(git --version | awk '{print $3}')"

if (( DRY_RUN )); then
  skip "dry run: no changes will be made"
else
  sudo -v || die "sudo is required to install packages"
  ok "sudo authenticated"
fi

# ----------------------------------------------------------------- uninstall

if (( UNINSTALL )); then
  step "Uninstall"
  backup "$HOME/.zshrc"
  backup "$HOME/.config/starship.toml"
  run rm -f "$HOME/.zshrc" "$HOME/.config/starship.toml"
  ok "removed config files (backups kept, repos and packages left alone)"
  exit 0
fi

# ------------------------------------------------------------------ packages

step "Packages"
if (( DRY_RUN )); then
  info "apt-get install -y ${PKGS[*]}"
else
  missing=()
  for p in "${PKGS[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "ok installed" || missing+=("$p")
  done
  if (( ${#missing[@]} )); then
    info "installing: ${missing[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${missing[@]}"
    ok "installed ${#missing[@]} package(s)"
  else
    skip "all ${#PKGS[@]} packages already present"
  fi
  if (( WITH_NODE )) && ! have fnm; then
    info "installing fnm"
    curl -fsSL https://fnm.vercel.app/install | bash
    ok "fnm installed"
  fi
fi

# --------------------------------------------------------------- oh-my-zsh

step "oh-my-zsh"
if [[ -d "$OMZ_DIR/.git" ]]; then
  skip "already installed at $OMZ_DIR (left untouched; update it yourself if wanted)"
else
  run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
  ok "cloned to $OMZ_DIR"
fi

# ----------------------------------------------------------------- plugins

step "Plugins"

clone_or_pull() {
  local url="$1" dir="$2" name="$3"
  if [[ -d "$dir/.git" ]]; then
    skip "$name already present"
  else
    mkdir -p "$(dirname "$dir")"
    run git clone --depth 1 "$url" "$dir"
    ok "$name -> $dir"
  fi
}

# fzf-tab must be the last plugin to bind ^I, hence the omz custom dir.
clone_or_pull https://github.com/Aloxaf/fzf-tab "$FZFTAB_DIR" "fzf-tab"
clone_or_pull https://github.com/zsh-users/zsh-completions "$ZCOMPL_DIR" "zsh-completions"

# --------------------------------------------------------------- nerd font

step "Nerd Font"
if (( SKIP_FONT )); then
  skip "skipped (--skip-font)"
else
  if [[ -d "$FONTS_DIR" ]] && compgen -G "$FONTS_DIR/*NerdFontMono*.ttf" >/dev/null; then
    skip "Nerd Font already installed"
  else
    if (( DRY_RUN )); then
      info "would download and install $NERD_FONT_ASSET from $NERD_FONT_REPO"
    else
      have unzip || die "unzip is required to unpack the font"
      tag="$NERD_FONT_VERSION"
      if [[ -z "$tag" ]]; then
        tag="$(curl -fsSL "https://api.github.com/repos/$NERD_FONT_REPO/releases/latest" \
               | sed -n 's/.*"tag_name" *: *"\([^"]*\)".*/\1/p' | head -1)"
        [[ -n "$tag" ]] || die "could not determine the latest $NERD_FONT_REPO release"
      fi
      url="https://github.com/$NERD_FONT_REPO/releases/download/$tag/$NERD_FONT_ASSET"
      tmp="$(mktemp -d)"
      info "downloading $NERD_FONT_ASSET ($tag)"
      curl -fsSL "$url" -o "$tmp/font.zip"
      # Only the Mono variant: a terminal needs a fixed advance width.
      unzip -qo "$tmp/font.zip" -d "$tmp/x" 'NerdFontMono/*.ttf' 2>/dev/null \
        || unzip -qo "$tmp/font.zip" -d "$tmp/x"
      mkdir -p "$FONTS_DIR"
      find "$tmp/x" -name '*NerdFontMono*.ttf' -exec cp -f {} "$FONTS_DIR/" \;
      rm -rf "$tmp"
      ok "installed Nerd Font Mono to $FONTS_DIR"
    fi
  fi
  # The TTF files are also needed before fontconfig will report the family.
  have fc-cache && run fc-cache -f "$FONTS_DIR" && ok "font cache rebuilt"
fi

# ----------------------------------------------------------- config files

step "Config files"
backup "$HOME/.zshrc"
backup "$HOME/.config/starship.toml"

run install -Dm644 "$SRC_HOME/.zshrc"      "$HOME/.zshrc"
run install -Dm644 "$SRC_HOME/starship.toml" "$HOME/.config/starship.toml"
ok "installed ~/.zshrc and ~/.config/starship.toml"

# ------------------------------------------------------------ terminal font

if (( SKIP_FONT )); then
  :
else
  step "Terminal font"
  if have gsettings && [[ -d /usr/share/glib-2.0/schemas ]]; then
    # Never hardcode a profile UUID: it differs per machine.
    raw_uuid="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null || true)"
    uuid="${raw_uuid//\"/}"
    uuid="${uuid//\'/}"
    if [[ -z "$uuid" ]]; then
      skip "no default GNOME Terminal profile found; set the font by hand"
    else
      prof="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$uuid/"
      current="$(gsettings get "$prof" font 2>/dev/null || true)"
      if [[ "$current" == *"$TERMINAL_FONT_NAME"* ]]; then
        # Already a Nerd Font: keep whatever size the user chose.
        skip "already set to $current"
      elif (( DRY_RUN )); then
        info "would set $current -> $TERMINAL_FONT_NAME $TERMINAL_FONT_SIZE"
      else
        gsettings set "$prof" font "$TERMINAL_FONT_NAME $TERMINAL_FONT_SIZE"
        ok "set $current -> $TERMINAL_FONT_NAME $TERMINAL_FONT_SIZE"
        warn "open a NEW terminal window -- running ones keep the old font"
      fi
    fi
  else
    skip "gsettings or GNOME Terminal not present; set the font by hand"
  fi
fi

# --------------------------------------------------------------------- chsh

step "Default shell"
if (( SKIP_CHSH )); then
  skip "skipped (--skip-chsh)"
elif ! have zsh; then
  warn "zsh not installed; cannot set default shell"
else
  target="$(command -v zsh)"
  current="$(getent passwd "$(id -u)" | cut -d: -f7)"
  if [[ "$current" == "$target" ]]; then
    skip "already $target"
  elif (( DRY_RUN )); then
    info "would chsh to $target"
  else
    sudo chsh -s "$target" "$(id -un)" && ok "default shell set to $target"
  fi
fi

# ------------------------------------------------------------------ verify

if (( SKIP_VERIFY )); then
  step "Verify"; skip "skipped (--skip-verify)"; exit 0
fi

step "Verify"
if ! have zsh; then
  warn "zsh missing; cannot verify"; exit 0
fi

check() { # check <label> <zsh-expression>
  local label="$1" expr="$2" out
  if out="$(zsh -i -c "$expr" 2>/dev/null)"; then
    ok "$label: $out"
  else
    warn "$label: FAILED"
  fi
}

check "startup errors"  'zsh -i -c exit 2>&1 | grep -c . || true'
check "autosuggestions"  'print ${+functions[_zsh_autosuggest_start]}'
check "syntax highlight" 'print ${ZSH_HIGHLIGHT_HIGHLIGHTERS[1]:-none}'
check "fzf-tab (Tab)"    'bindkey "^I"'
check "zoxide (z)"       'whence -w z'
check "eza"              'eza --version 2>&1 | head -1'
check "starship"         'starship --version 2>&1 | head -1'
check "node"             'node --version 2>/dev/null || echo "not installed"'

printf '\n%sDone.%s Open a NEW terminal window, then run: exec zsh\n' "$C_GRN$C_B" "$C_RESET"
