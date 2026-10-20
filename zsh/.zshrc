# ~/.zshrc — fast, framework-free zsh for Ghostty · Node/React · Python · Go
#
# Install the tools (all optional — every section is guarded):
#   macOS : brew install starship mise usage fzf fd ripgrep bat eza zoxide vivid
#   Linux : apt install zsh fzf fd-find ripgrep bat zoxide eza vivid
#           + curl -sS https://starship.rs/install.sh | sh
#           + curl https://mise.run | sh
#   Then  : mise install
#
# Plugins self-install on first launch (needs git). Update everything: zsh-update
# Machine-specific settings / secrets → ~/.zshrc.local (sourced last, never committed)
# PATH for non-interactive shells (scripts, `zsh -c`) → ~/.zshenv
# Measure startup: zsh-bench      Profile startup: ZPROF=1 zsh -i -c exit

[[ -n $ZPROF ]] && zmodload zsh/zprof

# ─── Directories ─────────────────────────────────────────────────────────────
: ${XDG_CONFIG_HOME:=$HOME/.config} ${XDG_CACHE_HOME:=$HOME/.cache}
: ${XDG_DATA_HOME:=$HOME/.local/share} ${XDG_STATE_HOME:=$HOME/.local/state}
export XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME

ZSH_CACHE=$XDG_CACHE_HOME/zsh
ZSH_PLUGINS=$XDG_DATA_HOME/zsh/plugins
for _d in $ZSH_CACHE/completions $ZSH_PLUGINS $XDG_STATE_HOME/{zsh,less,python,node}; do
  [[ -d $_d ]] || mkdir -p $_d
done
unset _d

# ─── Options ─────────────────────────────────────────────────────────────────
setopt EXTENDED_GLOB INTERACTIVE_COMMENTS NO_BEEP NO_FLOW_CONTROL
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt COMPLETE_IN_WORD ALWAYS_TO_END

HISTFILE=$XDG_STATE_HOME/zsh/history
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_VERIFY   # leading space = not saved

WORDCHARS='*?_-[]~&;!#$%^(){}<>'   # Ctrl-W stops at / . = (path-friendly)

# ─── PATH ────────────────────────────────────────────────────────────────────
typeset -U path fpath   # keep entries unique

# Homebrew (Apple Silicon, Linuxbrew, Intel) — static, no `brew shellenv` fork
for _p in /opt/homebrew /home/linuxbrew/.linuxbrew /usr/local; do
  if [[ -x $_p/bin/brew ]]; then
    export HOMEBREW_PREFIX=$_p
    path=($_p/bin $_p/sbin $path)
    fpath=($_p/share/zsh/site-functions $fpath)
    break
  fi
done
unset _p

export GOPATH=${GOPATH:-$HOME/go}
export BUN_INSTALL=$HOME/.bun
export PNPM_HOME=$HOME/.pnpm

path=(
  $HOME/.local/bin        # mise, uv, starship installers + uv tool installs
  $PNPM_HOME
  $BUN_INSTALL/bin
  $GOPATH/bin             # go install …
  $HOME/.cargo/bin(N-/)
  $path
)

# App-installed CLIs (skipped if the app isn't installed)
path+=(
  "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"(N-/)  # idea, studio, …
  $HOME/.orbstack/bin(N-/)   # orb, orbctl, kubectl; docker also lives in /usr/local/bin
)

# ─── Environment ─────────────────────────────────────────────────────────────
export LANG=${LANG:-en_US.UTF-8}
if (( $+commands[code] )); then export EDITOR='code --wait'; else export EDITOR=vim; fi
export VISUAL=$EDITOR
export PAGER=less LESS='-R -F -i -M'
export CLICOLOR=1

# Keep REPL / pager history out of $HOME (dirs created above)
export LESSHISTFILE=$XDG_STATE_HOME/less/history
export PYTHON_HISTORY=$XDG_STATE_HOME/python/history       # Python ≥ 3.13
export NODE_REPL_HISTORY=$XDG_STATE_HOME/node/repl_history

