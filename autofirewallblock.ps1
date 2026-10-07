<#
.SYNOPSIS
    AutoFirewallBlock - blocks all executables of a program folder in the Windows Firewall.

.DESCRIPTION
    Searches a folder and all of its subfolders for *.exe files and creates an
    inbound and an outbound block rule for each of them. All rules of one folder
    are put into their own rule group ("AutoFirewallBlock: <folder>"), so they
    can be listed and removed again with this script.

    Started without parameters, an interactive menu is shown.

.EXAMPLE
    .\autofirewallblock.ps1
    Interactive menu.

.EXAMPLE
    .\autofirewallblock.ps1 -Path "C:\Program Files\SomeApp"
    Blocks all .exe files below the given folder.

.EXAMPLE
    .\autofirewallblock.ps1 -Unblock "C:\Program Files\SomeApp"
    Removes all rules that were created for that folder.

.EXAMPLE
    .\autofirewallblock.ps1 -Path "C:\Program Files\SomeApp" -IncludeRelated -StopProcesses
    Takes the program completely off the network: also blocks related folders
    (ProgramData, AppData, ...) and closes its running processes.

.EXAMPLE
    .\autofirewallblock.ps1 -Refresh
    Scans all blocked folders again and blocks new .exe files (after updates).

.EXAMPLE
    .\autofirewallblock.ps1 -List
    Shows all folders blocked by AutoFirewallBlock.
#>
[CmdletBinding(DefaultParameterSetName = 'Menu')]
param(
    [Parameter(ParameterSetName = 'Block', Mandatory, Position = 0)]
    [string]$Path,

    # Also create rules for .dll files (older behavior). The Windows Firewall
    # filters by process image, so rules for DLLs normally have no effect.
    [Parameter(ParameterSetName = 'Block')]
    [switch]$IncludeDll,

    # Also block folders with the same name in ProgramData, AppData and
    # Program Files (x86) - typical places for updaters, launchers and helpers.
    [Parameter(ParameterSetName = 'Block')]
    [switch]$IncludeRelated,

    # Close running processes of the blocked folders, so open connections end.
    [Parameter(ParameterSetName = 'Block')]
    [switch]$StopProcesses,

    [Parameter(ParameterSetName = 'Unblock', Mandatory)]
    [string]$Unblock,

    [Parameter(ParameterSetName = 'List', Mandatory)]
    [switch]$List,

    # Scan all blocked folders again, e.g. after a program update added new .exe files.
    [Parameter(ParameterSetName = 'Refresh', Mandatory)]
    [switch]$Refresh
)

