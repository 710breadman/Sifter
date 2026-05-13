param(
    [string]$OutputRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\Sifter.DotNet'),
    [string]$Runtime = 'win-x64',
    [switch]$Clean,
    [switch]$Zip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repoRoot 'src\Sifter.App\Sifter.App.csproj'
$outputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

if ($Clean -and (Test-Path -LiteralPath $outputRoot)) {
    $resolvedRepo = (Resolve-Path -LiteralPath $repoRoot).ProviderPath
    $resolvedOutput = (Resolve-Path -LiteralPath $outputRoot).ProviderPath
    if (-not $resolvedOutput.StartsWith($resolvedRepo, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean outside the repository: $resolvedOutput"
    }

    Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}

dotnet publish $project `
    --configuration Release `
    --runtime $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=embedded `
    --output $outputRoot

if ($LASTEXITCODE -ne 0) {
    throw 'dotnet publish failed.'
}

if ($Zip) {
    $zipPath = "$outputRoot.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $outputRoot '*') -DestinationPath $zipPath -Force
    Write-Host "Published $outputRoot and $zipPath"
} else {
    Write-Host "Published $outputRoot"
}
