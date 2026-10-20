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
| `../vscode/settings.json` | `%APPDATA%\Code\User\` |
| `../zed/settings.json` | `%APPDATA%\Zed\` |
| `../git/ignore` | `~\.config\git\ignore` |
| `../vivid/themes/vesper.yml` | `~\.config\vivid\themes\` |
| `../lazygit/config.yml` | `%LOCALAPPDATA%\lazygit\` |

## Packages

`scoop/apps.txt` (CLI tools, toolchains, fonts) and `winget/packages.txt` (apps) are kept by hand,
dev tools only. The install commands are at the top of each file.

```powershell
Get-Content vscode\extensions.txt | ForEach-Object { code --install-extension $_ }
Install-Module PSFzf, CompletionPredictor, git-completion -Scope CurrentUser
```
