Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoRoot 'RomCurator.Core.psm1') -Force -DisableNameChecking

$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
    $script:Passed++
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected' but got '$Actual'."
    }
    $script:Passed++
}

function Invoke-Test {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Write-Host "[PASS] $Name" -ForegroundColor Green
    } catch {
        $script:Failed++
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Reset-TestWorkspace {
    $tmp = Join-Path $PSScriptRoot 'tmp'
    $resolvedTests = (Resolve-Path -LiteralPath $PSScriptRoot).ProviderPath
    if (Test-Path -LiteralPath $tmp) {
        $resolvedTmp = (Resolve-Path -LiteralPath $tmp).ProviderPath
        if (-not $resolvedTmp.StartsWith($resolvedTests, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove temp path outside tests folder: $resolvedTmp"
        }
        Remove-Item -LiteralPath $resolvedTmp -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    return $tmp
}

$tmpRoot = Reset-TestWorkspace
$fixtures = Join-Path $PSScriptRoot 'fixtures'
$ratingsFixture = Join-Path $fixtures 'metacritic_fixture.jsonl'

Invoke-Test 'name cleaning removes release noise and preserves subtitles' {
    Assert-Equal 'Rage' (Normalize-RomCuratorGameName 'Rage_EUR_MULTi4_PS3-ABSTRAKT') 'Rage cleaner failed.'
    Assert-Equal 'Sacred 2: Fallen Angel' (Normalize-RomCuratorGameName 'Sacred_2_Fallen_Angel_BLES00410') 'Sacred cleaner failed.'
    Assert-Equal 'Game Name' (Normalize-RomCuratorGameName 'Game.Name.USA.En.Fr.De.SceneGroup') 'Dotted scene-name cleaner failed.'
}

Invoke-Test 'system aliases resolve common frontend names' {
    $aliases = Get-RomCuratorDefaultSystemAliases
    Assert-Equal 'gc' (Resolve-RomCuratorSystemAlias -System 'gamecube' -AliasMap $aliases) 'GameCube alias failed.'
    Assert-Equal 'psx' (Resolve-RomCuratorSystemAlias -System 'PlayStation' -AliasMap $aliases) 'PlayStation alias failed.'
    Assert-Equal 'arcade' (Resolve-RomCuratorSystemAlias -System 'mame' -AliasMap $aliases) 'MAME alias failed.'
}

Invoke-Test 'theme setting survives settings JSON round-trip' {
    $settings = New-RomCuratorDefaultSettings
    Assert-True ($null -ne $settings.PSObject.Properties['Theme']) 'Default settings should include Theme.'
    Assert-True ($null -ne $settings.PSObject.Properties['DarkMode']) 'Default settings should include DarkMode.'
    $settings.Theme = 'Dark'
    $settings.DarkMode = $true
    $roundTrip = $settings | ConvertTo-RomCuratorJson | ConvertFrom-Json
    Assert-Equal 'Dark' $roundTrip.Theme 'Theme setting did not round-trip.'
    Assert-True ([bool]$roundTrip.DarkMode) 'DarkMode toggle did not round-trip.'
}

Invoke-Test 'quick system discovery matches aliases and records mismatches' {
    $root = Join-Path $tmpRoot 'discovery'
    $gamelists = Join-Path $root 'gamelists'
    $roms = Join-Path $root 'roms'
    $media = Join-Path $root 'media'
    New-Item -ItemType Directory -Path (Join-Path $gamelists 'gamecube') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $roms 'gc') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $media 'gc') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $gamelists 'gamecube\gamelist.xml') -Value '<gameList />' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $roms 'gc\Game Name.iso') -Value 'rom' -Encoding ASCII
    $settings = New-RomCuratorDefaultSettings
    $settings.GamelistsRoot = $gamelists
    $settings.RomsRoot = $roms
    $settings.MediaRoot = $media
    $discovery = @(Get-RomCuratorSystemDiscovery -Settings $settings)
    $gc = $discovery | Where-Object CanonicalSystem -eq 'gc' | Select-Object -First 1
    Assert-True ($null -ne $gc) 'Alias-matched GameCube discovery row missing.'
    Assert-True $gc.HasGamelist 'Discovery should find gamelist.'
    Assert-True $gc.HasRomFolder 'Discovery should find ROM folder.'
    Assert-True $gc.HasMediaFolder 'Discovery should find media folder.'
    Assert-True ($gc.WarningsText -like '*Alias match*') 'Discovery should record alias mismatch notes.'
}

