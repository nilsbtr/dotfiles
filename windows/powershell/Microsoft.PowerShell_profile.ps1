# PowerShell 7 profile: the Windows mirror of ~/.zshrc from the dotfiles (macOS)
#
# Install the tools (all required: nothing checks whether they're on PATH, that costs ~230 ms):
#   scoop  : scoop install starship vivid fzf fd ripgrep bat eza zoxide delta lazygit lazydocker gh
#   toolchains (scoop): nodejs-lts pnpm bun python uv ruff go just just-lsp flutter
#                       java/temurin25-jdk
#   modules: Install-Module PSFzf, CompletionPredictor, git-completion -Scope CurrentUser
#
# Overview of the aliases and functions below: phelp [filter]
# Machine-specific settings / secrets: profile.local.ps1 next to this file (sourced last, never committed)
# PATH for every app (not just this shell): user PATH has scoop shims, ~/.local/bin, scoop pnpm's and bun's bin, ~/go/bin
# Measure startup: pwsh-bench

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ----- Directories -----
$StateDir = Join-Path $HOME '.local\state'
foreach ($d in 'less', 'python', 'node') {
    if (-not (Test-Path "$StateDir\$d")) { New-Item -ItemType Directory -Force "$StateDir\$d" | Out-Null }
}

# Tool init scripts and completions are cached so the shell starts fast.
# A cache is regenerated when the tool's exe path, size or timestamp changes.
$ProfileCacheDir = Join-Path $env:LOCALAPPDATA 'pwsh-profile-cache'
if (-not (Test-Path $ProfileCacheDir)) { New-Item -ItemType Directory $ProfileCacheDir | Out-Null }

function Get-CachedInit {
    param([string]$Name, [string]$Exe, [scriptblock]$Generate)
    $cache = Join-Path $ProfileCacheDir "$Name.ps1"
    # Fast path: the cache's first line names the exe it came from; if that file is unchanged,
    # skip the PATH lookup (the first one in a session costs ~230 ms)
    if ([IO.File]::Exists($cache)) {
        $reader = [IO.StreamReader]::new($cache); $first = $reader.ReadLine(); $reader.Dispose()
        if ($first -match '^# cache-key: (.+)\|(\d+)\|(\d+)$') {
            $file = [IO.FileInfo]::new($Matches[1])
            if ($file.Exists -and $file.Length -eq $Matches[2] -and $file.LastWriteTimeUtc.Ticks -eq $Matches[3]) { return $cache }
        }
    }
    $exePath = (Get-Command $Exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $exePath) { return $null }
    # Scoop shims never change, so key on the real exe behind the shim
    $shim = [IO.Path]::ChangeExtension($exePath, '.shim')
    if (Test-Path $shim) { $exePath = ((Get-Content $shim -TotalCount 1) -replace '^path\s*=\s*"?|"$', '') }
    $file = Get-Item $exePath
    $stamp = "# cache-key: $($file.FullName)|$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
    if (-not (Test-Path $cache) -or (Get-Content $cache -TotalCount 1) -ne $stamp) {
        $out = & $Generate | Out-String
        if (-not $out.Trim()) { return $null }
        $stamp, $out | Set-Content $cache -Encoding utf8
    }
    $cache
}

# ----- PSReadLine (history, suggestions, highlighting) -----
# Interactive = not `pwsh -Command/-File/-EncodedCommand ...` or `pwsh script.ps1` (unless -NoExit).
# pwsh takes any unambiguous prefix (-comm, -enc, -noex), so flags are matched by prefix.
# CompletionPredictor keeps a non-interactive pwsh from ever exiting, which hangs scripts and editor tasks.
$argv = [Environment]::GetCommandLineArgs() | Select-Object -Skip 1
$flags = foreach ($p in $argv) { if ($p -match '^(--?|/)([a-z]+)$') { $Matches[2].ToLower() } }
$noExit = $flags | Where-Object { $_.Length -ge 3 -and 'noexit'.StartsWith($_) }
$runs = ($argv -match '\.ps1$') -or ($flags | Where-Object { $_ -eq 'ec' -or 'command'.StartsWith($_) -or 'file'.StartsWith($_) -or 'encodedcommand'.StartsWith($_) })
$Interactive = [bool]$noExit -or -not $runs
if ($Interactive) { Import-Module CompletionPredictor -ErrorAction SilentlyContinue }

