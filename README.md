# dotfiles

Plain copies of my dev config (macOS first; VS Code notes the Windows font stack inline). No tooling: copy files in to back up, copy them out to restore.

| Repo | Location on disk |
|---|---|
| `brew/Brewfile` | — (hand-maintained package list) |
| `ghostty/config` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `git/.gitconfig` | `~/.gitconfig` (fill in `name`, `email`, `signingkey`, gpg `program`) |
| `mise/config.toml` | `~/.config/mise/config.toml` |
| `pnpm/config.yaml` | `~/.config/pnpm/config.yaml` |
| `starship/starship.toml` | `~/.config/starship/starship.toml` |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` |
| `vscode/extensions.txt` | installed VS Code extensions |
| `zed/settings.json` | `~/.config/zed/settings.json` |
| `zsh/.zshrc` | `~/.zshrc` |
| `zsh/.zshrc.local.example` | `~/.zshrc.local` (machine-specific; never commit the real one) |

## Back up (home → repo)

```sh
cd ~/Developer/dotfiles
AS="$HOME/Library/Application Support"
cp "$AS/com.mitchellh.ghostty/config"  ghostty/config
cp ~/.config/mise/config.toml          mise/config.toml
cp ~/.config/pnpm/config.yaml          pnpm/config.yaml
cp ~/.config/starship/starship.toml    starship/starship.toml
cp "$AS/Code/User/settings.json"       vscode/settings.json
jq -r '.[].identifier.id' ~/.vscode/extensions/extensions.json | sort -fu > vscode/extensions.txt
cp ~/.config/zed/settings.json         zed/settings.json
cp ~/.zshrc                            zsh/.zshrc
# git/.gitconfig: copy by hand and blank out name, email, signingkey and program
git add -A && git commit -m "Update dotfiles" && git push
```

`brew/Brewfile` is edited by hand — add or remove a line when you install or uninstall something.

## Restore on a new Mac

```sh
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
git clone https://github.com/nilsbtr/dotfiles.git ~/Developer/dotfiles && cd ~/Developer/dotfiles

brew bundle --file=brew/Brewfile

AS="$HOME/Library/Application Support"
mkdir -p "$AS/com.mitchellh.ghostty" "$AS/Code/User" ~/.config/{mise,pnpm,starship,zed}
cp ghostty/config          "$AS/com.mitchellh.ghostty/config"
cp git/.gitconfig          ~/.gitconfig   # then fill in name, email, signingkey, program
cp mise/config.toml        ~/.config/mise/config.toml
cp pnpm/config.yaml        ~/.config/pnpm/config.yaml
cp starship/starship.toml  ~/.config/starship/starship.toml
cp vscode/settings.json    "$AS/Code/User/settings.json"
xargs -n1 code --install-extension < vscode/extensions.txt
cp zed/settings.json       ~/.config/zed/settings.json
cp zsh/.zshrc              ~/.zshrc
cp -n zsh/.zshrc.local.example ~/.zshrc.local

exec zsh       # zsh plugins self-install on first launch
mise install   # node, python, go, java, bun, pnpm, uv, ruff, just, flutter …
```