export DO_NOT_TRACK=1 NEXT_TELEMETRY_DISABLED=1
export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1
export PIP_REQUIRE_VIRTUALENV=true   # never pip-install into a global Python by accident
export VIRTUAL_ENV_DISABLE_PROMPT=1  # the prompt shows the venv itself
export BAT_THEME=OneHalfDark
export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml

# LS_COLORS for eza + completion menus (macOS has none); cached, $(<file) doesn't fork
if (( $+commands[vivid] )); then
  _lsc=$ZSH_CACHE/ls-colors
  [[ -s $_lsc && $_lsc -nt $commands[vivid] ]] || vivid generate one-dark >| $_lsc
  export LS_COLORS=$(<$_lsc)
  unset _lsc
fi

# mise: also honour .nvmrc / .node-version / .python-version / .go-version / .java-version / .sdkmanrc
# (mise ignores these by default). mise sets JAVA_HOME itself — don't export it here.
export MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=node,python,go,java

# Android SDK
export ANDROID_HOME=$HOME/Library/Android/sdk
[[ -d $ANDROID_HOME ]] && path+=($ANDROID_HOME/emulator $ANDROID_HOME/platform-tools)

# mise: per-project Node / Python / Go / Java versions (mise.toml, .tool-versions, .nvmrc …)
# Activated before completions so mise-managed tools (uv, pnpm, just, …) are on PATH there.
# (not cached: its output embeds the current PATH)
(( $+commands[mise] )) && eval "$(mise activate zsh)"

# Debian/Ubuntu ship fd/bat under other names
_fd=${commands[fd]:+fd};   [[ -z $_fd && -n ${commands[fdfind]} ]] && _fd=fdfind
_bat=${commands[bat]:+bat}; [[ -z $_bat && -n ${commands[batcat]} ]] && _bat=batcat