Set-PSReadLineOption -EditMode Windows `
    -BellStyle None `
    -HistoryNoDuplicates `
    -HistorySearchCursorMovesToEnd `
    -MaximumHistoryCount 100000

# Inline grey suggestions like zsh-autosuggestions (history + completion); needs a real console
if ($Interactive -and -not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle InlineView
}

# Not saved: a leading space (like HIST_IGNORE_SPACE), and lines that look like secrets
Set-PSReadLineOption -AddToHistoryHandler {
    param([string]$line)
    -not $line.StartsWith(' ') -and $line -notmatch '(password|passwd|secret|token|apikey|api_key|connectionstring)'
}

# Highlighting uses the terminal palette (Vesper) by index, like fast-syntax-highlighting:
# comments are bright black (8), variables blue, selections the same #232323 as fzf
Set-PSReadLineOption -Colors @{
    Command                = "`e[32m"
    Comment                = "`e[90m"
    ContinuationPrompt     = "`e[90m"
    Default                = "`e[39m"
    Emphasis               = "`e[93m"
    Error                  = "`e[1;31m"
    InlinePrediction       = "`e[90m"
    Keyword                = "`e[33m"
    ListPrediction         = "`e[33m"
    ListPredictionSelected = "`e[48;2;35;35;35m"
    Member                 = "`e[39m"
    Number                 = "`e[35m"
    Operator               = "`e[39m"
    Parameter              = "`e[36m"
    Selection              = "`e[48;2;35;35;35m"
    String                 = "`e[33m"
    Type                   = "`e[35m"
    Variable               = "`e[34m"
}

# ----- Environment -----
$env:EDITOR = 'code --wait'
$env:VISUAL = $env:EDITOR
$env:LESS = '-R -F -i -M'
$env:CLICOLOR = '1'

# Global installs of package managers (their bin dirs are on the user PATH)
$env:GOPATH = $env:GOPATH ?? "$HOME\go"

# Keep REPL / pager history out of $HOME (dirs created above)
$env:LESSHISTFILE = "$StateDir\less\history"
$env:PYTHON_HISTORY = "$StateDir\python\history"   # Python >= 3.13
$env:NODE_REPL_HISTORY = "$StateDir\node\repl_history"

# No telemetry / nagging
$env:DO_NOT_TRACK = '1'
$env:NEXT_TELEMETRY_DISABLED = '1'

# Python
$env:PIP_REQUIRE_VIRTUALENV = 'true'   # never pip-install into a global Python by accident
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'  # the prompt shows the venv itself

# Tool config
$env:BAT_THEME = 'ansi'   # uses the terminal's (Vesper) palette; also picked up by delta
$env:STARSHIP_CONFIG = "$HOME\.config\starship.toml"

# LS_COLORS for eza: Vesper palette from ~/.config/vivid/themes, else vivid's built-in ansi
$theme = "$HOME\.config\vivid\themes\vesper.yml"
if (-not (Test-Path $theme)) { $theme = 'ansi' }
$lsc = Join-Path $ProfileCacheDir 'ls-colors.ps1'
if ((Test-Path $lsc) -and $theme -ne 'ansi' -and (Get-Item $theme).LastWriteTime -gt (Get-Item $lsc).LastWriteTime) { Remove-Item $lsc }
if ($init = Get-CachedInit ls-colors vivid { "`$env:LS_COLORS = '$(vivid generate $theme)'" }) { . $init }
Remove-Variable theme, lsc

