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

    [Parameter(ParameterSetName = 'Unblock', Mandatory)]
    [string]$Unblock,

    [Parameter(ParameterSetName = 'List', Mandatory)]
    [switch]$List
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
    $dll = Read-Host 'Also create rules for .dll files? Usually not needed. (y/N)'
    Block-Folder $folder ($dll -match '^(y|j)')
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
        Block-Folder $folder $IncludeDll.IsPresent
    }
    'Unblock' {
        $folder = Resolve-Folder $Unblock
        if (-not $folder) { $folder = $Unblock.Trim().Trim('"').TrimEnd('\') }
        Unblock-Folder $folder
    }
    'List' { Show-BlockedFolders | Out-Null }
    'Menu' {
        while ($true) {
            Write-Host ''
            Write-Host '  [1] Block a program folder'
            Write-Host '  [2] Unblock a program folder'
            Write-Host '  [3] Show blocked folders'
            Write-Host '  [4] Remove rules from older versions'
            Write-Host '  [0] Exit'
            switch (Read-Host 'Choice') {
                '1' { Invoke-BlockMenu }
                '2' { Invoke-UnblockMenu }
                '3' { Show-BlockedFolders | Out-Null }
                '4' { Remove-LegacyRules }
                '0' { exit }
            }
        }
    }
}
