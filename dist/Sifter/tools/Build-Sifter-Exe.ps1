param(
    [string]$OutputRoot,
    [string]$IconSourcePath,
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$builder = Join-Path $PSScriptRoot 'Build-RomCurator-Exe.ps1'
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $builder)

if ($OutputRoot) {
    $arguments += @('-OutputRoot', $OutputRoot)
}

if ($IconSourcePath) {
    $arguments += @('-IconSourcePath', $IconSourcePath)
}

if ($Clean) {
    $arguments += '-Clean'
}

& powershell @arguments
exit $LASTEXITCODE