Invoke-Test 'Metacritic JSONL parser and matcher handle fixture schema' {
    $warnings = [System.Collections.Generic.List[object]]::new()
    $records = @(Import-RomCuratorMetacriticJsonl -Path $ratingsFixture -Warnings $warnings)
    Assert-Equal 3 $records.Count 'Rating fixture count mismatch.'
    Assert-Equal 0 $warnings.Count 'Rating fixture should not warn.'
    $index = New-RomCuratorRatingIndex -Records $records
    $match = Find-RomCuratorRatingMatch -Name 'Legend of Zelda Ocarina of Time (USA)' -System 'n64' -Index $index
    Assert-Equal 99 $match.CriticScore 'Zelda score match failed.'
    Assert-True ($match.MatchConfidence -ge 0.9) 'Zelda confidence too low.'
}

Invoke-Test 'duplicate grouping uses cleaned names, not raw filenames' {
    $items = @(
        [pscustomobject]@{ System='gc'; CleanName=(Normalize-RomCuratorGameName 'Game.Name.USA.En.Fr.De.SceneGroup'); OriginalName='Game.Name.USA.En.Fr.De.SceneGroup.iso'; CriticScore=80; MatchConfidence=0.90; Favorite='false'; HasImage=$false; HasVideo=$false; FileSize=300; Extension='.iso'; Selected=$false },
        [pscustomobject]@{ System='gc'; CleanName=(Normalize-RomCuratorGameName 'Game Name (USA)'); OriginalName='Game Name (USA).iso'; CriticScore=88; MatchConfidence=0.95; Favorite='false'; HasImage=$true; HasVideo=$false; FileSize=250; Extension='.iso'; Selected=$false },
        [pscustomobject]@{ System='gc'; CleanName=(Normalize-RomCuratorGameName 'Game_Name_v1.01'); OriginalName='Game_Name_v1.01.iso'; CriticScore=84; MatchConfidence=0.91; Favorite='false'; HasImage=$false; HasVideo=$false; FileSize=200; Extension='.iso'; Selected=$false }
    )
    Update-RomCuratorDuplicateGroups -Items $items | Out-Null
    Assert-Equal 3 (@($items | Where-Object IsDuplicate).Count) 'All three cleaned title variants should be grouped as duplicates.'
    Assert-Equal 1 (@($items | Where-Object { $_.DuplicateRank -eq 1 }).Count) 'Duplicate group should have one best item.'
}

Invoke-Test 'auto-selection skips cleaned-name duplicates and excluded systems' {
    $items = @(
        [pscustomobject]@{ System='gc'; CleanName='Game Name'; OriginalName='Game.Name.USA.iso'; CriticScore=80; MatchConfidence=0.90; Favorite='false'; HasImage=$false; HasVideo=$false; FileSize=[int64]300; MediaSize=[int64]0; Extension='.iso'; RomPath='R:\roms\gc\Game.Name.USA.iso'; Selected=$false; Genre='Action'; Players='1' },
        [pscustomobject]@{ System='ps2'; CleanName='Game Name'; OriginalName='Game Name.iso'; CriticScore=91; MatchConfidence=0.96; Favorite='false'; HasImage=$true; HasVideo=$false; FileSize=[int64]500; MediaSize=[int64]0; Extension='.iso'; RomPath='R:\roms\ps2\Game Name.iso'; Selected=$false; Genre='Action'; Players='1' },
        [pscustomobject]@{ System='n64'; CleanName='Other Game'; OriginalName='Other Game.z64'; CriticScore=95; MatchConfidence=0.98; Favorite='false'; HasImage=$true; HasVideo=$false; FileSize=[int64]100; MediaSize=[int64]0; Extension='.z64'; RomPath='R:\roms\n64\Other Game.z64'; Selected=$false; Genre='Adventure'; Players='2' },
        [pscustomobject]@{ System='gba'; CleanName='Excluded Gem'; OriginalName='Excluded Gem.gba'; CriticScore=99; MatchConfidence=0.99; Favorite='false'; HasImage=$true; HasVideo=$false; FileSize=[int64]10; MediaSize=[int64]0; Extension='.gba'; RomPath='R:\roms\gba\Excluded Gem.gba'; Selected=$false; Genre='Action'; Players='1' }
    )
    $summary = Select-RomCuratorByCriteria -Items $items -TopNOverall 10 -ExcludeSystems @('gba') -ExcludeUnmatched
    Assert-Equal 2 $summary.SelectedCount 'Auto-select should keep best duplicate plus other non-excluded game.'
    Assert-True ($summary.DuplicatesSkipped -ge 1) 'Auto-select should report skipped duplicate.'
    Assert-True (-not ($items | Where-Object { $_.System -eq 'gba' }).Selected) 'Excluded system should not be selected.'
    Assert-True (($items | Where-Object { $_.System -eq 'ps2' }).Selected) 'Best duplicate should be selected.'
}

