param(
    [string]$OutputRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist\Sifter'),
    [string]$IconSourcePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\Sifter.png'),
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = (Resolve-Path -LiteralPath $repoRoot).ProviderPath
$outputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$launcherSource = Join-Path $PSScriptRoot 'RomCuratorLauncher.cs'
$assetsRoot = Join-Path $repoRoot 'assets'
$iconPath = Join-Path $assetsRoot 'Sifter.ico'
$launcherExe = Join-Path $outputRoot 'Sifter.exe'

function Test-IsUnderPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Parent
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $fullParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\')
    return $fullPath.Equals($fullParent, [System.StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($fullParent + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-CSharpCompiler {
    $candidates = @(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $fromPath = Get-Command csc.exe -ErrorAction SilentlyContinue
    if ($fromPath) {
        return $fromPath.Source
    }

    throw 'Could not find csc.exe. Install .NET Framework developer tools or run this on a Windows machine with the .NET Framework compiler.'
}

function Convert-PngToIco {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestinationPath
    )

    Add-Type -AssemblyName System.Drawing

    $sourceBitmap = [System.Drawing.Bitmap]::FromFile($SourcePath)
    $frames = @()
    try {
        foreach ($size in @(256, 128, 64, 48, 32, 16)) {
            $bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $stream = [System.IO.MemoryStream]::new()
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

                $scale = [Math]::Min($size / $sourceBitmap.Width, $size / $sourceBitmap.Height)
                $width = [int][Math]::Round($sourceBitmap.Width * $scale)
                $height = [int][Math]::Round($sourceBitmap.Height * $scale)
                $left = [int][Math]::Floor(($size - $width) / 2)
                $top = [int][Math]::Floor(($size - $height) / 2)
                $graphics.DrawImage($sourceBitmap, $left, $top, $width, $height)

                $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
                $frames += [pscustomobject]@{
                    Size = $size
                    Bytes = $stream.ToArray()
                }
            } finally {
                $stream.Dispose()
                $graphics.Dispose()
                $bitmap.Dispose()
            }
        }
    } finally {
        $sourceBitmap.Dispose()
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $DestinationPath) -Force | Out-Null
    $fileStream = [System.IO.File]::Create($DestinationPath)
    $writer = [System.IO.BinaryWriter]::new($fileStream)
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$frames.Count)

        $offset = 6 + ($frames.Count * 16)
        foreach ($frame in $frames) {
            $writer.Write([byte]$(if ($frame.Size -eq 256) { 0 } else { $frame.Size }))
            $writer.Write([byte]$(if ($frame.Size -eq 256) { 0 } else { $frame.Size }))
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$frame.Bytes.Length)
            $writer.Write([UInt32]$offset)
            $offset += $frame.Bytes.Length
        }

        foreach ($frame in $frames) {
            $writer.Write([byte[]]$frame.Bytes)
        }
    } finally {
        $writer.Dispose()
        $fileStream.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $launcherSource)) {
    throw "Missing launcher source: $launcherSource"
}

if (-not (Test-Path -LiteralPath $IconSourcePath)) {
    throw "Missing Sifter icon source: $IconSourcePath"
}

Convert-PngToIco -SourcePath $IconSourcePath -DestinationPath $iconPath

if ($Clean -and (Test-Path -LiteralPath $outputRoot)) {
    $resolvedOutput = (Resolve-Path -LiteralPath $outputRoot).ProviderPath
    if (-not (Test-IsUnderPath -Path $resolvedOutput -Parent $repoRoot)) {
        throw "Refusing to clean an output folder outside the project: $resolvedOutput"
    }

    Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

$copyItems = @(
    'Run-RomCurator.ps1',
    'RomCurator.Core.psm1',
    'Run-RomCurator.cmd',
    'README.md',
    'assets',
    'data',
    'tools'
)

foreach ($item in $copyItems) {
    $source = Join-Path $repoRoot $item
    $destination = Join-Path $outputRoot $item

    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing required package item: $source"
    }

    if ((Get-Item -LiteralPath $source).PSIsContainer) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Copy-Item -Path (Join-Path $source '*') -Destination $destination -Recurse -Force
    } else {
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}

$csc = Get-CSharpCompiler
$compilerArgs = @(
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    '/optimize+',
    '/reference:System.Windows.Forms.dll',
    "/win32icon:$iconPath",
    "/out:$launcherExe",
    $launcherSource
)

& $csc @compilerArgs

if ($LASTEXITCODE -ne 0) {
    throw "Failed to compile Sifter.exe with $csc"
}

Write-Host "Built $launcherExe"