# ----- Completion -----
$completions = [ordered]@{
    gh     = { gh completion -s powershell }
    docker = { docker completion powershell }
    just   = { $env:JUST_COMPLETE = 'powershell'; just; Remove-Item Env:JUST_COMPLETE }
    pnpm   = { pnpm completion pwsh }
    ruff   = { ruff generate-shell-completion powershell }
    uv     = { uv generate-shell-completion powershell }
    uvx    = { uvx --generate-shell-completion powershell }
}
foreach ($name in $completions.Keys) {
    if ($init = Get-CachedInit "completion-$name" $name $completions[$name]) { . $init }
}
Remove-Variable completions, name

# Git (git-completion module, autoloaded on the first Tab); g completes like git
Register-ArgumentCompleter -Native -CommandName git, g -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    Complete-Git -CommandAst $commandAst -CursorPosition $cursorPosition
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $word = $wordToComplete.Replace('"', '""')
    $ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$word" --commandline "$ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# ----- Key bindings -----
Set-PSReadLineKeyHandler -Key UpArrow         -Function HistorySearchBackward   # Up / Down search history by prefix
Set-PSReadLineKeyHandler -Key DownArrow       -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord             # Ctrl-Right / Ctrl-Left
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord
Set-PSReadLineKeyHandler -Key Alt+RightArrow  -Function ForwardWord             # Alt-Right / Alt-Left
Set-PSReadLineKeyHandler -Key Alt+LeftArrow   -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+x,Ctrl+e' -Function ViEditVisually        # open command in $EDITOR
Set-PSReadLineKeyHandler -Key Ctrl+Spacebar   -Function AcceptSuggestion        # Ctrl-Space accepts suggestion
Set-PSReadLineKeyHandler -Key Ctrl+Backspace  -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+z          -Function Undo