Invoke-Test 'system count aggregation separates copyable, missing, visible, duplicates, and size' {
    $items = @(
        [pscustomobject]@{ System='gc'; CleanName='Game Name'; OriginalName='Game Name.iso'; CriticScore=88; MatchConfidence=0.9; FileSize=[int64]100; MediaSize=[int64]10; Extension='.iso'; RomPath='R:\roms\gc\Game Name.iso'; Selected=$true; HasGamelistEntry=$true; IssuesText=''; IsDuplicate=$false; DuplicateKey='game name' },
        [pscustomobject]@{ System='gc'; CleanName='Game Name'; OriginalName='Game Name v1.iso'; CriticScore=80; MatchConfidence=0.8; FileSize=[int64]120; MediaSize=[int64]5; Extension='.iso'; RomPath='R:\roms\gc\Game Name v1.iso'; Selected=$false; HasGamelistEntry=$false; IssuesText='Orphan ROM without gamelist entry'; IsDuplicate=$false; DuplicateKey='game name' },
        [pscustomobject]@{ System='gc'; CleanName='Missing Game'; OriginalName='Missing Game.iso'; CriticScore=$null; MatchConfidence=$null; FileSize=[int64]0; MediaSize=[int64]0; Extension='[missing]'; RomPath=''; Selected=$false; HasGamelistEntry=$true; IssuesText='Missing ROM for gamelist entry'; IsDuplicate=$false; DuplicateKey='missing game' }
    )
    Update-RomCuratorDuplicateGroups -Items $items | Out-Null
    $summary = @(Get-RomCuratorSystemSummaries -Items $items -VisibleItems @($items[0]) -ExcludedSystems @('ps2') -FullSelectedSystems @('gc')) | Select-Object -First 1
    Assert-Equal 3 $summary.TotalEntries 'Total system entry count mismatch.'
    Assert-Equal 2 $summary.CopyableGames 'Copyable game count mismatch.'
    Assert-Equal 1 $summary.MissingRomEntries 'Missing ROM count mismatch.'
    Assert-Equal 1 $summary.OrphanRoms 'Orphan ROM count mismatch.'
    Assert-Equal 1 $summary.VisibleGames 'Visible count mismatch.'
    Assert-Equal 220 $summary.RomSize 'ROM size should exclude missing/media.'
    Assert-Equal 15 $summary.MediaSize 'Media size mismatch.'
    Assert-True $summary.FullSystemSelected 'Full-system selected flag mismatch.'
}

