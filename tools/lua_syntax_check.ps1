param(
    [string]$LuacPath
)

$ErrorActionPreference = "Stop"

function Resolve-Luac {
    param(
        [string]$ExplicitPath
    )

    if ($ExplicitPath -and (Test-Path $ExplicitPath)) {
        return (Resolve-Path $ExplicitPath).Path
    }

    if ($env:LUAC -and (Test-Path $env:LUAC)) {
        return (Resolve-Path $env:LUAC).Path
    }

    $cmd = Get-Command luac.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $cmd = Get-Command luac -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

$luac = Resolve-Luac -ExplicitPath $LuacPath
if (-not $luac) {
    Write-Host "luac.exe was not found."
    Write-Host "Install Lua and ensure luac.exe is in PATH, or set the LUAC environment variable."
    exit 2
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$roots = @("res", "scripts", "lua_intellisense")
$files = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($root in $roots) {
    $fullRoot = Join-Path $repoRoot $root
    if (Test-Path $fullRoot) {
        Get-ChildItem -Path $fullRoot -Recurse -File -Filter *.lua |
            Sort-Object FullName |
            ForEach-Object { [void]$files.Add($_) }
    }
}

if ($files.Count -eq 0) {
    Write-Host "No Lua files found."
    exit 0
}

$failed = $false
foreach ($file in $files) {
    $output = & $luac -p $file.FullName 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failed = $true
        $output | ForEach-Object { Write-Host $_ }
    }
}

if ($failed) {
    Write-Host "Lua syntax check failed."
    exit 1
}

Write-Host "Lua syntax check passed for $($files.Count) files."