# ----- fzf: Ctrl-T files, Alt-C dirs, Ctrl-R history, Tab completion menu (like fzf-tab) -----
# Skip VCS and dependency/cache dirs everywhere, even outside git repos where .gitignore doesn't apply
$fdExcludes = @(
    '.git'
    'node_modules', '.next'              # node/js (vite/astro caches live inside node_modules)
    '.venv', 'venv', '__pycache__'       # python
    '**/pkg/mod'                         # go module cache
    '.gradle', '.m2', 'target', 'build'  # java/gradle/maven, flutter build output
    '.dart_tool'                         # flutter
) | ForEach-Object { "--exclude `"$_`"" }
$fdExcludes = $fdExcludes -join ' '
$env:FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow $fdExcludes"
$env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
$env:FZF_ALT_C_COMMAND = "fd --type d --hidden --follow $fdExcludes"
Remove-Variable fdExcludes
# Colors: terminal palette (Vesper) by index, plus a subtle selection background
$env:FZF_DEFAULT_OPTS = '--height=40% --layout=reverse --border=rounded --info=inline --cycle ' +
    '--color=16,bg+:#232323,fg+:15,hl:11,hl+:11,prompt:4,pointer:11,marker:10,spinner:11,info:8,header:8,border:8,gutter:-1'
$env:FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
$env:FZF_ALT_C_OPTS = "--preview 'eza --tree --level=2 --color=always {}'"

# PSFzf autoloads on the first key press (importing it up front costs ~170 ms per shell)
Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock { Invoke-FzfPsReadlineHandlerProvider }
Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { Invoke-FzfPsReadlineHandlerHistory }
Set-PSReadLineKeyHandler -Key Alt+c  -ScriptBlock { Invoke-FzfPsReadlineHandlerSetLocation }
Set-PSReadLineKeyHandler -Key Tab    -ScriptBlock { Invoke-FzfTabCompletion }

# ----- Tools -----
# Auto-activate the nearest .venv when you cd into a Python project, deactivate on leave
function global:Update-AutoVenv {
    $dir = $PWD.ProviderPath; $venv = $null
    while ($dir) {
        if (Test-Path "$dir\.venv\Scripts\Activate.ps1") { $venv = "$dir\.venv"; break }
        $dir = Split-Path $dir -Parent
    }
    if ($venv -and $env:VIRTUAL_ENV -ne $venv) {
        if (Get-Command deactivate -CommandType Function -ErrorAction SilentlyContinue) { deactivate }
        & "$venv\Scripts\Activate.ps1"; $global:AutoVenv = $venv
    } elseif (-not $venv -and $global:AutoVenv -and $env:VIRTUAL_ENV -eq $global:AutoVenv) {
        deactivate; $global:AutoVenv = $null
    }
}
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = [Delegate]::Combine(
    $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction,
    [EventHandler[System.Management.Automation.LocationChangedEventArgs]] { Update-AutoVenv })
Update-AutoVenv

# ----- Prompt -----
if ($init = Get-CachedInit starship starship { starship init powershell --print-full-init }) { . $init }

# ----- Aliases -----
# PowerShell ships aliases with the same names (gc = Get-Content, gl = Get-Location, ni = New-Item, ...)
foreach ($a in 'cat', 'gc', 'gcm', 'gl', 'gp', 'ls', 'ni') {
    if (Test-Path "Alias:$a") { Remove-Item "Alias:$a" -Force }
}

# General
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function reload { & (Get-Process -Id $PID).Path -NoLogo; exit }  # restart the shell (like exec zsh)
function path { $env:Path -split ';' | Where-Object { $_ } }  # print PATH, one entry per line
function mkdir { New-Item -ItemType Directory -Force @args }
function o { Invoke-Item ($args ? $args : '.') }  # open in Explorer / the default app
function which { param([Parameter(Mandatory)][string]$Name) Get-Command $Name -All | Select-Object CommandType, Name, @{ n = 'Source'; e = { $_.Source ?? $_.Definition } } }  # every command named <name>, in lookup order
function ep { code $PROFILE }  # edit this profile

# Listing (eza)
function ls { eza --group-directories-first --icons=auto @args }
function ll { eza -lh --git --group-directories-first --icons=auto @args }
function la { eza -lh --git --group-directories-first --icons=auto -a @args }
function lt { eza --tree --level=2 --git-ignore --icons=auto @args }

# Modern replacements
function cat { bat --paging=never --style=plain @args }
function rg { rg.exe --smart-case @args }

# Git
function g { git @args }
function gs { git status -sb @args }
function ga { git add @args }
function gaa { git add -A @args }
function gc { git commit @args }
function gcm { git commit -m @args }
function gca { git commit --amend --no-edit @args }
function gd { git diff @args }
function gds { git diff --staged @args }
function gsw { git switch @args }
function gswc { git switch -c @args }
function gp { git push @args }
function gpf { git push --force-with-lease @args }
function gl { git pull --rebase @args }
function gst { git stash @args }
function gstp { git stash pop @args }
function glog { git log --oneline --graph --decorate -20 @args }
function lg { lazygit @args }

# Docker
function d { docker @args }
function dc { docker compose @args }
function dps { docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" @args }
function lzd { lazydocker @args }

# Python
function uvr { uv run @args }

# Go
function gor { go run . @args }
function gob { go build @args }
function got { go test ./... @args }
function gomt { go mod tidy @args }

# Editor
function vsc { code . }

# ----- Functions -----
# General: make a directory and cd into it
function mkcd { param([Parameter(Mandatory)][string]$Path) New-Item -ItemType Directory -Force $Path | Out-Null; Set-Location $Path }

# General: fuzzy-find a file with a bat preview and open it in VS Code
function ff {
    $file = fzf --preview 'bat --color=always --style=numbers --line-range=:300 {}'
    if ($file) { code $file }
}

# Git: switch branch with fzf (local + remote, most recent first)
function gbf {
    $b = git branch --all --sort=-committerdate --format='%(refname:short)' | Where-Object { $_ -notmatch 'HEAD' } |
        fzf --prompt='branch> ' --preview 'git log --oneline --color=always -20 {}'
    if ($b) { git switch ($b -replace '^origin/', '') }
}

# Node: detect the project's package manager from its lockfile
function pm {
    $dir = $PWD.ProviderPath
    while ($dir) {
        if ((Test-Path "$dir\bun.lock") -or (Test-Path "$dir\bun.lockb")) { return 'bun' }
        if (Test-Path "$dir\pnpm-lock.yaml") { return 'pnpm' }
        if (Test-Path "$dir\yarn.lock") { return 'yarn' }
        if (Test-Path "$dir\package-lock.json") { return 'npm' }
        $dir = Split-Path $dir -Parent
    }
    'npm'
}

# Node: ni / nr / nx = install / run / exec with the detected manager
function ni { & (pm) install @args }  # install dependencies
function nr { & (pm) run @args }  # run a package.json script
function nx {  # run a package binary (npx, pnpm dlx, bunx)
    switch (pm) {
        'pnpm' { pnpm dlx @args }
        'bun' { bunx @args }
        default { npx @args }
    }
}
function nrd { nr dev @args }
function nrb { nr build @args }
function nrt { nr test @args }
function nrl { nr lint @args }

# Node: pick a package.json script with fzf and run it
function nrf {
    if (-not (Test-Path package.json)) { Write-Host 'no package.json here'; return }
    $s = (Get-Content package.json -Raw | ConvertFrom-Json).scripts.PSObject.Properties.Name | fzf --prompt='script> '
    if ($s) { nr $s }
}

# Node: delete every node_modules under the current dir (asks first)
function nuke-nm {
    $dirs = @(if (Get-Command fd -ErrorAction SilentlyContinue) {
        fd --type d --hidden --no-ignore --prune --glob node_modules
    } else {
        Get-ChildItem -Recurse -Directory -Force -Filter node_modules | ForEach-Object FullName | Where-Object { $_ -notmatch 'node_modules.+node_modules' }
    })
    if (-not $dirs) { Write-Host 'no node_modules found'; return }
    $dirs
    if ((Read-Host "Delete $($dirs.Count) folder(s)? [y/N]") -eq 'y') { Remove-Item -Recurse -Force $dirs }
}

# Python: create (if needed) and activate .venv, uses uv when available
function venv {
    if (-not (Test-Path .venv)) {
        if (Get-Command uv -ErrorAction SilentlyContinue) { uv venv @args } else { python -m venv .venv }
        if ($LASTEXITCODE) { return }
    }
    & .\.venv\Scripts\Activate.ps1; $global:AutoVenv = $env:VIRTUAL_ENV
}

# Network: list listeners (optionally on one port) / kill the listener on a port / serve cwd
function port {  # list listening ports (port [n])
    param([int]$Number)
    $conns = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { -not $Number -or $_.LocalPort -eq $Number }
    $conns | Sort-Object LocalPort | Select-Object LocalAddress, LocalPort, OwningProcess,
        @{ n = 'Process'; e = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName } }
}
function killport {  # kill whatever listens on a port
    param([Parameter(Mandatory)][int]$Number)
    $pids = @(Get-NetTCPConnection -LocalPort $Number -State Listen -ErrorAction SilentlyContinue | ForEach-Object OwningProcess | Sort-Object -Unique)
    if (-not $pids) { Write-Host "nothing on :$Number"; return }
    Stop-Process -Id $pids -Force; Write-Host "killed $($pids -join ' ') on :$Number"
}
function serve { python -m http.server ($args[0] ?? 8000) }  # serve the current dir (serve [port])

# Shell: update modules, clear caches, restart
function pwsh-update {
    foreach ($m in 'PSFzf', 'CompletionPredictor', 'git-completion') {
        if (Get-Module -ListAvailable $m) { Write-Host "updating $m" -ForegroundColor Cyan; Update-Module $m -ErrorAction SilentlyContinue }
    }
    Remove-Item "$ProfileCacheDir\*.ps1" -Force
    reload
}

# Shell: startup time, 10 runs
function pwsh-bench {
    $exe = (Get-Process -Id $PID).Path
    1..10 | ForEach-Object { '{0:N0} ms' -f (Measure-Command { & $exe -NoLogo -Command exit }).TotalMilliseconds }
}

# Shell: list the aliases, functions and keys in this file (phelp [filter])
function phelp {
    # Categories come from the "# Category" / "# Category: description" comments in the alias
    # and function sections; a trailing "  # ..." describes one function, else a one-line
    # function shows its body. Functions that only add options to the same command are skipped.
    param([string]$Filter)
    $rows = [ordered]@{}; $cat = $null; $desc = $null; $on = $false; $seen = @{}
    foreach ($line in Get-Content $PROFILE) {
        if ($line -eq '# ----- Aliases -----') { $on = $true; continue }
        if ($line -like '# ----- Local overrides*') { break }
        if ($line -like '# -----*' -or -not $on) { continue }
        if ($line -match '^# (.+)$') {
            $cat = ($Matches[1] -split ':')[0] -replace ' \(.*$', ''
            $desc = if ($Matches[1] -match ': (.+)$') { $Matches[1] } else { $null }
            if (-not $rows.Contains($cat)) { $rows[$cat] = [Collections.Generic.List[object]]::new() }
        } elseif ($line -match '^\s*(?:if \(.+\) \{ )?function ([\w.-]+) \{(.*)$') {
            $name = $Matches[1]; $rest = $Matches[2]
            if ($seen[$name] -or -not (Get-Command $name -CommandType Function -ErrorAction SilentlyContinue)) { continue }
            # Own "  # ..." comment, else an alias-like wrapper's command, else the category text, else the body
            $alias = if ($rest -match '^ (.+?) @args \}') { $Matches[1] }
            $text = if ($line -match '[{}]\s+# (.+)$') { $Matches[1] }
                elseif ($alias) { $alias }
                elseif ($desc) { $desc }
                elseif ($rest -match '^ (.+?) \}') { $Matches[1] }
            if ($text -eq $alias -and (($alias -split ' ')[0] -replace '\.exe$') -eq $name) { continue }
            $seen[$name] = $true; $rows[$cat].Add([pscustomobject]@{ Name = $name; Text = $text })
        }
    }
    $rows['Keys'] = [Collections.Generic.List[object]]::new()
    @(
        'Ctrl-R', 'search history (fzf)'; 'Ctrl-T', 'insert a file path (fzf)'; 'Alt-C', 'cd into a subdirectory (fzf)'
        'Tab', 'completion menu (fzf)'; 'Up/Down', "search history by what's typed"; 'Alt-Left/Right', 'move by word'
        'Ctrl-Space', 'accept the grey suggestion'; 'Ctrl-X Ctrl-E', 'edit the command in your editor'
        'z / zi', 'jump to a frequent directory / pick one (zoxide)'; 'cd -', 'back to the previous directory'
    ) | ForEach-Object -Begin { $k = $null } -Process { if ($k) { $rows['Keys'].Add([pscustomobject]@{ Name = $k; Text = $_ }); $k = $null } else { $k = $_ } }

    # get_Keys()/get_Values(): $rows.Keys would return the "Keys" category instead
    $width = ($rows.get_Values() | ForEach-Object { $_ } | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    $shown = 0
    foreach ($c in @($rows.get_Keys())) {
        $entries = @($rows[$c] | Where-Object { -not $Filter -or $c -like "*$Filter*" -or $_.Name -like "*$Filter*" -or $_.Text -like "*$Filter*" })
        if (-not $entries) { continue }
        $shown++
        Write-Host "`e[1;93m$c`e[0m"
        foreach ($e in $entries) { Write-Host ("  `e[32m{0}`e[0m  `e[37m{1}`e[0m" -f $e.Name.PadRight($width), $e.Text) }
        Write-Host
    }
    if (-not $shown) { Write-Host "phelp: nothing matches '$Filter'" }
}

# ----- Local overrides & cleanup -----
$localProfile = Join-Path (Split-Path $PROFILE) 'profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
Remove-Variable localProfile, StateDir, argv, flags, noExit, runs, p, a, d -ErrorAction SilentlyContinue

# zoxide (z <dir>, zi) wraps the prompt, so it loads after starship
if ($init = Get-CachedInit zoxide zoxide { zoxide init powershell }) { . $init }
Remove-Variable init -ErrorAction SilentlyContinue