Invoke-Test 'auto-selection counts skip missing ROMs and respect size limit' {
    $items = @(
        [pscustomobject]@{ System='gc'; CleanName='Top Game'; OriginalName='Top Game.iso'; CriticScore=99; MatchConfidence=0.99; FileSize=[int64]90; MediaSize=[int64]0; Extension='.iso'; RomPath='R:\roms\gc\Top Game.iso'; Selected=$false; Genre='Action'; Players='1'; Favorite='false'; HasImage=$true; HasVideo=$false },
        [pscustomobject]@{ System='gc'; CleanName='Big Game'; OriginalName='Big Game.iso'; CriticScore=98; MatchConfidence=0.99; FileSize=[int64](2GB); MediaSize=[int64]0; Extension='.iso'; RomPath='R:\roms\gc\Big Game.iso'; Selected=$false; Genre='Action'; Players='1'; Favorite='false'; HasImage=$true; HasVideo=$false },
        [pscustomobject]@{ System='gc'; CleanName='Missing Game'; OriginalName='Missing Game.iso'; CriticScore=100; MatchConfidence=1.0; FileSize=[int64]0; MediaSize=[int64]0; Extension='[missing]'; RomPath=''; Selected=$false; Genre='Action'; Players='1'; Favorite='false'; HasImage=$false; HasVideo=$false }
    )
    $summary = Select-RomCuratorByCriteria -Items $items -TopNOverall 10 -MaxTotalGB 1 -ExcludeUnmatched
    Assert-Equal 1 $summary.CopyableSelectedCount 'Auto-select should choose only the small copyable game under size limit.'
    Assert-Equal 90 $summary.RomSize 'Auto-select size summary mismatch.'
    Assert-True (($items | Where-Object CleanName -eq 'Top Game').Selected) 'Small top game should be selected.'
    Assert-True (-not (($items | Where-Object CleanName -eq 'Missing Game').Selected)) 'Missing ROM must not be selected.'
}

Invoke-Test 'gamelist parser extracts fields and recovers valid entries from bad XML' {
    $warnings = [System.Collections.Generic.List[object]]::new()
    $entries = @(Parse-RomCuratorGamelist -Path (Join-Path $fixtures 'gamelists\gc\gamelist.xml') -System 'gc' -RomSystemRoot $tmpRoot -Warnings $warnings)
    Assert-Equal 2 $entries.Count 'Good gamelist entry count mismatch.'
    Assert-Equal 'Adventure' $entries[0].Genre 'Genre not parsed.'
    Assert-Equal 'true' $entries[0].Favorite 'Favorite not parsed.'
    $badWarnings = [System.Collections.Generic.List[object]]::new()
    $bad = @(Parse-RomCuratorGamelist -Path (Join-Path $fixtures 'gamelists\bad\gamelist.xml') -System 'bad' -RomSystemRoot $tmpRoot -Warnings $badWarnings)
    Assert-Equal 1 $bad.Count 'Bad XML recovery should keep the closed game entry.'
    Assert-True ($badWarnings.Count -ge 1) 'Bad XML should warn.'
}

Invoke-Test 'library scan matches ROMs, gamelist metadata, media, ratings, missing ROMs, and orphan ROMs' {
    $romRoot = Join-Path $tmpRoot 'roms'
    $gcRoot = Join-Path $romRoot 'gc'
    $badRoot = Join-Path $romRoot 'bad'
    $ps3Root = Join-Path $romRoot 'ps3'
    New-Item -ItemType Directory -Path (Join-Path $gcRoot 'media\images') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $gcRoot 'media\videos') -Force | Out-Null
    New-Item -ItemType Directory -Path $badRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $ps3Root -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $gcRoot 'The Legend of Zelda - Ocarina of Time (USA).z64') -Value 'rom' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $gcRoot 'media\images\The Legend of Zelda - Ocarina of Time (USA).png') -Value 'image' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $gcRoot 'media\videos\The Legend of Zelda - Ocarina of Time (USA).mp4') -Value 'video' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $badRoot 'Rage_EUR_MULTi4_PS3-ABSTRAKT.iso') -Value 'rom' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $ps3Root 'Sacred_2_Fallen_Angel_BLES00410.iso') -Value 'rom' -Encoding ASCII

    $settings = New-RomCuratorDefaultSettings
    $settings.GamelistsRoot = Join-Path $fixtures 'gamelists'
    $settings.RomsRoot = $romRoot
    $settings.MediaRoot = ''
    $settings.MediaMode = 'BesideRoms'
    $settings.ExportDestination = Join-Path $tmpRoot 'export'
    $settings.ExportProfile = 'windows'
    $settings.MinimumRatingConfidence = 0.82
    $scan = Invoke-RomCuratorLibraryScan -Settings $settings -MetacriticPath $ratingsFixture
    Assert-True ($scan.Items.Count -ge 4) 'Scan should include matched, missing, recovered, and orphan rows.'
    $zelda = $scan.Items | Where-Object CleanName -eq 'The Legend of Zelda: Ocarina of Time' | Select-Object -First 1
    Assert-True ($null -ne $zelda) 'Zelda row missing.'
    Assert-Equal 99 $zelda.CriticScore 'Zelda rating not matched.'
    Assert-True $zelda.HasImage 'Zelda image not resolved.'
    Assert-True $zelda.HasVideo 'Zelda video not resolved.'
    $missing = $scan.Items | Where-Object { $_.IssuesText -like '*Missing ROM*' } | Select-Object -First 1
    Assert-True ($null -ne $missing) 'Missing ROM issue not recorded.'
    $sacred = $scan.Items | Where-Object CleanName -eq 'Sacred 2: Fallen Angel' | Select-Object -First 1
    Assert-Equal 71 $sacred.CriticScore 'Orphan Sacred rating not matched.'
}