$ErrorActionPreference = 'Stop'
$GroupPrefix = 'AutoFirewallBlock: '

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunch elevated, forwarding the original parameters.
if (-not (Test-Admin)) {
    Write-Host 'Administrator rights are required, requesting elevation...' -ForegroundColor Yellow
    $forward = foreach ($p in $PSBoundParameters.GetEnumerator()) {
        if ($p.Value -is [switch]) { if ($p.Value) { "-$($p.Key)" } }
        # A trailing backslash would escape the closing quote on the command line.
        else { "-$($p.Key) `"$(([string]$p.Value).TrimEnd('\'))`"" }
    }
    # Keep the elevated window open when called with parameters, so the result stays visible.
    $noExit = if ($PSBoundParameters.Count) { @('-NoExit') } else { @() }
    $argList = $noExit + @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"") + @($forward)
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    } catch {
        Write-Host 'Elevation was cancelled. Nothing was changed.' -ForegroundColor Red
    }
    exit
}

function Show-Banner {
    Write-Host @'

      db      `7MM"""YMM `7MM"""Yp,
     ;MM:       MM    `7   MM    Yb
    ,V^MM.      MM   d     MM    dP
   ,M  `MM      MM""MM     MM"""bg.
   AbmmmqMA     MM   Y     MM    `Y
  A'     VML    MM         MM    ,9
.AMA.   .AMMA..JMML.     .JMMmmmd9      AutoFirewallBlock

'@ -ForegroundColor Cyan
}

function Get-GroupName([string]$Folder) {
    $GroupPrefix + $Folder
}

# Compared literally: folder names may contain wildcard characters like [ ].
function Get-GroupRules([string]$Group) {
    Get-NetFirewallRule -All | Where-Object { $_.Group -eq $Group }
}

# Returns one entry per blocked folder: Folder, Group, Rules (count).
function Get-BlockedFolders {
    Get-NetFirewallRule -All |
        Where-Object { $_.Group -like "$GroupPrefix*" } |
        Group-Object -Property Group |
        ForEach-Object {
            [pscustomobject]@{
                Folder = $_.Name.Substring($GroupPrefix.Length)
                Group  = $_.Name
                Rules  = $_.Count
            }
        } |
        Sort-Object Folder
}

function Resolve-Folder([string]$Folder) {
    $Folder = $Folder.Trim().Trim('"').Trim()
    if (-not $Folder -or -not (Test-Path -LiteralPath $Folder -PathType Container)) {
        return $null
    }
    (Resolve-Path -LiteralPath $Folder).ProviderPath.TrimEnd('\')
}

# Blocking a whole drive or the Windows folder would cut off the system itself.
function Test-ProtectedFolder([string]$Folder) {
    if ($Folder -match '^[A-Za-z]:$') { return $true }
    $windir = $env:SystemRoot.TrimEnd('\')
    $Folder -eq $windir -or $Folder.StartsWith("$windir\", [StringComparison]::OrdinalIgnoreCase)
}

function Confirm-Yes([string]$Question) {
    (Read-Host "$Question (y/N)") -match '^(y|j)'
}

# Rules have no effect on a firewall profile that is switched off.
function Assert-FirewallEnabled([bool]$Ask) {
    $off = @(Get-NetFirewallProfile | Where-Object { -not $_.Enabled })
    if (-not $off.Count) { return }
    $names = ($off.Name) -join ', '
    Write-Host "WARNING: The Windows Firewall is switched OFF for: $names" -ForegroundColor Red
    Write-Host 'Block rules do not work there, the program could still go online.' -ForegroundColor Red
    if ($Ask -and (Confirm-Yes 'Switch the firewall on for these profiles?')) {
        $off | Set-NetFirewallProfile -Enabled True
        Write-Host 'Firewall switched on.' -ForegroundColor Green
    }
}

# Folders with the same name in other typical install locations
# (updaters, launchers, crash reporters, helpers).
function Find-RelatedFolders([string]$Folder) {
    $name = Split-Path -Path $Folder -Leaf
    if (-not $name) { return }
    $roots = @($env:ProgramData, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA,
               $env:APPDATA, (Join-Path $env:LOCALAPPDATA 'Programs')) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
        Select-Object -Unique
    $found = foreach ($root in $roots) {
        # <root>\<name> and <root>\<vendor>\<name>
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($_.Name -eq $name) { $_.FullName }
                Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -eq $name } | ForEach-Object { $_.FullName }
            }
    }
    $found | ForEach-Object { $_.TrimEnd('\') } | Select-Object -Unique | Where-Object {
        # Skip the folder itself and anything inside or around it.
        $_ -ne $Folder -and
        -not $_.StartsWith("$Folder\", [StringComparison]::OrdinalIgnoreCase) -and
        -not $Folder.StartsWith("$_\", [StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-ProtectedFolder $_)
    }
}

function Get-FolderProcesses([string[]]$Folders) {
    Get-Process | Where-Object {
        $exe = $_.Path
        $exe -and ($Folders | Where-Object { $exe.StartsWith("$_\", [StringComparison]::OrdinalIgnoreCase) })
    }
}

# New rules do not always cut connections that are already open.
function Stop-FolderProcesses([string[]]$Folders, [bool]$Ask, [bool]$Force) {
    $procs = @(Get-FolderProcesses $Folders)
    if (-not $procs.Count) { return }
    Write-Host ''
    Write-Host 'These processes of the blocked program are still running:' -ForegroundColor Yellow
    $procs | ForEach-Object { Write-Host "  $($_.ProcessName) (PID $($_.Id))" }
    Write-Host 'Connections they already opened may stay alive until they are restarted.' -ForegroundColor Yellow
    if ($Force -or ($Ask -and (Confirm-Yes 'Close them now? Unsaved data in the program is lost.'))) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host 'Processes closed.' -ForegroundColor Green
    } elseif (-not $Ask) {
        Write-Host 'Restart the program (or use -StopProcesses) to cut them off.'
    }
}

function Block-Folder([string]$Folder, [bool]$WithDll) {
    $group = Get-GroupName $Folder
    $name  = Split-Path -Path $Folder -Leaf
    if (-not $name) { $name = $Folder.TrimEnd(':\') }

    $existing = @(Get-GroupRules $group)
    if ($existing.Count) {
        Write-Host "Existing rules for this folder are replaced ($($existing.Count) rules)." -ForegroundColor Yellow
        $existing | Remove-NetFirewallRule
    }

    $patterns = @('*.exe')
    if ($WithDll) { $patterns += '*.dll' }

    Write-Host "Searching '$Folder' for $($patterns -join ', ') ..."
    $files = @(Get-ChildItem -LiteralPath $Folder -Recurse -File -Include $patterns -ErrorAction SilentlyContinue)
    if (-not $files.Count) {
        Write-Host 'No matching files found. Nothing was blocked.' -ForegroundColor Yellow
        return
    }

    $counts = @{ exe = 0; dll = 0 }
    $failed = 0
    $i = 0
    foreach ($file in $files) {
        $i++
        Write-Progress -Activity "Blocking $name" -Status $file.Name -PercentComplete ($i * 100 / $files.Count)
        $type = $file.Extension.TrimStart('.').ToLower()
        $displayName = "AFB_${type}_${name}_$($counts[$type] + 1) ($($file.Name))"
        try {
            foreach ($direction in 'Inbound', 'Outbound') {
                New-NetFirewallRule -DisplayName $displayName -Group $group -Direction $direction `
                    -Action Block -Program $file.FullName -Profile Any -Enabled True `
                    -Description "Created by AutoFirewallBlock for $Folder" | Out-Null
            }
            $counts[$type]++
        } catch {
            $failed++
            Write-Warning "Could not block $($file.FullName): $($_.Exception.Message)"
        }
    }
    Write-Progress -Activity "Blocking $name" -Completed

    Write-Host ''
    Write-Host "$name was blocked successfully." -ForegroundColor Green
    Write-Host "  $($counts.exe) exe blocked"
    if ($WithDll) { Write-Host "  $($counts.dll) dll blocked" }
    if ($failed) { Write-Host "  $failed file(s) failed" -ForegroundColor Red }
}

function Unblock-Folder([string]$Folder) {
    $group = Get-GroupName $Folder
    $rules = @(Get-GroupRules $group)
    if (-not $rules.Count) {
        Write-Host "No AutoFirewallBlock rules found for '$Folder'." -ForegroundColor Yellow
        return
    }
    $rules | Remove-NetFirewallRule
    Write-Host "Removed $($rules.Count) rules for '$Folder'." -ForegroundColor Green
}

# Re-scan every blocked folder, e.g. after an update added new .exe files.
function Update-BlockedFolders {
    $blocked = @(Get-BlockedFolders)
    if (-not $blocked.Count) {
        Write-Host 'No folders are blocked by AutoFirewallBlock.'
        return
    }
    foreach ($entry in $blocked) {
        Write-Host ''
        if (-not (Test-Path -LiteralPath $entry.Folder -PathType Container)) {
            Write-Host "Skipped (folder no longer exists): $($entry.Folder)" -ForegroundColor Yellow
            continue
        }
        $withDll = [bool](Get-GroupRules $entry.Group | Where-Object { $_.DisplayName -like 'AFB_dll_*' })
        Block-Folder $entry.Folder $withDll
    }
}

# Rules created by older versions (netsh, no group) are only recognizable by name.
function Remove-LegacyRules {
    $legacy = @(Get-NetFirewallRule -All | Where-Object { -not $_.Group -and $_.DisplayName -like 'AFB_*' })
    if (-not $legacy.Count) {
        Write-Host 'No rules from older versions found.'
        return
    }
    $answer = Read-Host "Found $($legacy.Count) rules from an older version (AFB_*). Remove them all? (y/N)"
    if ($answer -match '^(y|j)') {
        $legacy | Remove-NetFirewallRule
        Write-Host "Removed $($legacy.Count) rules." -ForegroundColor Green
    }
}

function Show-BlockedFolders {
    $blocked = @(Get-BlockedFolders)
    if (-not $blocked.Count) {
        Write-Host 'No folders are blocked by AutoFirewallBlock.'
    } else {
        $blocked | Format-Table Folder, Rules -AutoSize | Out-Host
    }
    $blocked
}

function Invoke-BlockMenu {
    while ($true) {
        $answer = Read-Host 'Main folder of the program to block (empty = back)'
        if (-not $answer.Trim()) { return }
        $folder = Resolve-Folder $answer
        if (-not $folder) {
            Write-Host '!!! Directory not found, please make sure the directory exists !!!' -ForegroundColor Red
        } elseif (Test-ProtectedFolder $folder) {
            Write-Host '!!! Refusing to block a drive root or a Windows system folder !!!' -ForegroundColor Red
        } else { break }
    }
    Assert-FirewallEnabled $true

    $folders = @($folder)
    $related = @(Find-RelatedFolders $folder)
    if ($related.Count) {
        Write-Host ''
        Write-Host 'Folders with the same name were found in other locations.'
        Write-Host 'They often contain updaters, launchers or helpers of the same program:'
        foreach ($rel in $related) {
            if (Confirm-Yes "  Also block '$rel'?") { $folders += $rel }
        }
    }

    $dll = Confirm-Yes 'Also create rules for .dll files? Usually not needed.'
    foreach ($f in $folders) {
        Write-Host ''
        Block-Folder $f $dll
    }
    Stop-FolderProcesses $folders $true $false
}

function Invoke-UnblockMenu {
    $blocked = @(Show-BlockedFolders)
    if (-not $blocked.Count) { return }
    for ($n = 0; $n -lt $blocked.Count; $n++) {
        Write-Host ("  [{0}] {1}" -f ($n + 1), $blocked[$n].Folder)
    }
    $choice = Read-Host 'Number of the folder to unblock (empty = back)'
    $index = 0
    if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $blocked.Count) {
        Unblock-Folder $blocked[$index - 1].Folder
    }
}

Show-Banner

switch ($PSCmdlet.ParameterSetName) {
    'Block' {
        $folder = Resolve-Folder $Path
        if (-not $folder) { Write-Error "Directory not found: $Path" }
        if (Test-ProtectedFolder $folder) { Write-Error "Refusing to block a drive root or a Windows system folder: $folder" }
        Assert-FirewallEnabled $false
        $folders = @($folder)
        if ($IncludeRelated) { $folders += @(Find-RelatedFolders $folder) }
        foreach ($f in $folders) {
            Write-Host ''
            Block-Folder $f $IncludeDll.IsPresent
        }
        Stop-FolderProcesses $folders $false $StopProcesses.IsPresent
    }
    'Unblock' {
        $folder = Resolve-Folder $Unblock
        if (-not $folder) { $folder = $Unblock.Trim().Trim('"').TrimEnd('\') }
        Unblock-Folder $folder
    }
    'List' { Show-BlockedFolders | Out-Null }
    'Refresh' {
        Assert-FirewallEnabled $false
        Update-BlockedFolders
    }
    'Menu' {
        Assert-FirewallEnabled $true
        while ($true) {
            Write-Host ''
            Write-Host '  [1] Block a program folder'
            Write-Host '  [2] Unblock a program folder'
            Write-Host '  [3] Show blocked folders'
            Write-Host '  [4] Re-scan blocked folders (after program updates)'
            Write-Host '  [5] Remove rules from older versions'
            Write-Host '  [0] Exit'
            switch (Read-Host 'Choice') {
                '1' { Invoke-BlockMenu }
                '2' { Invoke-UnblockMenu }
                '3' { Show-BlockedFolders | Out-Null }
                '4' { Update-BlockedFolders }
                '5' { Remove-LegacyRules }
                '0' { exit }
            }
        }
    }
}
