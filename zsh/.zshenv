# ~/.zshenv: read by every zsh, including scripts, `zsh -c`, editor tasks and git hooks.
# Keep it tiny and fork-free: just enough PATH for non-interactive shells.
# Everything interactive lives in ~/.zshrc (which re-establishes the full PATH).

: ${XDG_CONFIG_HOME:=$HOME/.config} ${XDG_CACHE_HOME:=$HOME/.cache}
: ${XDG_DATA_HOME:=$HOME/.local/share} ${XDG_STATE_HOME:=$HOME/.local/state}
export XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME

typeset -U path

for _p in /opt/homebrew /home/linuxbrew/.linuxbrew /usr/local; do
  [[ -x $_p/bin/brew ]] && { path=($_p/bin $_p/sbin $path); break }
done
unset _p

# mise shims resolve per-project tool versions without `mise activate`
path=($XDG_DATA_HOME/mise/shims(N-/) $HOME/.local/bin(N-/) $path)
