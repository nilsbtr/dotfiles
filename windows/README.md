# Windows

Windows versions of the configs. Files that are identical on both systems are not duplicated here,
use the top-level copies.

| File | Location |
| --- | --- |
| `powershell/Microsoft.PowerShell_profile.ps1` | `~\Documents\PowerShell\` |
| `powershell/powershell.config.json` | `~\Documents\PowerShell\` |
| `windows-terminal/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\` |
| `git/.gitconfig` | `~\.gitconfig` (fill in name, email, signingkey) |
| `starship/starship.toml` | `~\.config\starship.toml` |
| `vscode/settings.json` | `%APPDATA%\Code\User\` |
| `zed/settings.json` | `%APPDATA%\Zed\` |
| `../git/ignore` | `~\.config\git\ignore` |
| `../vivid/themes/vesper.yml` | `~\.config\vivid\themes\` |
| `../lazygit/config.yml` | `%LOCALAPPDATA%\lazygit\` |

## Packages

```powershell
scoop import windows\scoop\scoopfile.json
winget import -i windows\winget\packages.json
Get-Content windows\vscode\extensions.txt | ForEach-Object { code --install-extension $_ }
Install-Module PSFzf, CompletionPredictor, git-completion -Scope CurrentUser
```