Invoke-Test 'auto-selection and export dry-run write manifests safely' {
    $romRoot = Join-Path $tmpRoot 'roms'
    $settings = New-RomCuratorDefaultSettings
    $settings.GamelistsRoot = Join-Path $fixtures 'gamelists'
    $settings.RomsRoot = $romRoot
    $settings.MediaRoot = ''
    $settings.MediaMode = 'BesideRoms'
    $settings.ExportDestination = Join-Path $tmpRoot 'export'
    $settings.ExportProfile = 'windows'
    $settings.OverwritePolicy = 'Skip'
    $scan = Invoke-RomCuratorLibraryScan -Settings $settings -MetacriticPath $ratingsFixture
    $summary = Select-RomCuratorByCriteria -Items $scan.Items -MinimumScore 80 -ExcludeUnmatched
    Assert-Equal 1 $summary.SelectedCount 'Auto-selection should select one high-score game.'
    $plan = Get-RomCuratorExportPlan -Items $scan.Items -Settings $settings -IncludeMedia -IncludeGamelists
    Assert-Equal 1 $plan.SelectedCount 'Export plan selected count mismatch.'
    $export = Invoke-RomCuratorExport -Plan $plan -AllItems $scan.Items -OverwritePolicy Skip -DryRun
    Assert-True (Test-Path -LiteralPath $export.Manifest.Json) 'Dry-run manifest JSON was not written.'
    Assert-True (Test-Path -LiteralPath $export.Manifest.Csv) 'Dry-run manifest CSV was not written.'
}

Invoke-Test 'full-system export planning ignores filtered/manual item selection' {
    $settings = New-RomCuratorDefaultSettings
    $settings.ExportDestination = Join-Path $tmpRoot 'full-system-export'
    $settings.ExportProfile = 'windows'
    $items = @(
        [pscustomobject]@{ System='gc'; CleanName='Game A'; OriginalName='Game A.iso'; RomPath='R:\roms\gc\Game A.iso'; RelativePath='Game A.iso'; FileSize=[int64]100; MediaSize=[int64]0; Extension='.iso'; IsFolder=$false; Selected=$false },
        [pscustomobject]@{ System='gc'; CleanName='Game B'; OriginalName='Game B.iso'; RomPath='R:\roms\gc\Game B.iso'; RelativePath='Game B.iso'; FileSize=[int64]200; MediaSize=[int64]0; Extension='.iso'; IsFolder=$false; Selected=$false },
        [pscustomobject]@{ System='ps2'; CleanName='Filtered Manual'; OriginalName='Filtered Manual.iso'; RomPath='R:\roms\ps2\Filtered Manual.iso'; RelativePath='Filtered Manual.iso'; FileSize=[int64]300; MediaSize=[int64]0; Extension='.iso'; IsFolder=$false; Selected=$true }
    )
    $plan = Get-RomCuratorExportPlan -Items $items -Settings $settings -FullSystems @('gc') -IgnoreItemSelection
    Assert-Equal 'FullSystems' $plan.PlanMode 'Full-system export plan mode mismatch.'
    Assert-Equal 2 $plan.SelectedCount 'Full-system export should include every copyable game in selected system only.'
    Assert-Equal 300 $plan.TotalBytes 'Full-system export size should ignore filtered/manual ps2 item.'
    Assert-Equal 0 @($plan.CopyItems | Where-Object System -eq 'ps2').Count 'Full-system-only export should not include manually selected ps2 item.'
}