# ─── Helpers: cache generated init scripts & completions ─────────────────────
# `tool init zsh` output is cached and only regenerated when the tool changes,
# which saves a process spawn per tool on every new shell.
_cached_init() {   # _cached_init <name> <cmd> [args…]
  local name=$1 bin=${commands[$2]}
  shift
  [[ -n $bin ]] || return 1
  local f=$ZSH_CACHE/init-$name-${${bin:A}//[^[:alnum:]]/_}.zsh
  if [[ ! -s $f || $bin -nt $f ]]; then
    "$@" >| $f 2>/dev/null && [[ -s $f ]] || { rm -f $f; return 1 }
    zcompile -R -- $f 2>/dev/null
  fi
  source $f
}

_gen_comp() {      # _gen_comp <name> <cmd> [args…]  →  completions/_<name>
  local out=$ZSH_CACHE/completions/_$1 bin=${commands[$2]}
  shift
  [[ -n $bin ]] || return 0
  [[ -s $out && $out -nt $bin ]] && return 0
  "$@" >| $out 2>/dev/null && [[ -s $out ]] || { rm -f $out; return 0 }
  _comp_changed=1
}

# ─── Plugins (git clone on first run, byte-compiled) ─────────────────────────
_plug_compile() { local f; for f in $1/**/*.zsh(N.); do zcompile -R -- $f 2>/dev/null; done }
_plug() {
  local dir=$ZSH_PLUGINS/${1:t}
  [[ -d $dir ]] && return 0
  (( $+commands[git] )) || return 1
  print -P "%F{cyan}zsh:%f installing $1 …"
  git clone --quiet --depth=1 https://github.com/$1.git $dir && _plug_compile $dir
}

_plug zsh-users/zsh-completions
_plug Aloxaf/fzf-tab
_plug zsh-users/zsh-autosuggestions
_plug zdharma-continuum/fast-syntax-highlighting
_plug MichaelAquilina/zsh-you-should-use

# ─── Completion ──────────────────────────────────────────────────────────────
_gen_comp uv     uv generate-shell-completion zsh
_gen_comp uvx    uvx --generate-shell-completion zsh
_gen_comp mise   mise completion zsh          # needs `usage` (brew install usage)
_gen_comp docker docker completion zsh
_gen_comp pnpm   pnpm completion zsh
_gen_comp just   just --completions zsh
_gen_comp ruff   ruff generate-shell-completion zsh

fpath=($ZSH_CACHE/completions $ZSH_PLUGINS/zsh-completions/src $BUN_INSTALL(N-/) $fpath)

autoload -Uz compinit
_zcd=$ZSH_CACHE/zcompdump-$ZSH_VERSION
[[ -n $_comp_changed ]] && rm -f $_zcd
# Full security check at most once a day; otherwise load the dump directly.
# touch: compinit only rewrites the dump when fpath changes, so its mtime would go stale.
if [[ ! -s $_zcd || -n $_zcd(#qN.mh+20) ]]; then
  compinit -i -d $_zcd && touch $_zcd
else
  compinit -C -d $_zcd
fi
{ [[ -s $_zcd && ! $_zcd.zwc -nt $_zcd ]] && zcompile -R -- $_zcd } &!

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $ZSH_CACHE/compcache
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' menu no                       # fzf-tab takes over
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w'

zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:(cd|z|__zoxide_z):*' fzf-preview \
  'eza -1 --color=always --icons=always $realpath 2>/dev/null || ls -1 $realpath'
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
  'git diff --color=always -- $realpath'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps -p $word -o comm=,args='

# ─── Key bindings (Emacs mode) ───────────────────────────────────────────────
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search edit-command-line
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
zle -N edit-command-line

bindkey '^[[A' up-line-or-beginning-search     # ↑ / ↓ search history by prefix
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
bindkey '^[[1;5C' forward-word                 # Ctrl-→ / Ctrl-←
bindkey '^[[1;5D' backward-word
bindkey '^[[1;3C' forward-word                 # Alt-→ / Alt-← (macos-option-as-alt)
bindkey '^[[1;3D' backward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^X^E' edit-command-line               # open command in $EDITOR
bindkey '^ ' autosuggest-accept                # Ctrl-Space accepts suggestion


# ─── Plugins: load order matters ─────────────────────────────────────────────
# compinit → fzf-tab → fzf (so `**<Tab>` falls back to fzf-tab) → autosuggest → highlighting
[[ -f $ZSH_PLUGINS/fzf-tab/fzf-tab.plugin.zsh ]] && source $ZSH_PLUGINS/fzf-tab/fzf-tab.plugin.zsh

if (( $+commands[fzf] )); then
  if [[ -n $_fd ]]; then
    export FZF_DEFAULT_COMMAND="$_fd --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
    export FZF_ALT_C_COMMAND="$_fd --type d --hidden --follow --exclude .git"
  fi
  export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border=rounded --info=inline --cycle'
  export FZF_CTRL_T_OPTS="--preview '${_bat:-cat} --color=always --style=numbers --line-range=:300 {} 2>/dev/null || cat {}'"
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {} 2>/dev/null || ls {}'"
  # fzf ≥ 0.48 has `fzf --zsh`; fall back to distro-shipped scripts on older versions
  _cached_init fzf fzf --zsh || {
    for _f in /usr/share/{doc/fzf/examples,fzf}/{key-bindings,completion}.zsh(N); do source $_f; done
    unset _f
  }
fi

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=30
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_MANUAL_REBIND=1   # don't re-wrap every widget before each prompt
[[ -f $ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source $ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f $ZSH_PLUGINS/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]] &&
  source $ZSH_PLUGINS/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
[[ -f $ZSH_PLUGINS/zsh-you-should-use/you-should-use.plugin.zsh ]] &&
  source $ZSH_PLUGINS/zsh-you-should-use/you-should-use.plugin.zsh

# ─── Tools ───────────────────────────────────────────────────────────────────
autoload -Uz add-zsh-hook

_cached_init zoxide zoxide init zsh        # z <dir>, zi = interactive
_cached_init direnv direnv hook zsh        # only if installed

# Auto-activate the nearest .venv when you cd into a Python project, deactivate on leave
_auto_venv() {
  local dir=$PWD venv=
  while :; do
    if [[ -f $dir/.venv/bin/activate ]]; then venv=$dir/.venv; break; fi
    [[ $dir == / ]] && break
    dir=${dir:h}
  done
  if [[ -n $venv && $VIRTUAL_ENV != $venv ]]; then
    (( $+functions[deactivate] )) && deactivate
    source $venv/bin/activate && _AUTO_VENV=$venv
  elif [[ -z $venv && -n $_AUTO_VENV && $VIRTUAL_ENV == $_AUTO_VENV ]]; then
    deactivate; unset _AUTO_VENV
  fi
}
add-zsh-hook chpwd _auto_venv
_auto_venv

# ─── Prompt ──────────────────────────────────────────────────────────────────
if (( $+commands[starship] )); then
  _cached_init starship starship init zsh --print-full-init
else
  autoload -Uz vcs_info
  add-zsh-hook precmd vcs_info
  zstyle ':vcs_info:git:*' formats ' %F{magenta}%b%f'
  setopt PROMPT_SUBST
  PROMPT='%F{blue}%~%f${vcs_info_msg_0_} %(?.%F{green}.%F{red})❯%f '
fi

# ─── Aliases ─────────────────────────────────────────────────────────────────
alias ...='cd ../..' ....='cd ../../..'
alias -- -='cd -'
alias reload='exec zsh'
alias path='print -l $path'
alias mkdir='mkdir -p'
alias grep='grep --color=auto'
[[ $OSTYPE == darwin* ]] && alias o='open' || alias o='xdg-open'

if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lh --git --group-directories-first --icons=auto'
  alias la='ll -a'
  alias lt='eza --tree --level=2 --git-ignore --icons=auto'
else
  [[ $OSTYPE == darwin* ]] && alias ls='ls -G' || alias ls='ls --color=auto'
  alias ll='ls -lh' la='ls -lAh'
fi

if [[ -n $_bat ]]; then
  [[ $_bat == batcat ]] && alias bat=batcat
  alias cat="$_bat --paging=never --style=plain"
  export MANPAGER="sh -c 'col -bx | $_bat -l man -p'" MANROFFOPT='-c'
fi
[[ -n $_fd && $_fd == fdfind ]] && alias fd=fdfind
(( $+commands[rg] )) && alias rg='rg --smart-case'
(( $+commands[lazygit] )) && alias lg=lazygit

# Git
alias g=git
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend --no-edit'
alias gd='git diff'
alias gds='git diff --staged'
alias gsw='git switch'
alias gswc='git switch -c'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gl='git pull --rebase'
alias gst='git stash'
alias gstp='git stash pop'
alias glog='git log --oneline --graph --decorate -20'

# Docker
alias d=docker
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Python
(( $+commands[python] )) || alias python=python3
alias uvr='uv run'

# Go
alias gor='go run .'
alias gob='go build'
alias got='go test ./...'
alias gomt='go mod tidy'

# VS Code
(( $+commands[code] )) && alias vsc='code .'

# ─── Functions ───────────────────────────────────────────────────────────────
# Node: detect the project's package manager from its lockfile
pm() {
  local dir=$PWD
  while :; do
    [[ -f $dir/bun.lock || -f $dir/bun.lockb ]] && { print bun; return }
    [[ -f $dir/pnpm-lock.yaml ]]              && { print pnpm; return }
    [[ -f $dir/yarn.lock ]]                   && { print yarn; return }
    [[ -f $dir/package-lock.json ]]           && { print npm; return }
    [[ $dir == / ]] && break
    dir=${dir:h}
  done
  print npm
}
# ni / nr / nx — skipped if you already use @antfu/ni (same names)
(( $+commands[ni] )) || ni() { $(pm) install "$@" }
(( $+commands[nr] )) || nr() { $(pm) run "$@" }
(( $+commands[nx] )) || nx() {
  case $(pm) in
    pnpm) pnpm dlx "$@" ;;
    bun)  bunx "$@" ;;
    *)    npx "$@" ;;
  esac
}
alias nrd='nr dev' nrb='nr build' nrt='nr test' nrl='nr lint'

# Pick a package.json script with fzf and run it
nrf() {
  [[ -f package.json ]] || { print 'no package.json here'; return 1 }
  local s
  s=$(node -e 'console.log(Object.keys(require("./package.json").scripts||{}).join("\n"))' |
      fzf --prompt='script> ') && nr $s
}

# Delete every node_modules under the current dir (asks first)
nuke-nm() {
  local -a dirs=(${(f)"$(find . -name node_modules -type d -prune 2>/dev/null)"})
  (( $#dirs )) || { print 'no node_modules found'; return }
  print -l $dirs
  read -q "?Delete ${#dirs} folder(s)? [y/N] " && { print; rm -rf -- $dirs }
}

# Python: create (if needed) and activate .venv — uses uv when available
venv() {
  if [[ ! -d .venv ]]; then
    if (( $+commands[uv] )); then uv venv "$@"; else python3 -m venv .venv; fi || return
  fi
  source .venv/bin/activate && _AUTO_VENV=$VIRTUAL_ENV
}

# Ports: list listeners (optionally on one port) / kill whatever holds a port
port()     { lsof -nP -iTCP${1:+:$1} -sTCP:LISTEN }
killport() {
  local -a pids=(${(f)"$(lsof -ti tcp:${1:?usage: killport <port>} -sTCP:LISTEN 2>/dev/null)"})
  (( $#pids )) || { print "nothing on :$1"; return 1 }
  kill $pids && print "killed $pids on :$1"
}

mkcd()  { mkdir -p -- "$1" && cd -- "$1" }

serve() { python3 -m http.server ${1:-8000} }

# Switch git branch with fzf (local + remote, most recent first)
gbf() {
  local b
  b=$(git branch --all --sort=-committerdate --format='%(refname:short)' |
      grep -v HEAD | fzf --prompt='branch> ' --preview 'git log --oneline --color=always -20 {}') &&
    git switch ${b#origin/}
}

# Update plugins, clear caches, restart shell
zsh-update() {
  local d
  for d in $ZSH_PLUGINS/*(N/); do
    print -P "%F{cyan}↻%f ${d:t}"
    git -C $d pull --quiet --ff-only && _plug_compile $d
  done
  local -a junk=($ZSH_CACHE/init-*(N) $ZSH_CACHE/completions/_*(N) $ZSH_CACHE/zcompdump*(N))
  (( $#junk )) && rm -f -- $junk
  exec zsh
}

# Startup time, 10 runs
zsh-bench() {
  local TIMEFMT='%*E s' i
  for i in {1..10}; do time zsh -i -c exit; done
}

# ─── Local overrides & cleanup ───────────────────────────────────────────────
[[ -r ${ZDOTDIR:-$HOME}/.zshrc.local ]] && source ${ZDOTDIR:-$HOME}/.zshrc.local

# Byte-compile this file in the background so the next shell starts faster
() {
  local rc=${ZDOTDIR:-$HOME}/.zshrc
  { [[ -s $rc && ! $rc.zwc -nt $rc ]] && zcompile -R -- $rc 2>/dev/null } &!
}

unset _zcd _comp_changed
[[ -n $ZPROF ]] && zprof