Invoke-Test 'empty selection summary and cache round-trip are safe' {
    $emptySummary = Get-RomCuratorSelectionSummary -Items @()
    Assert-Equal 0 $emptySummary.SelectedCount 'Empty summary selected count should be zero.'
    Assert-Equal 0 $emptySummary.TotalSize 'Empty summary total size should be zero.'

    $settings = New-RomCuratorDefaultSettings
    $settings.GamelistsRoot = Join-Path $fixtures 'gamelists'
    $settings.RomsRoot = Join-Path $tmpRoot 'roms'
    $settings.MediaRoot = ''
    $settings.MediaMode = 'BesideRoms'
    $settings.ExportDestination = Join-Path $tmpRoot 'export'
    $settings.ExportProfile = 'windows'
    $settings.RatingFilePath = $ratingsFixture
    $scan = Invoke-RomCuratorLibraryScan -Settings $settings -MetacriticPath $ratingsFixture
    $cachePath = Join-Path $tmpRoot 'library_cache.json'
    $saved = Save-RomCuratorLibraryCache -ScanResult $scan -Settings $settings -Path $cachePath
    Assert-True (Test-Path -LiteralPath $saved.Path) 'Cache file was not written.'
    $loaded = Load-RomCuratorLibraryCache -Settings $settings -Path $cachePath
    Assert-True $loaded.Loaded 'Cache should load.'
    Assert-True $loaded.Valid 'Cache should validate.'
    Assert-Equal @($scan.Items).Count @($loaded.Items).Count 'Cache item count mismatch.'
    $changed = @(Get-RomCuratorChangedSystems -Cache $loaded.Cache -Settings $settings)
    Assert-Equal 0 $changed.Count 'Fresh cache should not report changed systems.'
}

Invoke-Test 'user and community presets save/load with correct privacy behavior' {
    $oldAppData = $env:APPDATA
    $env:APPDATA = Join-Path $tmpRoot 'appdata'
    try {
        $items = @(
            [pscustomobject]@{ System='gc'; CleanName='Game Name'; OriginalName='Game Name.iso'; RomPath='C:\Users\Rollza\ROMs\gc\Game Name.iso'; RelativePath='Game Name.iso'; CriticScore=91; FileSize=[int64]100; MediaSize=[int64]0; Genre='Action'; Players='1'; Selected=$true; Extension='.iso'; HasImage=$true; HasVideo=$false },
            [pscustomobject]@{ System='n64'; CleanName='Other Game'; OriginalName='Other Game.z64'; RomPath='R:\Emulation\roms\n64\Other Game.z64'; RelativePath='Other Game.z64'; CriticScore=95; FileSize=[int64]50; MediaSize=[int64]0; Genre='Adventure'; Players='2'; Selected=$false; Extension='.z64'; HasImage=$true; HasVideo=$false }
        )
        Update-RomCuratorDuplicateGroups -Items $items | Out-Null
        $settings = New-RomCuratorDefaultSettings
        $settings.RomsRoot = 'C:\Users\Rollza\ROMs'
        $user = Save-RomCuratorUserPreset -Items $items -Name 'Personal' -Settings $settings -AppVersion 'test'
        $userRaw = Get-Content -LiteralPath $user.Path -Raw
        Assert-True ($userRaw -like '*C:\\Users\\Rollza\\ROMs*') 'User preset should keep full personal paths.'

        $community = Save-RomCuratorCommunityPreset -Items $items -Name 'Shareable' -AppVersion 'test'
        $communityRaw = Get-Content -LiteralPath $community.Path -Raw
        Assert-True ($communityRaw -notmatch '[A-Za-z]:\\') 'Community preset should not contain drive-letter paths.'
        Assert-True ($communityRaw -notmatch 'Users\\') 'Community preset should not contain user folders.'

        foreach ($item in $items) { $item.Selected = $false }
        $summary = Load-RomCuratorSelectionPreset -Items $items -Path $community.Path
        Assert-Equal 1 $summary.SelectedCount 'Community preset should match by normalized cleaned title.'
        Assert-Equal 1 $summary.PresetMatches.Matched 'Community preset match count mismatch.'
    } finally {
        $env:APPDATA = $oldAppData
    }
}

Write-Host ""
Write-Host "Assertions passed: $script:Passed" -ForegroundColor Cyan
if ($script:Failed -gt 0) {
    Write-Host "Tests failed: $script:Failed" -ForegroundColor Red
    exit 1
}
Write-Host "All tests passed." -ForegroundColor Green
