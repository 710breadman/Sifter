Set-StrictMode -Version Latest
try { Add-Type -AssemblyName System.Xml.Linq -ErrorAction Stop } catch {}

$script:ModuleRoot = $PSScriptRoot
$script:DefaultRatingFile = Join-Path $script:ModuleRoot 'data\metacritic_game_critic_scores.jsonl'
$script:CacheSchemaVersion = 2
$script:NameNormalizeCache = @{}
$script:RatingMatchCache = @{}
$script:MediaIndexCache = @{}
$script:MetacriticLineRegex = [regex]::new('"rank"\s*:\s*(?<rank>null|\d+)[\s\S]*?"title"\s*:\s*"(?<title>(?:\\.|[^"\\])*)"[\s\S]*?"release_date_text"\s*:\s*(?<release>null|"(?<releaseText>(?:\\.|[^"\\])*)")[\s\S]*?"rating"\s*:\s*(?<rating>null|"(?<ratingText>(?:\\.|[^"\\])*)")[\s\S]*?"metascore"\s*:\s*(?<score>\d+)[\s\S]*?"detail_url"\s*:\s*(?<detail>null|"(?<detailText>(?:\\.|[^"\\])*)")[\s\S]*?"parse_confidence"\s*:\s*(?<confidence>\d+(?:\.\d+)?)', [System.Text.RegularExpressions.RegexOptions]::Compiled)

function Get-RomCuratorAppDataPath {
    param([string]$ChildPath)
    $root = Join-Path $env:APPDATA 'RomCurator'
    if ($ChildPath) { return (Join-Path $root $ChildPath) }
    return $root
}

function Ensure-RomCuratorDirectory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        [void](New-Item -ItemType Directory -Path $Path -Force)
    }
    return (Resolve-Path -LiteralPath $Path).ProviderPath
}

function Get-RomCuratorCacheFolder {
    Ensure-RomCuratorDirectory (Get-RomCuratorAppDataPath 'cache') | Out-Null
    return (Get-RomCuratorAppDataPath 'cache')
}

function Get-RomCuratorLogFolder {
    Ensure-RomCuratorDirectory (Get-RomCuratorAppDataPath 'logs') | Out-Null
    return (Get-RomCuratorAppDataPath 'logs')
}

function Get-RomCuratorLibraryCachePath {
    return (Join-Path (Get-RomCuratorCacheFolder) 'library_cache.json')
}

function Get-RomCuratorCachedRatingPath {
    return (Join-Path (Get-RomCuratorCacheFolder) 'metacritic_game_critic_scores.jsonl')
}

function Initialize-RomCuratorMetacriticData {
    param([object]$Settings)
    $target = Get-RomCuratorCachedRatingPath
    if (-not (Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $script:DefaultRatingFile)) {
        Copy-Item -LiteralPath $script:DefaultRatingFile -Destination $target -Force
    }
    if ($Settings) {
        if ($null -eq $Settings.PSObject.Properties['RatingFilePath']) {
            Add-Member -InputObject $Settings -NotePropertyName RatingFilePath -NotePropertyValue $target
        } elseif ((-not $Settings.RatingFilePath) -or -not (Test-Path -LiteralPath $Settings.RatingFilePath)) {
            $Settings.RatingFilePath = $target
        }
    }
    return $target
}

function Get-RomCuratorMetacriticInfo {
    param([string]$Path = (Get-RomCuratorCachedRatingPath))
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Path=$Path; Exists=$false; Count=0; LastWriteTime=$null; Version='Unavailable' }
    }
    $count = 0
    try {
        foreach ($line in [IO.File]::ReadLines($Path)) {
            if (-not [string]::IsNullOrWhiteSpace($line)) { $count++ }
        }
    } catch {}
    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Path = $Path
        Exists = $true
        Count = $count
        LastWriteTime = if ($item) { $item.LastWriteTime } else { $null }
        Version = if ($item) { "$count records, $($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" } else { "$count records" }
    }
}

function Copy-RomCuratorBundledMetacriticData {
    $target = Get-RomCuratorCachedRatingPath
    if (Test-Path -LiteralPath $script:DefaultRatingFile) {
        if (Test-Path -LiteralPath $target) {
            $backup = "$target.backup.$(Get-Date -Format yyyyMMddHHmmss)"
            Copy-Item -LiteralPath $target -Destination $backup -Force
        }
        Copy-Item -LiteralPath $script:DefaultRatingFile -Destination $target -Force
    }
    return $target
}

function Get-RomCuratorPathStamp {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Path=$Path; Exists=$false; LastWriteUtc=$null; LastWriteUtcTicks=$null; Length=$null }
    }
    try {
        $item = Get-Item -LiteralPath $Path -Force
        [pscustomobject]@{
            Path = $item.FullName
            Exists = $true
            LastWriteUtc = $item.LastWriteTimeUtc.ToString('o')
            LastWriteUtcTicks = $item.LastWriteTimeUtc.Ticks
            Length = if ($item.PSIsContainer) { $null } else { [int64]$item.Length }
        }
    } catch {
        [pscustomobject]@{ Path=$Path; Exists=$false; LastWriteUtc=$null; LastWriteUtcTicks=$null; Length=$null }
    }
}

function Get-RomCuratorSettingsSignature {
    param([Parameter(Mandatory)][object]$Settings)
    [pscustomobject]@{
        GamelistsRoot = [string]$Settings.GamelistsRoot
        RomsRoot = [string]$Settings.RomsRoot
        MediaRoot = [string]$Settings.MediaRoot
        MediaMode = [string]$Settings.MediaMode
        RatingFilePath = [string]$Settings.RatingFilePath
    }
}

function ConvertTo-RomCuratorJson {
    param([Parameter(ValueFromPipeline)][object]$InputObject)
    begin { $items = New-Object System.Collections.Generic.List[object] }
    process {
        [void]$items.Add($InputObject)
    }
    end {
        if ($items.Count -eq 1) {
            $items[0] | ConvertTo-Json -Depth 20
        } else {
            @($items) | ConvertTo-Json -Depth 20
        }
    }
}

function Get-RomCuratorMeasureSum {
    param(
        [object[]]$Items,
        [Parameter(Mandatory)][string]$Property
    )
    $total = [double]0
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        $prop = $item.PSObject.Properties[$Property]
        if ($prop -and $null -ne $prop.Value -and "$($prop.Value)" -ne '') {
            try { $total += [double]$prop.Value } catch {}
        }
    }
    return $total
}

function New-RomCuratorDefaultSettings {
    $roaming = $env:APPDATA
    $emuDeckEsDe = if ($roaming) {
        Join-Path $roaming 'EmuDeck\EmulationStation-DE\ES-DE\gamelists'
    } else { '' }

    $defaultRoms = @(
        'R:\Emulation\roms',
        'D:\Emulation\roms',
        'E:\Emulation\roms',
        'C:\Emulation\roms'
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    $defaultMedia = @(
        'R:\Emulation\storage\downloaded_media',
        'D:\Emulation\storage\downloaded_media',
        'E:\Emulation\storage\downloaded_media'
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    [pscustomobject]@{
        SchemaVersion = 1
        GamelistsRoot = if (Test-Path -LiteralPath $emuDeckEsDe) { $emuDeckEsDe } else { '' }
        RomsRoot = if ($defaultRoms) { $defaultRoms } else { '' }
        MediaRoot = if ($defaultMedia) { $defaultMedia } else { '' }
        MediaMode = 'AutoDetect'
        ExportDestination = ''
        ExportProfile = 'es-de'
        IncludeMediaByDefault = $true
        IncludeGamelistsByDefault = $true
        OverwritePolicy = 'Skip'
        MinimumRatingConfidence = 0.82
        MatchCacheEnabled = $true
        SystemAliasesPath = Join-Path $script:ModuleRoot 'data\system_aliases.json'
        ExportProfilesPath = Join-Path $script:ModuleRoot 'data\export_profiles.json'
        RatingFilePath = Get-RomCuratorCachedRatingPath
        LibraryCachePath = Get-RomCuratorLibraryCachePath
        RecentSelectionPreset = ''
        Theme = 'System'
        DarkMode = $true
        ExcludedSystems = @()
    }
}

function Save-RomCuratorSettings {
    param([Parameter(Mandatory)][object]$Settings)
    $path = Get-RomCuratorAppDataPath 'settings.json'
    Ensure-RomCuratorDirectory (Split-Path -Parent $path) | Out-Null
    $Settings | ConvertTo-RomCuratorJson | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Load-RomCuratorSettings {
    $default = New-RomCuratorDefaultSettings
    $path = Get-RomCuratorAppDataPath 'settings.json'
    if (-not (Test-Path -LiteralPath $path)) { return $default }

    try {
        $loaded = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        foreach ($prop in $default.PSObject.Properties.Name) {
            if ($null -eq $loaded.PSObject.Properties[$prop]) {
                Add-Member -InputObject $loaded -NotePropertyName $prop -NotePropertyValue $default.$prop
            }
        }
        return $loaded
    } catch {
        $backup = "$path.bad.$(Get-Date -Format yyyyMMddHHmmss)"
        try { Copy-Item -LiteralPath $path -Destination $backup -Force } catch {}
        return $default
    }
}

function Export-RomCuratorConfig {
    param(
        [Parameter(Mandatory)][object]$Settings,
        [Parameter(Mandatory)][string]$Path
    )
    Ensure-RomCuratorDirectory (Split-Path -Parent ([IO.Path]::GetFullPath($Path))) | Out-Null
    $Settings | ConvertTo-RomCuratorJson | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Import-RomCuratorConfig {
    param([Parameter(Mandatory)][string]$Path)
    Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}

function Get-RomCuratorDefaultSystemAliases {
    [ordered]@{
        'gc' = @('gamecube','ngc','nintendo gamecube')
        'genesis' = @('megadrive','md','sega genesis','sega megadrive')
        'xbox360' = @('x360','xbox 360','xb360')
        'psx' = @('ps1','playstation','playstation 1','sony playstation')
        'n64' = @('nintendo64','nintendo 64')
        'snes' = @('sfc','super nintendo','super famicom')
        'nes' = @('famicom','nintendo entertainment system')
        'arcade' = @('mame','fbneo','fba','finalburn neo')
        'tg16' = @('pcengine','pc engine','turbografx16','turbografx-16')
        'dreamcast' = @('dc','sega dreamcast')
        'switch' = @('nsw','nintendo switch')
        'wiiu' = @('wii u','nintendo wii u')
        '3ds' = @('n3ds','nintendo 3ds')
        'nds' = @('ds','nintendo ds')
        'ps2' = @('playstation2','playstation 2')
        'ps3' = @('playstation3','playstation 3')
        'psp' = @('playstation portable')
    }
}

function Get-RomCuratorSystemAliases {
    param([object]$Settings)
    $map = Get-RomCuratorDefaultSystemAliases
    $path = if ($Settings -and $Settings.PSObject.Properties['SystemAliasesPath']) { $Settings.SystemAliasesPath } else { $null }
    if ($path -and (Test-Path -LiteralPath $path)) {
        try {
            $custom = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop
            foreach ($p in $custom.PSObject.Properties) {
                $map[$p.Name] = @($p.Value)
            }
        } catch {}
    }
    return $map
}

function Save-RomCuratorSystemAliases {
    param(
        [Parameter(Mandatory)][object]$Aliases,
        [string]$Path = (Join-Path $script:ModuleRoot 'data\system_aliases.json')
    )
    Ensure-RomCuratorDirectory (Split-Path -Parent $Path) | Out-Null
    $Aliases | ConvertTo-RomCuratorJson | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Normalize-RomCuratorSystemName {
    param([AllowNull()][string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return '' }
    $value = $Name.ToLowerInvariant()
    $value = $value -replace '&',' and '
    $value = $value -replace '[^a-z0-9]+',' '
    $value = ($value -replace '\s+',' ').Trim()
    return $value
}

function Resolve-RomCuratorSystemAlias {
    param(
        [Parameter(Mandatory)][string]$System,
        [object]$Settings,
        [hashtable]$AliasMap
    )
    if (-not $AliasMap) { $AliasMap = Get-RomCuratorSystemAliases -Settings $Settings }
    $key = Normalize-RomCuratorSystemName $System
    foreach ($canonical in $AliasMap.Keys) {
        if ((Normalize-RomCuratorSystemName $canonical) -eq $key) { return $canonical }
        foreach ($alias in @($AliasMap[$canonical])) {
            if ((Normalize-RomCuratorSystemName $alias) -eq $key) { return $canonical }
        }
    }
    return ($System -replace '\s+','').ToLowerInvariant()
}

function Get-RomCuratorKnownTagPattern {
    $tags = @(
        'usa','us','eur','europe','jpn','japan','jp','world','asia','kor','korea','chn','china','tw','taiwan',
        'aus','australia','can','canada','germany','de','fr','france','italy','it','spain','es','uk','pal','ntsc',
        'rev[0-9a-z]*','beta','demo','proto','prototype','sample','trial','preview','press','proper','repack',
        'multi[0-9]*','multilanguage','english','en','fr','de','es','it','nl','pt','ru','ja','ko','zh',
        'ps3','ps2','ps1','ps4','ps5','xbox','xbox360','xb360','x360','xbla','switch','nsw','wii','wiiu','gc','ngc',
        'n64','nds','3ds','snes','nes','gba','gbc','gb','dreamcast','dc','pc','windows','linux',
        'scene','scenegroup','scenegrp','duplex','abstrakt','complex','imars','venom','caravan','lightforce','paradox','kalisto','razor1911',
        'flt','codex','plaza','reloaded','skidrow','prophet','hoodlum','cpy','vimm','redump','nointro','no-intro'
    )
    return "(?i)^($($tags -join '|'))$"
}

function Convert-RomCuratorRomanToken {
    param([string]$Token)
    $roman = @{
        'i'=1; 'ii'=2; 'iii'=3; 'iv'=4; 'v'=5; 'vi'=6; 'vii'=7; 'viii'=8; 'ix'=9; 'x'=10
        'xi'=11; 'xii'=12; 'xiii'=13; 'xiv'=14; 'xv'=15
    }
    $lower = $Token.ToLowerInvariant()
    if ($roman.ContainsKey($lower)) { return [string]$roman[$lower] }
    return $Token
}

function Get-RomCuratorTitleCase {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $textInfo = [Globalization.CultureInfo]::InvariantCulture.TextInfo
    $small = @('a','an','and','as','at','but','by','for','from','in','into','nor','of','on','or','the','to','vs','with')
    $forceUpper = @('nba','nfl','nhl','mlb','fifa','ufc','usa','dx','hd','vr','ds','wii','wwe','wwf','atv','mx','ssx','nfs','rpg','mmorpg','fps')
    $tokens = $Value.ToLowerInvariant().Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
    $out = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $token = $tokens[$i]
        if ($forceUpper -contains $token) {
            $out.Add($token.ToUpperInvariant())
        } elseif (($small -contains $token) -and $i -gt 0 -and $i -lt ($tokens.Count - 1)) {
            $out.Add($token)
        } elseif ($token -match '^\d+k\d*$') {
            $out.Add($token.ToUpperInvariant())
        } else {
            $out.Add($textInfo.ToTitleCase($token))
        }
    }
    return ($out -join ' ')
}

function Remove-RomCuratorExtension {
    param([string]$Name)
    $known = @(
        '.nkit.iso','.xiso.iso','.tar.gz','.zip','.7z','.rar','.iso','.cso','.chd','.rvz','.wbfs','.gcm','.gcz',
        '.nes','.sfc','.smc','.fig','.gba','.gbc','.gb','.n64','.z64','.v64','.nds','.3ds','.cia','.xci','.nsp',
        '.bin','.cue','.m3u','.ccd','.img','.sub','.pbp','.pkg','.rap','.elf','.dol','.xbe','.xex','.app','.wad',
        '.md','.gen','.sms','.gg','.32x','.a26','.a52','.a78','.lnx','.pce','.ngp','.ngc','.ws','.wsc','.col',
        '.dsk','.tap','.tzx','.rom','.neo','.iso.dec'
    )
    $result = $Name
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($ext in $known) {
            if ($result.EndsWith($ext, [StringComparison]::OrdinalIgnoreCase)) {
                $result = $result.Substring(0, $result.Length - $ext.Length)
                $changed = $true
                break
            }
        }
    }
    return $result
}

function Get-RomCuratorBaseName {
    param([AllowNull()][string]$PathOrName)
    if ([string]::IsNullOrWhiteSpace($PathOrName)) { return '' }
    $name = $PathOrName
    if ($PathOrName -match '[\\/]') {
        try { $name = [IO.Path]::GetFileName($PathOrName.Trim()) } catch {}
        if ([string]::IsNullOrWhiteSpace($name)) {
            try { $name = Split-Path -Leaf $PathOrName } catch {}
        }
    }
    return (Remove-RomCuratorExtension $name)
}

function Normalize-RomCuratorGameName {
    param(
        [AllowNull()][string]$Name,
        [switch]$ForKey
    )
    if ([string]::IsNullOrWhiteSpace($Name)) { return '' }
    $cacheKey = "$(if ($ForKey) { 'K' } else { 'D' })|$Name"
    if ($script:NameNormalizeCache.ContainsKey($cacheKey)) { return $script:NameNormalizeCache[$cacheKey] }

    $base = Get-RomCuratorBaseName $Name
    $base = [Uri]::UnescapeDataString($base)
    $base = $base -replace '\[[^\]]*\]', ' '
    $base = [regex]::Replace($base, '\(([^)]*)\)', {
        param([System.Text.RegularExpressions.Match]$m)
        $inner = $m.Groups[1].Value.Trim()
        if ($inner -match '^\d{4}$') {
            if ($ForKey) { " $inner " } else { ' ' }
        } else { ' ' }
    })
    $base = $base -replace '\{[^}]*\}', ' '
    $base = $base -replace '(?i)\b(BL[EUJ][SM]\d{5}|BC[AEUJ][SM]\d{5}|NP[AEUJ][ABH]\d{5}|BLES\d{5}|BLUS\d{5}|BCES\d{5}|BCUS\d{5}|NPEB\d{5}|NPUB\d{5}|CUSA\d{5}|SLUS[-_ ]?\d{3,5}|SLES[-_ ]?\d{3,5}|SCUS[-_ ]?\d{3,5}|SCES[-_ ]?\d{3,5}|ULUS[-_ ]?\d{5})\b',' '
    $base = $base -replace '(?i)\b(disc|disk|cd|dvd)\s*[0-9ivx]+\b',' '
    $base = $base -replace '(?i)\bpart\s*[0-9ivx]+\b',' '
    $base = $base -replace '(?i)(^|[\s._-])v[0-9]+(?:\.[0-9]+)+(?=$|[\s._-])',' '
    $base = $base -replace '[_\.]+',' '
    $base = $base -replace '\s+-\s+',' - '
    $base = $base -replace '-([A-Z0-9]{3,}|[A-Z][A-Z0-9]+)$',' '
    $base = $base -replace '(?i)(^|[\s._-])v(?:er(?:sion)?)?\.?\s*[0-9]+(?:[\._-][0-9]+)*\b',' '
    $base = $base -replace '[,;!]+',' '
    $base = $base -replace '\s+',' '
    $base = $base.Trim(' ', '-', '_', '.')

    $tagPattern = Get-RomCuratorKnownTagPattern
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($token in $base.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) {
        $trimmed = $token.Trim('-', '_', '.', ',', ';')
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match $tagPattern) { continue }
        if ($trimmed -match '^[A-Z]{2,4}[0-9]{2,6}$') { continue }
        if ($ForKey) { $trimmed = Convert-RomCuratorRomanToken $trimmed }
        $kept.Add($trimmed)
    }

    $clean = (($kept.ToArray()) -join ' ')
    $clean = $clean -replace '\s+',' '
    $clean = $clean.Trim()

    if ($ForKey) {
        $clean = $clean.ToLowerInvariant()
        $clean = $clean -replace '&',' and '
        $clean = $clean -replace '(?i)\bthe\b',' the '
        $clean = $clean -replace '[^a-z0-9]+',' '
        $clean = $clean -replace '\s+',' '
        $clean = $clean.Trim()
        $script:NameNormalizeCache[$cacheKey] = $clean
        return $clean
    }

    $clean = Get-RomCuratorTitleCase $clean
    if ($clean -match '^(.+\s\d+)\s+([A-Z][a-z]+ .+)$' -and $clean -notmatch ':') {
        $clean = "$($Matches[1]): $($Matches[2])"
    }
    $script:NameNormalizeCache[$cacheKey] = $clean
    return $clean
}

function Get-RomCuratorNameKeyVariants {
    param([AllowNull()][string]$Name)
    $key = Normalize-RomCuratorGameName -Name $Name -ForKey
    $variants = New-Object System.Collections.Generic.List[string]
    function Add-LocalVariant([string]$Value) {
        if (-not [string]::IsNullOrWhiteSpace($Value)) {
            $cleanValue = ($Value -replace '\s+',' ').Trim()
            if (-not $variants.Contains($cleanValue)) { [void]$variants.Add($cleanValue) }
        }
    }
    Add-LocalVariant $key
    if ($key -match '^the\s+(.+)$') { Add-LocalVariant $Matches[1] }
    if ($key -match '^(.+)\s+the$') { Add-LocalVariant "the $($Matches[1])" }
    if ($key -match '^(.+)\s+(\d{4})$') { Add-LocalVariant $Matches[1] }
    if ($key -match '^(.+)\s+goty$') { Add-LocalVariant $Matches[1] }
    foreach ($v in @($variants.ToArray())) {
        $withoutAnd = (($v -replace '\band\b','') -replace '\s+',' ').Trim()
        $versus = (($v -replace '\bvs\b','versus') -replace '\s+',' ').Trim()
        Add-LocalVariant $withoutAnd
        Add-LocalVariant $versus
    }
    return @($variants.ToArray())
}

function Set-RomCuratorObjectProperty {
    param(
        [Parameter(Mandatory)][object]$Object,
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()]$Value
    )
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value -Force
    } else {
        $Object.$Name = $Value
    }
}

function Get-RomCuratorObjectProperty {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()]$Default = $null
    )
    if ($null -eq $Object) { return $Default }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Get-RomCuratorDuplicateKey {
    param(
        [Parameter(Mandatory)][object]$Item,
        [switch]$IncludeSystem
    )
    $name = [string](Get-RomCuratorObjectProperty -Object $Item -Name 'CleanName' -Default '')
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = [string](Get-RomCuratorObjectProperty -Object $Item -Name 'OriginalName' -Default '')
    }
    $key = Normalize-RomCuratorGameName -Name $name -ForKey
    if ([string]::IsNullOrWhiteSpace($key)) { $key = 'unknown' }
    if ($IncludeSystem) {
        return "$([string](Get-RomCuratorObjectProperty -Object $Item -Name 'System' -Default ''))|$key"
    }
    return $key
}

function Get-RomCuratorSystemPriority {
    param(
        [object]$Item,
        [string[]]$PreferredSystems
    )
    $system = [string](Get-RomCuratorObjectProperty -Object $Item -Name 'System' -Default '')
    if (-not $PreferredSystems -or $PreferredSystems.Count -eq 0) { return 9999 }
    for ($i = 0; $i -lt $PreferredSystems.Count; $i++) {
        if ($system -eq [string]$PreferredSystems[$i]) { return $i }
    }
    return 9999
}

function Select-RomCuratorBestDuplicate {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [string[]]$PreferredSystems
    )
    @($Items | Sort-Object `
        @{Expression={ -[int](Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default 0) }}, `
        @{Expression={ -[double](Get-RomCuratorObjectProperty -Object $_ -Name 'MatchConfidence' -Default 0) }}, `
        @{Expression={ if ("$(Get-RomCuratorObjectProperty -Object $_ -Name 'Favorite' -Default '')" -match '(?i)true|1|yes') { 0 } else { 1 } }}, `
        @{Expression={ if ((Get-RomCuratorObjectProperty -Object $_ -Name 'HasImage' -Default $false) -or (Get-RomCuratorObjectProperty -Object $_ -Name 'HasVideo' -Default $false)) { 0 } else { 1 } }}, `
        @{Expression={ Get-RomCuratorSystemPriority -Item $_ -PreferredSystems $PreferredSystems }}, `
        @{Expression={ [int64](Get-RomCuratorObjectProperty -Object $_ -Name 'FileSize' -Default 0) }}, `
        @{Expression={ [string](Get-RomCuratorObjectProperty -Object $_ -Name 'CleanName' -Default '') }} | Select-Object -First 1)
}

function Update-RomCuratorDuplicateGroups {
    param(
        [object[]]$Items,
        [string[]]$PreferredSystems
    )
    $groups = @{}
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        $key = Get-RomCuratorDuplicateKey -Item $item
        Set-RomCuratorObjectProperty -Object $item -Name 'NormalizedName' -Value $key
        Set-RomCuratorObjectProperty -Object $item -Name 'DuplicateKey' -Value $key
        if (-not $groups.ContainsKey($key)) { $groups[$key] = New-Object System.Collections.Generic.List[object] }
        $groups[$key].Add($item)
    }
    foreach ($key in $groups.Keys) {
        $group = @($groups[$key].ToArray())
        $best = Select-RomCuratorBestDuplicate -Items $group -PreferredSystems $PreferredSystems
        $ranked = @($group | Sort-Object `
            @{Expression={ if ($_ -eq $best) { 0 } else { 1 } }}, `
            @{Expression={ -[int](Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default 0) }}, `
            @{Expression={ -[double](Get-RomCuratorObjectProperty -Object $_ -Name 'MatchConfidence' -Default 0) }}, `
            @{Expression={ [int64](Get-RomCuratorObjectProperty -Object $_ -Name 'FileSize' -Default 0) }})
        $rank = 0
        foreach ($item in $ranked) {
            $rank++
            Set-RomCuratorObjectProperty -Object $item -Name 'DuplicateGroupSize' -Value $group.Count
            Set-RomCuratorObjectProperty -Object $item -Name 'IsDuplicate' -Value ($group.Count -gt 1)
            Set-RomCuratorObjectProperty -Object $item -Name 'DuplicateRank' -Value $rank
            Set-RomCuratorObjectProperty -Object $item -Name 'DuplicateNote' -Value $(if ($group.Count -gt 1) { if ($rank -eq 1) { 'Best duplicate' } else { 'Duplicate candidate' } } else { '' })
        }
    }
    return @($Items)
}

function Normalize-RomCuratorRatingTitleKey {
    param([AllowNull()][string]$Title)
    if ([string]::IsNullOrWhiteSpace($Title)) { return '' }
    $key = $Title.ToLowerInvariant()
    $key = $key -replace '&',' and '
    $key = $key -replace '\(([^)]*)\)', ' $1 '
    $key = [regex]::Replace($key, '\b(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xiii|xiv|xv)\b', {
        param($m)
        Convert-RomCuratorRomanToken $m.Value
    })
    $key = $key -replace '[^a-z0-9]+',' '
    $key = $key -replace '\s+',' '
    return $key.Trim()
}

function Get-RomCuratorRatingTitleVariants {
    param([AllowNull()][string]$Title)
    $key = Normalize-RomCuratorRatingTitleKey $Title
    $variants = New-Object System.Collections.Generic.List[string]
    function Add-RatingVariant([string]$Value) {
        if (-not [string]::IsNullOrWhiteSpace($Value)) {
            $cleanValue = ($Value -replace '\s+',' ').Trim()
            if (-not $variants.Contains($cleanValue)) { [void]$variants.Add($cleanValue) }
        }
    }
    Add-RatingVariant $key
    if ($key -match '^the\s+(.+)$') { Add-RatingVariant $Matches[1] }
    if ($key -match '^(.+)\s+(\d{4})$') { Add-RatingVariant $Matches[1] }
    foreach ($v in @($variants.ToArray())) {
        Add-RatingVariant (($v -replace '\band\b','') -replace '\s+',' ')
        Add-RatingVariant (($v -replace '\bvs\b','versus') -replace '\s+',' ')
    }
    return @($variants.ToArray())
}

function Get-RomCuratorPropertyValue {
    param(
        [Parameter(Mandatory)][object]$Object,
        [Parameter(Mandatory)][string[]]$Names
    )
    foreach ($name in $Names) {
        $prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
        if ($prop -and $null -ne $prop.Value -and "$($prop.Value)" -ne '') { return $prop.Value }
    }
    return $null
}

function Get-RomCuratorYear {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    if ($text -match '(19|20)\d{2}') { return [int]$Matches[0] }
    return $null
}

function ConvertFrom-RomCuratorJsonStringLiteral {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return $null }
    try { return ('"' + $Value + '"' | ConvertFrom-Json -ErrorAction Stop) } catch { return $Value }
}

function Get-RomCuratorJsonRegexValue {
    param(
        [Parameter(Mandatory)][string]$Line,
        [Parameter(Mandatory)][string]$Name
    )
    $needle = '"' + $Name + '":'
    $idx = $Line.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase)
    if ($idx -ge 0) {
        $pos = $idx + $needle.Length
        while ($pos -lt $Line.Length -and [char]::IsWhiteSpace($Line[$pos])) { $pos++ }
        if ($pos -lt $Line.Length) {
            if ($Line[$pos] -eq '"') {
                $pos++
                $start = $pos
                while ($pos -lt $Line.Length) {
                    $ch = $Line[$pos]
                    if ($ch -eq '"' -and ($pos -eq $start -or $Line[$pos - 1] -ne '\')) {
                        $rawString = $Line.Substring($start, $pos - $start)
                        if ($rawString.IndexOf('\', [StringComparison]::Ordinal) -ge 0) {
                            return ConvertFrom-RomCuratorJsonStringLiteral $rawString
                        }
                        return $rawString
                    }
                    $pos++
                }
            } else {
                $start = $pos
                while ($pos -lt $Line.Length -and $Line[$pos] -notin @(',', '}')) { $pos++ }
                $raw = $Line.Substring($start, $pos - $start).Trim()
                if ($raw -eq 'null') { return $null }
                if ($raw -eq 'true') { return $true }
                if ($raw -eq 'false') { return $false }
                if ($raw -match '\.') { try { return [double]$raw } catch {} }
                try { return [int64]$raw } catch { return $raw }
            }
        }
    }
    $m = [regex]::Match($Line, '"' + [regex]::Escape($Name) + '"\s*:\s*"(?<v>(?:\\.|[^"\\])*)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) { return ConvertFrom-RomCuratorJsonStringLiteral $m.Groups['v'].Value }
    $m = [regex]::Match($Line, '"' + [regex]::Escape($Name) + '"\s*:\s*(?<v>-?\d+(?:\.\d+)?|true|false|null)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        $raw = $m.Groups['v'].Value
        if ($raw -eq 'null') { return $null }
        if ($raw -eq 'true') { return $true }
        if ($raw -eq 'false') { return $false }
        if ($raw -match '\.') { return [double]$raw }
        return [int64]$raw
    }
    return $null
}

function ConvertFrom-RomCuratorMetacriticLineFast {
    param([Parameter(Mandatory)][string]$Line)
    $m = $script:MetacriticLineRegex.Match($Line)
    if ($m.Success) {
        $title = ConvertFrom-RomCuratorJsonStringLiteral $m.Groups['title'].Value
        $release = if ($m.Groups['releaseText'].Success) { ConvertFrom-RomCuratorJsonStringLiteral $m.Groups['releaseText'].Value } else { $null }
        $rating = if ($m.Groups['ratingText'].Success) { ConvertFrom-RomCuratorJsonStringLiteral $m.Groups['ratingText'].Value } else { $null }
        $detail = if ($m.Groups['detailText'].Success) { ConvertFrom-RomCuratorJsonStringLiteral $m.Groups['detailText'].Value } else { $null }
        $rank = if ($m.Groups['rank'].Value -ne 'null') { [int]$m.Groups['rank'].Value } else { $null }
        $score = [int]$m.Groups['score'].Value
        $parseConfidence = [double]$m.Groups['confidence'].Value
        return [pscustomobject]@{
            Title = [string]$title
            Key = Normalize-RomCuratorRatingTitleKey ([string]$title)
            Variants = @()
            Platform = ''
            PlatformKey = ''
            ReleaseYear = Get-RomCuratorYear $release
            ReleaseDateText = if ($release) { [string]$release } else { '' }
            Rating = if ($rating) { [string]$rating } else { '' }
            CriticScore = $score
            Rank = $rank
            DetailUrl = if ($detail) { [string]$detail } else { '' }
            ParseConfidence = $parseConfidence
            Source = [pscustomobject]@{ raw_json = $Line }
        }
    }
    $title = Get-RomCuratorJsonRegexValue -Line $Line -Name 'title'
    $score = Get-RomCuratorJsonRegexValue -Line $Line -Name 'metascore'
    if ([string]::IsNullOrWhiteSpace([string]$title) -or $null -eq $score) { return $null }
    $platform = Get-RomCuratorJsonRegexValue -Line $Line -Name 'platform'
    if ($null -eq $platform) { $platform = Get-RomCuratorJsonRegexValue -Line $Line -Name 'system' }
    $release = Get-RomCuratorJsonRegexValue -Line $Line -Name 'release_date_text'
    $rating = Get-RomCuratorJsonRegexValue -Line $Line -Name 'rating'
    $detail = Get-RomCuratorJsonRegexValue -Line $Line -Name 'detail_url'
    $rank = Get-RomCuratorJsonRegexValue -Line $Line -Name 'rank'
    $parseConfidence = Get-RomCuratorJsonRegexValue -Line $Line -Name 'parse_confidence'
    [pscustomobject]@{
        Title = [string]$title
        Key = Normalize-RomCuratorRatingTitleKey ([string]$title)
        Variants = @()
        Platform = if ($platform) { [string]$platform } else { '' }
        PlatformKey = Normalize-RomCuratorSystemName ([string]$platform)
        ReleaseYear = Get-RomCuratorYear $release
        ReleaseDateText = if ($release) { [string]$release } else { '' }
        Rating = if ($rating) { [string]$rating } else { '' }
        CriticScore = [int]$score
        Rank = if ($rank) { [int]$rank } else { $null }
        DetailUrl = if ($detail) { [string]$detail } else { '' }
        ParseConfidence = if ($parseConfidence) { [double]$parseConfidence } else { 1.0 }
        Source = [pscustomobject]@{ raw_json = $Line }
    }
}

function Import-RomCuratorMetacriticJsonl {
    param(
        [string]$Path = $script:DefaultRatingFile,
        [System.Collections.Generic.List[object]]$Warnings
    )
    $records = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($null -ne $Warnings) { $Warnings.Add([pscustomobject]@{ Severity='Warning'; Area='Metacritic'; Message="Ratings file not found: $Path"; Path=$Path }) }
        return $records
    }

    $lineNumber = 0
    foreach ($line in [IO.File]::ReadLines($Path)) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $fast = ConvertFrom-RomCuratorMetacriticLineFast -Line $line
            if ($fast) {
                $records.Add($fast)
                continue
            }

            $obj = $line | ConvertFrom-Json -ErrorAction Stop
            $title = Get-RomCuratorPropertyValue -Object $obj -Names @('title','name','game','game_title','gameName')
            $score = Get-RomCuratorPropertyValue -Object $obj -Names @('metascore','critic_score','criticScore','score','metacritic_score')
            if ([string]::IsNullOrWhiteSpace([string]$title) -or $null -eq $score) { continue }
            $platform = Get-RomCuratorPropertyValue -Object $obj -Names @('platform','system','console','platform_name')
            $release = Get-RomCuratorPropertyValue -Object $obj -Names @('release_date_text','releaseDate','release_date','date')
            $rating = Get-RomCuratorPropertyValue -Object $obj -Names @('rating','esrb','content_rating')
            $detail = Get-RomCuratorPropertyValue -Object $obj -Names @('detail_url','url','source_url')
            $rank = Get-RomCuratorPropertyValue -Object $obj -Names @('rank')
            $parseConfidence = Get-RomCuratorPropertyValue -Object $obj -Names @('parse_confidence','confidence')

            $records.Add([pscustomobject]@{
                Title = [string]$title
                Key = Normalize-RomCuratorRatingTitleKey ([string]$title)
                Variants = @()
                Platform = if ($platform) { [string]$platform } else { '' }
                PlatformKey = Normalize-RomCuratorSystemName ([string]$platform)
                ReleaseYear = Get-RomCuratorYear $release
                ReleaseDateText = if ($release) { [string]$release } else { '' }
                Rating = if ($rating) { [string]$rating } else { '' }
                CriticScore = [int]$score
                Rank = if ($rank) { [int]$rank } else { $null }
                DetailUrl = if ($detail) { [string]$detail } else { '' }
                ParseConfidence = if ($parseConfidence) { [double]$parseConfidence } else { 1.0 }
                Source = $obj
            })
        } catch {
            if ($null -ne $Warnings) { $Warnings.Add([pscustomobject]@{ Severity='Warning'; Area='Metacritic'; Message="Bad JSON at line ${lineNumber}: $($_.Exception.Message)"; Path=$Path }) }
        }
    }
    return $records
}

function New-RomCuratorRatingIndex {
    param([Parameter(Mandatory)][object[]]$Records)
    $script:RatingMatchCache = @{}
    $byKey = @{}
    $byFirstToken = @{}
    foreach ($record in $Records) {
        $variants = @()
        if ($record.PSObject.Properties['Variants'] -and @($record.Variants).Count -gt 0) {
            $variants = @($record.Variants)
        } else {
            $baseKey = if ($record.PSObject.Properties['Key'] -and $record.Key) { [string]$record.Key } else { Normalize-RomCuratorRatingTitleKey $record.Title }
            $variantList = New-Object System.Collections.Generic.List[string]
            function Add-IndexVariant([string]$Value) {
                if (-not [string]::IsNullOrWhiteSpace($Value)) {
                    $cleanValue = ($Value -replace '\s+',' ').Trim()
                    if (-not $variantList.Contains($cleanValue)) { [void]$variantList.Add($cleanValue) }
                }
            }
            Add-IndexVariant $baseKey
            if ($baseKey -match '^the\s+(.+)$') { Add-IndexVariant $Matches[1] }
            if ($baseKey -match '^(.+)\s+(\d{4})$') { Add-IndexVariant $Matches[1] }
            Add-IndexVariant (($baseKey -replace '\band\b','') -replace '\s+',' ')
            Add-IndexVariant (($baseKey -replace '\bvs\b','versus') -replace '\s+',' ')
            $variants = @($variantList.ToArray())
            try { $record.Variants = $variants } catch {}
        }
        foreach ($variant in $variants) {
            if (-not $byKey.ContainsKey($variant)) { $byKey[$variant] = New-Object System.Collections.Generic.List[object] }
            $byKey[$variant].Add($record)
            $first = ($variant -split '\s+')[0]
            if ($first) {
                if (-not $byFirstToken.ContainsKey($first)) { $byFirstToken[$first] = New-Object System.Collections.Generic.List[object] }
                $byFirstToken[$first].Add($record)
            }
        }
    }
    [pscustomobject]@{
        ByKey = $byKey
        ByFirstToken = $byFirstToken
        Count = $Records.Count
    }
}

function Get-RomCuratorLevenshteinDistance {
    param([string]$A, [string]$B)
    if ($A -eq $B) { return 0 }
    if ([string]::IsNullOrEmpty($A)) { return $B.Length }
    if ([string]::IsNullOrEmpty($B)) { return $A.Length }
    $n = $A.Length
    $m = $B.Length
    $d = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = 0; $i -le $n; $i++) { $d[$i,0] = $i }
    for ($j = 0; $j -le $m; $j++) { $d[0,$j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $cost = if ($A[($i - 1)] -eq $B[($j - 1)]) { 0 } else { 1 }
            $deleteCost = $d[($i - 1), $j] + 1
            $insertCost = $d[$i, ($j - 1)] + 1
            $replaceCost = $d[($i - 1), ($j - 1)] + $cost
            $d[$i,$j] = [Math]::Min([Math]::Min($deleteCost, $insertCost), $replaceCost)
        }
    }
    return $d[$n,$m]
}

function Get-RomCuratorSimilarity {
    param([string]$A, [string]$B)
    if ([string]::IsNullOrWhiteSpace($A) -or [string]::IsNullOrWhiteSpace($B)) { return 0.0 }
    if ($A -eq $B) { return 1.0 }
    $maxLen = [Math]::Max($A.Length, $B.Length)
    if ($maxLen -eq 0) { return 1.0 }
    $distance = Get-RomCuratorLevenshteinDistance $A $B
    $lev = 1.0 - ($distance / [double]$maxLen)
    $aTokens = @($A -split '\s+' | Where-Object { $_ })
    $bTokens = @($B -split '\s+' | Where-Object { $_ })
    $intersect = @($aTokens | Where-Object { $bTokens -contains $_ } | Select-Object -Unique).Count
    $union = @($aTokens + $bTokens | Select-Object -Unique).Count
    $jaccard = if ($union -gt 0) { $intersect / [double]$union } else { 0.0 }
    return [Math]::Max($lev, $jaccard)
}

function Select-RomCuratorBestPlatformCandidate {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        [string]$System
    )
    $systemKey = Normalize-RomCuratorSystemName $System
    $best = $null
    $bestScore = -1.0
    foreach ($candidate in $Candidates) {
        $platformScore = 0.0
        if ([string]::IsNullOrWhiteSpace($candidate.PlatformKey)) {
            $platformScore = 0.02
        } elseif ($candidate.PlatformKey -eq $systemKey -or $candidate.PlatformKey -like "*$systemKey*" -or $systemKey -like "*$($candidate.PlatformKey)*") {
            $platformScore = 0.08
        }
        $rankScore = if ($candidate.Rank) { [Math]::Max(0, 0.03 - ([double]$candidate.Rank / 1000000.0)) } else { 0.0 }
        $score = $platformScore + $rankScore + ([double]$candidate.ParseConfidence * 0.01)
        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $candidate
        }
    }
    return $best
}

function Find-RomCuratorRatingMatch {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$System,
        [Parameter(Mandatory)][object]$Index,
        [double]$MinimumConfidence = 0.82
    )
    $matchCacheKey = "$System|$MinimumConfidence|$Name"
    if ($script:RatingMatchCache.ContainsKey($matchCacheKey)) { return $script:RatingMatchCache[$matchCacheKey] }
    $variants = @(Get-RomCuratorNameKeyVariants $Name)
    foreach ($variant in $variants) {
        if ($Index.ByKey.ContainsKey($variant)) {
            $candidateList = $Index.ByKey[$variant]
            $record = Select-RomCuratorBestPlatformCandidate -Candidates @($candidateList.ToArray()) -System $System
            $exactMatch = [pscustomobject]@{
                CriticScore = $record.CriticScore
                TitleMatched = $record.Title
                Platform = $record.Platform
                ReleaseYear = $record.ReleaseYear
                DetailUrl = $record.DetailUrl
                MatchConfidence = 0.97
                MatchMethod = 'exact-normalized'
                Source = $record.Source
            }
            $script:RatingMatchCache[$matchCacheKey] = $exactMatch
            return $exactMatch
        }
    }

    $key = if ($variants.Count -gt 0) { $variants[0] } else { Normalize-RomCuratorGameName -Name $Name -ForKey }
    if ([string]::IsNullOrWhiteSpace($key)) { return $null }
    $first = ($key -split '\s+')[0]
    $candidates = @()
    if ($first -and $Index.ByFirstToken.ContainsKey($first)) { $candidates += @($Index.ByFirstToken[$first].ToArray()) }
    if ($key -match '^\w+\s+(.+)$') {
        $second = ($Matches[1] -split '\s+')[0]
        if ($second -and $Index.ByFirstToken.ContainsKey($second)) { $candidates += @($Index.ByFirstToken[$second].ToArray()) }
    }
    $candidates = @($candidates | Select-Object -Unique)
    if ($candidates.Count -eq 0) { return $null }

    $best = $null
    $bestConfidence = 0.0
    foreach ($candidate in $candidates) {
        foreach ($candidateKey in @($candidate.Variants)) {
            $similarity = Get-RomCuratorSimilarity $key $candidateKey
            if (-not [string]::IsNullOrWhiteSpace($System) -and -not [string]::IsNullOrWhiteSpace($candidate.PlatformKey)) {
                $systemKey = Normalize-RomCuratorSystemName $System
                if ($candidate.PlatformKey -eq $systemKey -or $candidate.PlatformKey -like "*$systemKey*") { $similarity += 0.03 }
            }
            if ($similarity -gt $bestConfidence) {
                $bestConfidence = $similarity
                $best = $candidate
            }
        }
    }

    if ($best -and $bestConfidence -ge $MinimumConfidence) {
        $fuzzyMatch = [pscustomobject]@{
            CriticScore = $best.CriticScore
            TitleMatched = $best.Title
            Platform = $best.Platform
            ReleaseYear = $best.ReleaseYear
            DetailUrl = $best.DetailUrl
            MatchConfidence = [Math]::Min(0.93, [Math]::Round($bestConfidence, 3))
            MatchMethod = 'fuzzy'
            Source = $best.Source
        }
        $script:RatingMatchCache[$matchCacheKey] = $fuzzyMatch
        return $fuzzyMatch
    }
    $script:RatingMatchCache[$matchCacheKey] = $null
    return $null
}

function ConvertTo-RomCuratorRelativePathKey {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $value = $Path.Trim()
    $value = $value -replace '^[\.\\/]+',''
    $value = $value -replace '/','\'
    $value = $value.ToLowerInvariant()
    $value = $value -replace '\\+','\'
    return $value.Trim('\')
}

function Resolve-RomCuratorSafePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [AllowNull()][string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Root) -or [string]::IsNullOrWhiteSpace($Path)) { return $null }
    try {
        $candidate = $Path.Trim()
        if ($candidate.StartsWith('~')) { return $null }
        if ([IO.Path]::IsPathRooted($candidate)) {
            $full = [IO.Path]::GetFullPath($candidate)
        } else {
            $candidate = $candidate -replace '^[\.\\/]+',''
            $full = [IO.Path]::GetFullPath((Join-Path $Root $candidate))
        }
        $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
        if ($full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase) -or $full.TrimEnd('\').Equals($rootFull.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
            return $full
        }
    } catch {}
    return $null
}

function Get-RomCuratorXmlChildValue {
    param(
        [Parameter(Mandatory)]$Node,
        [Parameter(Mandatory)][string]$Name
    )
    $child = $Node.Elements() | Where-Object { $_.Name.LocalName -ieq $Name } | Select-Object -First 1
    if ($child) { return [string]$child.Value }
    return ''
}

function New-RomCuratorGamelistEntry {
    param(
        [Parameter(Mandatory)]$GameNode,
        [string]$System,
        [string]$GamelistPath,
        [string]$RomSystemRoot
    )
    $fields = [ordered]@{}
    foreach ($element in $GameNode.Elements()) {
        $fields[$element.Name.LocalName] = [string]$element.Value
    }
    $path = if ($fields.Contains('path')) { $fields['path'] } else { '' }
    $name = if ($fields.Contains('name')) { $fields['name'] } else { Normalize-RomCuratorGameName $path }
    $resolved = Resolve-RomCuratorSafePath -Root $RomSystemRoot -Path $path
    [pscustomobject]@{
        System = $System
        Name = $name
        Path = $path
        RelativePathKey = ConvertTo-RomCuratorRelativePathKey $path
        ResolvedPath = $resolved
        Description = if ($fields.Contains('desc')) { $fields['desc'] } else { '' }
        Image = if ($fields.Contains('image')) { $fields['image'] } else { '' }
        Marquee = if ($fields.Contains('marquee')) { $fields['marquee'] } else { '' }
        Thumbnail = if ($fields.Contains('thumbnail')) { $fields['thumbnail'] } else { '' }
        Video = if ($fields.Contains('video')) { $fields['video'] } else { '' }
        Fanart = if ($fields.Contains('fanart')) { $fields['fanart'] } else { '' }
        Boxart = if ($fields.Contains('boxart')) { $fields['boxart'] } elseif ($fields.Contains('cover')) { $fields['cover'] } else { '' }
        Rating = if ($fields.Contains('rating')) { $fields['rating'] } else { '' }
        ReleaseDate = if ($fields.Contains('releasedate')) { $fields['releasedate'] } else { '' }
        Developer = if ($fields.Contains('developer')) { $fields['developer'] } else { '' }
        Publisher = if ($fields.Contains('publisher')) { $fields['publisher'] } else { '' }
        Genre = if ($fields.Contains('genre')) { $fields['genre'] } else { '' }
        Players = if ($fields.Contains('players')) { $fields['players'] } else { '' }
        Favorite = if ($fields.Contains('favorite')) { [string]$fields['favorite'] } else { '' }
        Hidden = if ($fields.Contains('hidden')) { [string]$fields['hidden'] } else { '' }
        KidGame = if ($fields.Contains('kidgame')) { [string]$fields['kidgame'] } else { '' }
        PlayCount = if ($fields.Contains('playcount')) { [string]$fields['playcount'] } else { '' }
        LastPlayed = if ($fields.Contains('lastplayed')) { [string]$fields['lastplayed'] } else { '' }
        Fields = $fields
        GamelistPath = $GamelistPath
    }
}

function Parse-RomCuratorGamelist {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$System,
        [Parameter(Mandatory)][string]$RomSystemRoot,
        [System.Collections.Generic.List[object]]$Warnings
    )
    $entries = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path)) { return $entries }

    try {
        $settings = [System.Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
        $settings.IgnoreComments = $true
        $settings.IgnoreWhitespace = $true
        $reader = [System.Xml.XmlReader]::Create($Path, $settings)
        try {
            $doc = [System.Xml.Linq.XDocument]::Load($reader)
        } finally {
            $reader.Dispose()
        }
        foreach ($game in $doc.Descendants() | Where-Object { $_.Name.LocalName -eq 'game' }) {
            $entries.Add((New-RomCuratorGamelistEntry -GameNode $game -System $System -GamelistPath $Path -RomSystemRoot $RomSystemRoot))
        }
    } catch {
        if ($null -ne $Warnings) { $Warnings.Add([pscustomobject]@{ Severity='Warning'; Area='Gamelist'; System=$System; Message="Malformed XML, attempting recovery: $($_.Exception.Message)"; Path=$Path }) }
        try {
            $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
            $matches = [regex]::Matches($raw, '<game\b[^>]*>.*?</game>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $matches) {
                try {
                    $fragment = "<gameList>$($match.Value)</gameList>"
                    $doc = [System.Xml.Linq.XDocument]::Parse($fragment)
                    $game = $doc.Descendants() | Where-Object { $_.Name.LocalName -eq 'game' } | Select-Object -First 1
                    if ($game) {
                        $entries.Add((New-RomCuratorGamelistEntry -GameNode $game -System $System -GamelistPath $Path -RomSystemRoot $RomSystemRoot))
                    }
                } catch {}
            }
        } catch {
            if ($null -ne $Warnings) { $Warnings.Add([pscustomobject]@{ Severity='Error'; Area='Gamelist'; System=$System; Message="Could not recover gamelist XML: $($_.Exception.Message)"; Path=$Path }) }
        }
    }
    return $entries
}

function Test-RomCuratorExcludedDirectory {
    param([string]$Name)
    $excluded = @('media','images','videos','screenshots','manuals','manual','saves','save','states','state','cheats','bezels','covers','marquees','fanart','metadata','gamelists','downloaded_media','.git')
    return ($excluded -contains $Name.ToLowerInvariant())
}

function Test-RomCuratorRomExtension {
    param([string]$Path)
    $file = [IO.Path]::GetFileName($Path)
    $lower = $file.ToLowerInvariant()
    if ($lower -match '\.(png|jpg|jpeg|gif|bmp|webp|mp4|mkv|avi|mov|wmv|xml|json|txt|nfo|sfv|md5|sha1|srt|pdf|ini|cfg|log)$') { return $false }
    $romPatterns = @(
        '\.nkit\.iso$','\.xiso\.iso$','\.iso$','\.cso$','\.dax$','\.jso$','\.chd$','\.rvz$','\.wbfs$','\.gcm$','\.gcz$',
        '\.zip$','\.7z$','\.rar$','\.zar$','\.bin$','\.cue$','\.m3u$','\.ccd$','\.img$','\.mdf$','\.nrg$',
        '\.nes$','\.fds$','\.sfc$','\.smc$','\.fig$','\.gba$','\.gbc$','\.gb$',
        '\.n64$','\.z64$','\.v64$','\.nds$','\.3ds$','\.cia$','\.wud$','\.wux$','\.wua$','\.xci$','\.nsp$',
        '\.pbp$','\.pkg$','\.rap$','\.elf$','\.dol$','\.xbe$','\.xex$',
        '\.wad$','\.md$','\.gen$','\.smd$','\.sms$','\.gg$','\.32x$','\.cdi$','\.gdi$','\.a26$','\.a52$','\.a78$',
        '\.lnx$','\.pce$','\.sgx$','\.ngp$','\.ngc$','\.ws$','\.wsc$','\.col$','\.int$','\.vec$','\.j64$',
        '\.dsk$','\.tap$','\.tzx$','\.rom$','\.neo$','\.mame$'
    )
    foreach ($pattern in $romPatterns) {
        if ($lower -match $pattern) { return $true }
    }
    return $false
}

function Test-RomCuratorFolderGame {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $name = Split-Path -Leaf $Path
        if (Test-RomCuratorExcludedDirectory $name) { return $false }
        $markers = @(
            (Join-Path $Path 'PS3_GAME\PARAM.SFO'),
            (Join-Path $Path 'PS3_GAME\USRDIR\EBOOT.BIN'),
            (Join-Path $Path 'USRDIR\EBOOT.BIN'),
            (Join-Path $Path 'default.xex'),
            (Join-Path $Path 'default.xbe'),
            (Join-Path $Path 'eboot.bin'),
            (Join-Path $Path 'code\app.xml')
        )
        foreach ($marker in $markers) {
            if (Test-Path -LiteralPath $marker) { return $true }
        }
        $topFiles = @(Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction SilentlyContinue | Select-Object -First 5)
        if ($topFiles | Where-Object { $_.Extension -match '(?i)\.(xci|nsp|iso|pkg)$' }) { return $false }
        if ($topFiles | Where-Object { $_.Name -ieq 'PARAM.SFO' -or $_.Name -ieq 'EBOOT.BIN' }) { return $true }
    } catch {}
    return $false
}

function Get-RomCuratorDirectorySize {
    param([Parameter(Mandatory)][string]$Path)
    $total = [int64]0
    try {
        foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue) {
            $total += [int64]$file.Length
        }
    } catch {}
    return $total
}

function Get-RomCuratorDirectoryStats {
    param([Parameter(Mandatory)][string]$Path)
    $total = [int64]0
    $count = 0
    try {
        foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue) {
            $total += [int64]$file.Length
            $count++
        }
    } catch {}
    [pscustomobject]@{ Size=[int64]$total; FileCount=[int]$count; SizeText=(Format-RomCuratorSize $total) }
}

function Format-RomCuratorSize {
    param([Int64]$Bytes)
    if ($Bytes -lt 0) { $Bytes = 0 }
    if ($Bytes -ge 1TB) { return ('{0:N1} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N0} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ('{0} B' -f $Bytes)
}

function Sort-RomCuratorSystemRows {
    param(
        [object[]]$Rows,
        [ValidateSet('DisplayName','System','GameCount','FolderSize','Selected','Warnings')][string]$By = 'DisplayName',
        [switch]$Descending
    )
    $expr = switch ($By) {
        'System' { { [string](Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default '') } }
        'GameCount' { { [int](Get-RomCuratorObjectProperty -Object $_ -Name 'CopyableGames' -Default (Get-RomCuratorObjectProperty -Object $_ -Name 'EstimatedFileCount' -Default 0)) } }
        'FolderSize' { { [int64](Get-RomCuratorObjectProperty -Object $_ -Name 'RomSize' -Default 0) } }
        'Selected' { { if ([bool](Get-RomCuratorObjectProperty -Object $_ -Name 'Selected' -Default $false)) { 0 } else { 1 } } }
        'Warnings' { { [int](Get-RomCuratorObjectProperty -Object $_ -Name 'WarningCount' -Default @((Get-RomCuratorObjectProperty -Object $_ -Name 'Warnings' -Default @())).Count) } }
        default { { [string](Get-RomCuratorObjectProperty -Object $_ -Name 'DisplayName' -Default (Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default '')) } }
    }
    return @($Rows | Sort-Object -Property @{Expression=$expr; Descending=[bool]$Descending})
}

function Get-RomCuratorRelativePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )
    try {
        $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
        $pathFull = [IO.Path]::GetFullPath($Path)
        if ($pathFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
            return $pathFull.Substring($rootFull.Length)
        }
    } catch {}
    return (Split-Path -Leaf $Path)
}

function Get-RomCuratorRomFiles {
    param(
        [Parameter(Mandatory)][string]$System,
        [Parameter(Mandatory)][string]$SystemRoot,
        [object]$CancellationToken,
        [scriptblock]$ProgressCallback,
        [System.Collections.Generic.List[object]]$Warnings
    )
    $items = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $SystemRoot)) {
        if ($null -ne $Warnings) { $Warnings.Add([pscustomobject]@{ Severity='Warning'; Area='ROM Scan'; System=$System; Message="ROM system folder not found: $SystemRoot"; Path=$SystemRoot }) }
        return $items
    }

    $seenFolderGames = New-Object System.Collections.Generic.HashSet[string]
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push((Resolve-Path -LiteralPath $SystemRoot).ProviderPath)
    $count = 0
    while ($stack.Count -gt 0) {
        if ($CancellationToken -and $CancellationToken.IsCancellationRequested) { break }
        $dir = $stack.Pop()
        $leaf = Split-Path -Leaf $dir
        if ((Test-RomCuratorExcludedDirectory $leaf) -and -not $dir.Equals($SystemRoot, [StringComparison]::OrdinalIgnoreCase)) { continue }
        try {
            if (-not $dir.Equals($SystemRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-RomCuratorFolderGame $dir)) {
                if ($seenFolderGames.Add($dir)) {
                    $rel = Get-RomCuratorRelativePath -Root $SystemRoot -Path $dir
                    $size = Get-RomCuratorDirectorySize $dir
                    $items.Add([pscustomobject]@{
                        System = $System
                        OriginalName = Split-Path -Leaf $dir
                        CleanName = Normalize-RomCuratorGameName (Split-Path -Leaf $dir)
                        FullPath = $dir
                        RelativePath = $rel
                        RelativePathKey = ConvertTo-RomCuratorRelativePathKey $rel
                        FileSize = $size
                        Extension = '[folder]'
                        ParentFolder = Split-Path -Leaf (Split-Path -Parent $dir)
                        ModifiedDate = (Get-Item -LiteralPath $dir).LastWriteTime
                        IsFolder = $true
                        GroupKey = Normalize-RomCuratorGameName -Name (Split-Path -Leaf $dir) -ForKey
                    })
                    $count++
                    if ($ProgressCallback -and ($count % 20 -eq 0)) { & $ProgressCallback ([pscustomobject]@{ Operation='scan-roms'; System=$System; FileCount=$count; Current=$dir }) }
                }
                continue
            }

            foreach ($file in Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction SilentlyContinue) {
                if ($CancellationToken -and $CancellationToken.IsCancellationRequested) { break }
                if (-not (Test-RomCuratorRomExtension $file.FullName)) { continue }
                $rel = Get-RomCuratorRelativePath -Root $SystemRoot -Path $file.FullName
                $cleanName = Normalize-RomCuratorGameName $file.Name
                $groupKey = Normalize-RomCuratorGameName -Name ($file.BaseName -replace '(?i)\s*(disc|disk|cd)\s*[0-9ivx]+','') -ForKey
                $items.Add([pscustomobject]@{
                    System = $System
                    OriginalName = $file.Name
                    CleanName = $cleanName
                    FullPath = $file.FullName
                    RelativePath = $rel
                    RelativePathKey = ConvertTo-RomCuratorRelativePathKey $rel
                    FileSize = [int64]$file.Length
                    Extension = $file.Extension.ToLowerInvariant()
                    ParentFolder = Split-Path -Leaf $file.DirectoryName
                    ModifiedDate = $file.LastWriteTime
                    IsFolder = $false
                    GroupKey = $groupKey
                })
                $count++
                if ($ProgressCallback -and ($count % 50 -eq 0)) { & $ProgressCallback ([pscustomobject]@{ Operation='scan-roms'; System=$System; FileCount=$count; Current=$file.FullName }) }
            }
            foreach ($child in Get-ChildItem -LiteralPath $dir -Directory -Force -ErrorAction SilentlyContinue) {
                if (-not (Test-RomCuratorExcludedDirectory $child.Name)) {
                    $stack.Push($child.FullName)
                }
            }
        } catch {
            if ($null -ne $Warnings) { $Warnings.Add([pscustomobject]@{ Severity='Warning'; Area='ROM Scan'; System=$System; Message="Could not scan ${dir}: $($_.Exception.Message)"; Path=$dir }) }
        }
    }
    if ($ProgressCallback) { & $ProgressCallback ([pscustomobject]@{ Operation='scan-roms'; System=$System; FileCount=$count; Current='Complete' }) }
    return $items
}

function Resolve-RomCuratorMediaPath {
    param(
        [AllowNull()][string]$MediaRef,
        [Parameter(Mandatory)][string]$System,
        [string]$GamelistFolder,
        [string]$RomSystemRoot,
        [string]$MediaSystemRoot
    )
    if ([string]::IsNullOrWhiteSpace($MediaRef)) { return $null }
    $candidates = New-Object System.Collections.Generic.List[string]
    $ref = $MediaRef.Trim()
    if ([IO.Path]::IsPathRooted($ref)) {
        $candidates.Add($ref)
    } else {
        $trim = $ref -replace '^[\.\\/]+',''
        foreach ($root in @($RomSystemRoot, $GamelistFolder, $MediaSystemRoot)) {
            if (-not [string]::IsNullOrWhiteSpace($root)) { $candidates.Add((Join-Path $root $trim)) }
        }
    }
    foreach ($candidate in $candidates) {
        try {
            if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).ProviderPath }
        } catch {}
    }
    return $null
}

function Get-RomCuratorMediaIndex {
    param([Parameter(Mandatory)][string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root)) { return @{} }
    $resolvedRoot = try { (Resolve-Path -LiteralPath $Root).ProviderPath } catch { $Root }
    if ($script:MediaIndexCache.ContainsKey($resolvedRoot)) { return $script:MediaIndexCache[$resolvedRoot] }
    $index = @{}
    $allowed = '\.(png|jpg|jpeg|webp|bmp|mp4|mkv|avi|mov|wmv)$'
    try {
        foreach ($file in Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse -Force -ErrorAction SilentlyContinue) {
            if ($file.Name -notmatch $allowed) { continue }
            $key = Normalize-RomCuratorGameName -Name $file.BaseName -ForKey
            if (-not $key) { continue }
            if (-not $index.ContainsKey($key)) { $index[$key] = New-Object System.Collections.Generic.List[object] }
            $index[$key].Add($file.FullName)
        }
    } catch {}
    $script:MediaIndexCache[$resolvedRoot] = $index
    return $index
}

function Find-RomCuratorMediaByName {
    param(
        [Parameter(Mandatory)][object]$Rom,
        [Parameter(Mandatory)][string]$System,
        [string]$RomSystemRoot,
        [string]$MediaSystemRoot,
        [string]$MediaMode = 'AutoDetect'
    )
    $stem = Normalize-RomCuratorGameName -Name $Rom.OriginalName -ForKey
    $base = [IO.Path]::GetFileNameWithoutExtension($Rom.OriginalName)
    $roots = New-Object System.Collections.Generic.List[string]
    if ($MediaMode -in @('AutoDetect','Central') -and -not [string]::IsNullOrWhiteSpace($MediaSystemRoot)) { $roots.Add($MediaSystemRoot) }
    if ($MediaMode -in @('AutoDetect','BesideRoms') -and -not [string]::IsNullOrWhiteSpace($RomSystemRoot)) { $roots.Add((Join-Path $RomSystemRoot 'media')) }
    $imageDirs = @('images','image','covers','boxart','thumbs','thumbnails','screenshots','fanart')
    $videoDirs = @('videos','video')
    $imageExts = @('.png','.jpg','.jpeg','.webp','.bmp')
    $videoExts = @('.mp4','.mkv','.avi','.mov','.wmv')

    $result = [ordered]@{ ImagePath=$null; VideoPath=$null; FanartPath=$null; MarqueePath=$null; MediaSize=[int64]0 }
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $mediaIndex = Get-RomCuratorMediaIndex -Root $root
        if ($mediaIndex.ContainsKey($stem)) {
            foreach ($indexedPath in @($mediaIndex[$stem].ToArray())) {
                $ext = [IO.Path]::GetExtension($indexedPath).ToLowerInvariant()
                if (($imageExts -contains $ext) -and -not $result.ImagePath) { $result.ImagePath = $indexedPath }
                if (($videoExts -contains $ext) -and -not $result.VideoPath) { $result.VideoPath = $indexedPath }
                try { $result.MediaSize += (Get-Item -LiteralPath $indexedPath).Length } catch {}
            }
            if ($result.ImagePath -and $result.VideoPath) { continue }
        }
        foreach ($dirName in $imageDirs) {
            $dir = Join-Path $root $dirName
            if (-not (Test-Path -LiteralPath $dir)) { continue }
            foreach ($ext in $imageExts) {
                foreach ($candidateName in @($base, $Rom.CleanName)) {
                    $candidate = Join-Path $dir ($candidateName + $ext)
                    if (Test-Path -LiteralPath $candidate) {
                        $resolved = (Resolve-Path -LiteralPath $candidate).ProviderPath
                        if (-not $result.ImagePath) { $result.ImagePath = $resolved }
                        try { $result.MediaSize += (Get-Item -LiteralPath $resolved).Length } catch {}
                        break
                    }
                }
                if ($result.ImagePath) { break }
            }
            if ($result.ImagePath) { break }
        }
        foreach ($dirName in $videoDirs) {
            $dir = Join-Path $root $dirName
            if (-not (Test-Path -LiteralPath $dir)) { continue }
            foreach ($ext in $videoExts) {
                foreach ($candidateName in @($base, $Rom.CleanName)) {
                    $candidate = Join-Path $dir ($candidateName + $ext)
                    if (Test-Path -LiteralPath $candidate) {
                        $resolved = (Resolve-Path -LiteralPath $candidate).ProviderPath
                        if (-not $result.VideoPath) { $result.VideoPath = $resolved }
                        try { $result.MediaSize += (Get-Item -LiteralPath $resolved).Length } catch {}
                        break
                    }
                }
                if ($result.VideoPath) { break }
            }
            if ($result.VideoPath) { break }
        }
    }
    return [pscustomobject]$result
}

function Resolve-RomCuratorGameMedia {
    param(
        [Parameter(Mandatory)][object]$Rom,
        [object]$GamelistEntry,
        [Parameter(Mandatory)][object]$Settings,
        [string]$SystemRoot,
        [string]$GamelistPath
    )
    $mediaSystemRoot = if ($Settings.MediaRoot) { Join-Path $Settings.MediaRoot $Rom.System } else { '' }
    $gamelistFolder = if ($GamelistPath) { Split-Path -Parent $GamelistPath } else { '' }
    $media = [ordered]@{
        ImagePath = $null
        ThumbnailPath = $null
        MarqueePath = $null
        VideoPath = $null
        FanartPath = $null
        BoxartPath = $null
        MediaSize = [int64]0
        MissingMedia = New-Object System.Collections.Generic.List[string]
    }
    if ($GamelistEntry) {
        foreach ($pair in @(
            @{Field='Image'; Target='ImagePath'},
            @{Field='Thumbnail'; Target='ThumbnailPath'},
            @{Field='Marquee'; Target='MarqueePath'},
            @{Field='Video'; Target='VideoPath'},
            @{Field='Fanart'; Target='FanartPath'},
            @{Field='Boxart'; Target='BoxartPath'}
        )) {
            $ref = $GamelistEntry.$($pair.Field)
            if (-not [string]::IsNullOrWhiteSpace($ref)) {
                $resolved = Resolve-RomCuratorMediaPath -MediaRef $ref -System $Rom.System -GamelistFolder $gamelistFolder -RomSystemRoot $SystemRoot -MediaSystemRoot $mediaSystemRoot
                if ($resolved) {
                    $media[$pair.Target] = $resolved
                    try { $media.MediaSize += (Get-Item -LiteralPath $resolved).Length } catch {}
                } else {
                    $media.MissingMedia.Add($pair.Field)
                }
            }
        }
    }
    $auto = Find-RomCuratorMediaByName -Rom $Rom -System $Rom.System -RomSystemRoot $SystemRoot -MediaSystemRoot $mediaSystemRoot -MediaMode $Settings.MediaMode
    if (-not $media.ImagePath -and $auto.ImagePath) { $media.ImagePath = $auto.ImagePath; $media.MediaSize += $auto.MediaSize }
    if (-not $media.VideoPath -and $auto.VideoPath) { $media.VideoPath = $auto.VideoPath }

    [pscustomobject]@{
        ImagePath = $media.ImagePath
        ThumbnailPath = $media.ThumbnailPath
        MarqueePath = $media.MarqueePath
        VideoPath = $media.VideoPath
        FanartPath = $media.FanartPath
        BoxartPath = $media.BoxartPath
        HasImage = [bool]($media.ImagePath -or $media.ThumbnailPath -or $media.BoxartPath)
        HasVideo = [bool]$media.VideoPath
        MediaSize = [int64]$media.MediaSize
        MissingMedia = @($media.MissingMedia)
    }
}

function Get-RomCuratorQuickFileEstimate {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return 0 }
    try {
        $count = 0
        foreach ($child in Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Select-Object -First 501) {
            if (Test-RomCuratorExcludedDirectory $child.Name) { continue }
            if ($child.PSIsContainer) {
                if (Test-RomCuratorFolderGame $child.FullName) { $count++ }
                continue
            }
            if (Test-RomCuratorRomExtension $child.FullName) { $count++ }
        }
        return $count
    } catch {
        return 0
    }
}

function Get-RomCuratorSystemDiscovery {
    param([Parameter(Mandatory)][object]$Settings)
    $aliases = Get-RomCuratorSystemAliases -Settings $Settings
    $systems = [ordered]@{}

    function Get-LocalDiscovery([string]$SystemName) {
        $canonical = Resolve-RomCuratorSystemAlias -System $SystemName -AliasMap $aliases
        if ([string]::IsNullOrWhiteSpace($canonical)) { $canonical = $SystemName }
        if (-not $systems.Contains($canonical)) {
            $systems[$canonical] = [pscustomobject]@{
                Selected = $true
                System = $SystemName
                DisplayName = $SystemName
                CanonicalSystem = $canonical
                GamelistSystem = ''
                RomSystem = ''
                MediaSystem = ''
                GamelistPath = ''
                RomSystemRoot = ''
                MediaSystemRoot = ''
                HasGamelist = $false
                HasRomFolder = $false
                HasMediaFolder = $false
                EstimatedFileCount = 0
                RomSize = [int64]0
                RomSizeText = ''
                MediaSize = [int64]0
                MediaSizeText = ''
                Warnings = @()
                WarningsText = ''
            }
        }
        return $systems[$canonical]
    }

    if ($Settings.GamelistsRoot -and (Test-Path -LiteralPath $Settings.GamelistsRoot)) {
        foreach ($dir in Get-ChildItem -LiteralPath $Settings.GamelistsRoot -Directory -Force -ErrorAction SilentlyContinue) {
            if (Test-RomCuratorExcludedDirectory $dir.Name) { continue }
            $entry = Get-LocalDiscovery $dir.Name
            $entry.System = $dir.Name
            $entry.DisplayName = $dir.Name
            $entry.GamelistSystem = $dir.Name
            $entry.GamelistPath = Join-Path $dir.FullName 'gamelist.xml'
            $entry.HasGamelist = [bool](Test-Path -LiteralPath $entry.GamelistPath)
        }
    }

    if ($Settings.RomsRoot -and (Test-Path -LiteralPath $Settings.RomsRoot)) {
        foreach ($dir in Get-ChildItem -LiteralPath $Settings.RomsRoot -Directory -Force -ErrorAction SilentlyContinue) {
            if (Test-RomCuratorExcludedDirectory $dir.Name) { continue }
            $canonical = Resolve-RomCuratorSystemAlias -System $dir.Name -AliasMap $aliases
            if ([string]::IsNullOrWhiteSpace($canonical)) { $canonical = $dir.Name }
            $alreadyKnown = $systems.Contains($canonical)
            $estimate = Get-RomCuratorQuickFileEstimate -Path $dir.FullName
            if ($estimate -le 0 -and -not $alreadyKnown) { continue }
            $entry = Get-LocalDiscovery $dir.Name
            if ([string]::IsNullOrWhiteSpace($entry.System)) { $entry.System = $dir.Name }
            if ([string]::IsNullOrWhiteSpace($entry.DisplayName)) { $entry.DisplayName = $dir.Name }
            $entry.RomSystem = $dir.Name
            $entry.RomSystemRoot = $dir.FullName
            $entry.HasRomFolder = $true
            $entry.EstimatedFileCount = $estimate
        }
    }

    if ($Settings.MediaRoot -and (Test-Path -LiteralPath $Settings.MediaRoot)) {
        foreach ($dir in Get-ChildItem -LiteralPath $Settings.MediaRoot -Directory -Force -ErrorAction SilentlyContinue) {
            if (Test-RomCuratorExcludedDirectory $dir.Name) { continue }
            $entry = Get-LocalDiscovery $dir.Name
            $entry.MediaSystem = $dir.Name
            $entry.MediaSystemRoot = $dir.FullName
            $entry.HasMediaFolder = $true
        }
    }

    foreach ($entry in $systems.Values) {
        $warnings = New-Object System.Collections.Generic.List[string]
        if (-not $entry.HasGamelist) { [void]$warnings.Add('No gamelist.xml') }
        if (-not $entry.HasRomFolder) { [void]$warnings.Add('No ROM folder') }
        if ($entry.HasRomFolder -and [int]$entry.EstimatedFileCount -le 0) { [void]$warnings.Add('Empty ROM folder') }
        if ($Settings.MediaRoot -and -not $entry.HasMediaFolder) { [void]$warnings.Add('No media folder') }
        if ($entry.GamelistSystem -and $entry.RomSystem -and $entry.GamelistSystem -ne $entry.RomSystem) {
            [void]$warnings.Add("Alias match: gamelist $($entry.GamelistSystem), ROM $($entry.RomSystem)")
        }
        $entry.Warnings = @($warnings.ToArray())
        $entry.WarningsText = (@($warnings.ToArray()) -join '; ')
        $entry.Selected = [bool]($entry.HasRomFolder -and [int]$entry.EstimatedFileCount -gt 0)
    }
    return @($systems.Values | Sort-Object System)
}

function Save-RomCuratorDiscoveryCache {
    param(
        [Parameter(Mandatory)][object[]]$Discovery,
        [Parameter(Mandatory)][object]$Settings,
        [string]$Path = (Join-Path (Get-RomCuratorCacheFolder) 'system_discovery_cache.json')
    )
    Ensure-RomCuratorDirectory (Split-Path -Parent $Path) | Out-Null
    $payload = [pscustomobject]@{
        SchemaVersion = $script:CacheSchemaVersion
        SavedAt = (Get-Date).ToString('o')
        SettingsSignature = Get-RomCuratorSettingsSignature -Settings $Settings
        Systems = @($Discovery)
    }
    $payload | ConvertTo-RomCuratorJson | Set-Content -LiteralPath $Path -Encoding UTF8
    return $Path
}

function Get-RomCuratorDiscoveredSystems {
    param([Parameter(Mandatory)][object]$Settings)
    $discovery = @(Get-RomCuratorSystemDiscovery -Settings $Settings)
    return @($discovery | Where-Object { $_.HasGamelist -or $_.HasRomFolder } | ForEach-Object {
        [pscustomobject]@{
            System = if ($_.System) { $_.System } else { $_.CanonicalSystem }
            DisplayName = $_.DisplayName
            CanonicalSystem = $_.CanonicalSystem
            GamelistPath = $_.GamelistPath
            RomSystemRoot = $_.RomSystemRoot
            MediaSystemRoot = $_.MediaSystemRoot
        }
    })
}

function Merge-RomCuratorGameData {
    param(
        [Parameter(Mandatory)][object]$Rom,
        [object]$Entry,
        [object]$RatingMatch,
        [object]$Media,
        [object[]]$Issues
    )
    $name = if ($Entry -and -not [string]::IsNullOrWhiteSpace($Entry.Name)) { $Entry.Name } else { $Rom.CleanName }
    $clean = Normalize-RomCuratorGameName $name
    if ([string]::IsNullOrWhiteSpace($clean)) { $clean = $Rom.CleanName }
    [pscustomobject]@{
        Selected = $false
        System = $Rom.System
        CleanName = $clean
        OriginalName = $Rom.OriginalName
        CriticScore = if ($RatingMatch) { $RatingMatch.CriticScore } else { $null }
        MatchConfidence = if ($RatingMatch) { $RatingMatch.MatchConfidence } else { $null }
        RatingTitleMatched = if ($RatingMatch) { $RatingMatch.TitleMatched } else { '' }
        RatingPlatform = if ($RatingMatch) { $RatingMatch.Platform } else { '' }
        RatingReleaseYear = if ($RatingMatch) { $RatingMatch.ReleaseYear } else { $null }
        RatingUrl = if ($RatingMatch) { $RatingMatch.DetailUrl } else { '' }
        RatingMatchMethod = if ($RatingMatch) { $RatingMatch.MatchMethod } else { '' }
        NormalizedName = Normalize-RomCuratorGameName -Name $clean -ForKey
        DuplicateKey = Normalize-RomCuratorGameName -Name $clean -ForKey
        DuplicateGroupSize = 1
        IsDuplicate = $false
        DuplicateRank = 1
        DuplicateNote = ''
        Genre = if ($Entry) { $Entry.Genre } else { '' }
        Players = if ($Entry) { $Entry.Players } else { '' }
        Favorite = if ($Entry) { $Entry.Favorite } else { '' }
        Hidden = if ($Entry) { $Entry.Hidden } else { '' }
        KidGame = if ($Entry) { $Entry.KidGame } else { '' }
        Description = if ($Entry) { $Entry.Description } else { '' }
        Developer = if ($Entry) { $Entry.Developer } else { '' }
        Publisher = if ($Entry) { $Entry.Publisher } else { '' }
        ReleaseDate = if ($Entry) { $Entry.ReleaseDate } else { '' }
        FileSize = [int64]$Rom.FileSize
        SizeMB = [Math]::Round(([double]$Rom.FileSize / 1MB), 2)
        Extension = $Rom.Extension
        ParentFolder = $Rom.ParentFolder
        ModifiedDate = $Rom.ModifiedDate
        RomPath = $Rom.FullPath
        RelativePath = $Rom.RelativePath
        IsFolder = $Rom.IsFolder
        GamelistPath = if ($Entry) { $Entry.GamelistPath } else { '' }
        GamelistRelativePath = if ($Entry) { $Entry.Path } else { '' }
        HasGamelistEntry = [bool]$Entry
        ImagePath = if ($Media) { $Media.ImagePath } else { $null }
        ThumbnailPath = if ($Media) { $Media.ThumbnailPath } else { $null }
        MarqueePath = if ($Media) { $Media.MarqueePath } else { $null }
        VideoPath = if ($Media) { $Media.VideoPath } else { $null }
        FanartPath = if ($Media) { $Media.FanartPath } else { $null }
        BoxartPath = if ($Media) { $Media.BoxartPath } else { $null }
        HasImage = if ($Media) { $Media.HasImage } else { $false }
        HasVideo = if ($Media) { $Media.HasVideo } else { $false }
        MediaSize = if ($Media) { [int64]$Media.MediaSize } else { [int64]0 }
        Issues = @($Issues)
        IssuesText = (@($Issues) -join '; ')
        Metadata = if ($Entry) { $Entry.Fields } else { [ordered]@{} }
    }
}

function Invoke-RomCuratorLibraryScan {
    param(
        [Parameter(Mandatory)][object]$Settings,
        [string]$MetacriticPath,
        [string[]]$SystemsToScan,
        [object]$CancellationToken,
        [scriptblock]$ProgressCallback
    )
    $warnings = New-Object System.Collections.Generic.List[object]
    $items = New-Object System.Collections.Generic.List[object]
    $started = Get-Date
    if (-not $MetacriticPath) { $MetacriticPath = if ($Settings.RatingFilePath) { $Settings.RatingFilePath } else { $script:DefaultRatingFile } }
    if ($ProgressCallback) { & $ProgressCallback ([pscustomobject]@{ Operation='load-ratings'; Message='Loading Metacritic ratings'; Percent=0 }) }
    $ratingRecords = Import-RomCuratorMetacriticJsonl -Path $MetacriticPath -Warnings $warnings
    $ratingIndex = New-RomCuratorRatingIndex -Records @($ratingRecords)
    $systems = @(Get-RomCuratorDiscoveredSystems -Settings $Settings)
    if ($SystemsToScan -and $SystemsToScan.Count -gt 0) {
        $wanted = @{}
        foreach ($systemName in $SystemsToScan) { $wanted[[string]$systemName] = $true }
        $systems = @($systems | Where-Object { $wanted.ContainsKey([string]$_.System) })
    }
    if ($systems.Count -eq 0) {
        $warnings.Add([pscustomobject]@{ Severity='Warning'; Area='Scan'; Message='No systems discovered. Check gamelists and ROM roots.'; Path='' })
    }
    $systemNumber = 0
    foreach ($systemInfo in $systems) {
        if ($CancellationToken -and $CancellationToken.IsCancellationRequested) { break }
        $systemNumber++
        $percent = if ($systems.Count -gt 0) { [int](($systemNumber - 1) * 100 / $systems.Count) } else { 0 }
        $systemStarted = Get-Date
        $systemItems = New-Object System.Collections.Generic.List[object]
        $systemMatchCount = 0
        if ($ProgressCallback) {
            & $ProgressCallback ([pscustomobject]@{
                Operation='system-start'; System=$systemInfo.System; Message="Scanning $($systemInfo.System)";
                Percent=$percent; SystemsCompleted=($systemNumber - 1); SystemsTotal=$systems.Count;
                Current=$systemInfo.GamelistPath; GamesDiscovered=$items.Count; WarningsCount=$warnings.Count
            })
        }

        $entries = New-Object System.Collections.Generic.List[object]
        if ($systemInfo.GamelistPath -and (Test-Path -LiteralPath $systemInfo.GamelistPath)) {
            if ($ProgressCallback) { & $ProgressCallback ([pscustomobject]@{ Operation='parse-gamelist'; System=$systemInfo.System; Current=$systemInfo.GamelistPath; SystemsCompleted=($systemNumber - 1); SystemsTotal=$systems.Count; Percent=$percent }) }
            $entries = Parse-RomCuratorGamelist -Path $systemInfo.GamelistPath -System $systemInfo.System -RomSystemRoot $systemInfo.RomSystemRoot -Warnings $warnings
        }

        $roms = Get-RomCuratorRomFiles -System $systemInfo.System -SystemRoot $systemInfo.RomSystemRoot -CancellationToken $CancellationToken -ProgressCallback $ProgressCallback -Warnings $warnings
        if ($ProgressCallback) { & $ProgressCallback ([pscustomobject]@{ Operation='match-system'; System=$systemInfo.System; Current=$systemInfo.RomSystemRoot; RomCount=$roms.Count; MetadataCount=$entries.Count; SystemsCompleted=($systemNumber - 1); SystemsTotal=$systems.Count; Percent=$percent }) }
        $romByPath = @{}
        $romByName = @{}
        foreach ($rom in $roms) {
            if (-not $romByPath.ContainsKey($rom.RelativePathKey)) { $romByPath[$rom.RelativePathKey] = $rom }
            else { $warnings.Add([pscustomobject]@{ Severity='Warning'; Area='Matching'; System=$systemInfo.System; Message="Duplicate ROM relative path: $($rom.RelativePath)"; Path=$rom.FullPath }) }
            $key = Normalize-RomCuratorGameName -Name $rom.CleanName -ForKey
            if (-not $romByName.ContainsKey($key)) { $romByName[$key] = New-Object System.Collections.Generic.List[object] }
            $romByName[$key].Add($rom)
        }

        $matchedRomPaths = New-Object System.Collections.Generic.HashSet[string]
        $entryPathCounts = @{}
        foreach ($entry in $entries) {
            if ($entry.RelativePathKey) {
                if (-not $entryPathCounts.ContainsKey($entry.RelativePathKey)) { $entryPathCounts[$entry.RelativePathKey] = 0 }
                $entryPathCounts[$entry.RelativePathKey]++
            }
        }
        foreach ($key in $entryPathCounts.Keys) {
            if ($entryPathCounts[$key] -gt 1) {
                $warnings.Add([pscustomobject]@{ Severity='Warning'; Area='Gamelist'; System=$systemInfo.System; Message="Duplicate gamelist entry path: $key"; Path=$systemInfo.GamelistPath })
            }
        }

        foreach ($entry in $entries) {
            if ($CancellationToken -and $CancellationToken.IsCancellationRequested) { break }
            $rom = $null
            if ($entry.RelativePathKey -and $romByPath.ContainsKey($entry.RelativePathKey)) {
                $rom = $romByPath[$entry.RelativePathKey]
            } else {
                $nameKey = Normalize-RomCuratorGameName -Name $entry.Name -ForKey
                if ($romByName.ContainsKey($nameKey) -and $romByName[$nameKey].Count -eq 1) {
                    $rom = $romByName[$nameKey][0]
                }
            }
            if ($rom) {
                [void]$matchedRomPaths.Add($rom.FullPath)
                $issues = New-Object System.Collections.Generic.List[string]
                if ($entry.RelativePathKey -and $entry.RelativePathKey -ne $rom.RelativePathKey) { $issues.Add('Gamelist path matched by name fallback') }
                $media = Resolve-RomCuratorGameMedia -Rom $rom -GamelistEntry $entry -Settings $Settings -SystemRoot $systemInfo.RomSystemRoot -GamelistPath $systemInfo.GamelistPath
                if (-not $media.HasImage) { $issues.Add('Missing image media') }
                $ratingName = if ($entry.Name) { $entry.Name } else { $rom.CleanName }
                $rating = Find-RomCuratorRatingMatch -Name $ratingName -System $systemInfo.System -Index $ratingIndex -MinimumConfidence $Settings.MinimumRatingConfidence
                if (-not $rating) { $issues.Add('No Metacritic match') }
                elseif ($rating.MatchConfidence -lt 0.9) { $issues.Add('Low confidence rating match') }
                if ($rating) { $systemMatchCount++ }
                $merged = Merge-RomCuratorGameData -Rom $rom -Entry $entry -RatingMatch $rating -Media $media -Issues $issues
                $items.Add($merged)
                $systemItems.Add($merged)
            } else {
                $fakeRom = [pscustomobject]@{
                    System=$systemInfo.System; OriginalName=if ($entry.Path) { Split-Path -Leaf $entry.Path } else { $entry.Name }; CleanName=Normalize-RomCuratorGameName $entry.Name
                    FullPath=$entry.ResolvedPath; RelativePath=$entry.Path; FileSize=[int64]0; Extension='[missing]'; ParentFolder=''; ModifiedDate=$null; IsFolder=$false
                }
                $rating = Find-RomCuratorRatingMatch -Name $entry.Name -System $systemInfo.System -Index $ratingIndex -MinimumConfidence $Settings.MinimumRatingConfidence
                if ($rating) { $systemMatchCount++ }
                $merged = Merge-RomCuratorGameData -Rom $fakeRom -Entry $entry -RatingMatch $rating -Media $null -Issues @('Missing ROM for gamelist entry')
                $items.Add($merged)
                $systemItems.Add($merged)
                $warnings.Add([pscustomobject]@{ Severity='Warning'; Area='Matching'; System=$systemInfo.System; Message="Gamelist entry has no matching ROM: $($entry.Path)"; Path=$systemInfo.GamelistPath })
            }
        }

        foreach ($rom in $roms) {
            if ($CancellationToken -and $CancellationToken.IsCancellationRequested) { break }
            if ($matchedRomPaths.Contains($rom.FullPath)) { continue }
            $issues = New-Object System.Collections.Generic.List[string]
            $issues.Add('Orphan ROM without gamelist entry')
            $media = Resolve-RomCuratorGameMedia -Rom $rom -GamelistEntry $null -Settings $Settings -SystemRoot $systemInfo.RomSystemRoot -GamelistPath $systemInfo.GamelistPath
            if (-not $media.HasImage) { $issues.Add('Missing image media') }
            $rating = Find-RomCuratorRatingMatch -Name $rom.CleanName -System $systemInfo.System -Index $ratingIndex -MinimumConfidence $Settings.MinimumRatingConfidence
            if (-not $rating) { $issues.Add('No Metacritic match') }
            elseif ($rating.MatchConfidence -lt 0.9) { $issues.Add('Low confidence rating match') }
            if ($rating) { $systemMatchCount++ }
            $merged = Merge-RomCuratorGameData -Rom $rom -Entry $null -RatingMatch $rating -Media $media -Issues $issues
            $items.Add($merged)
            $systemItems.Add($merged)
        }
        if ($ProgressCallback) {
            $systemElapsed = ((Get-Date) - $systemStarted).TotalSeconds
            & $ProgressCallback ([pscustomobject]@{
                Operation='system-complete'; System=$systemInfo.System; Message="Finished $($systemInfo.System)";
                Percent=([int]($systemNumber * 100 / [Math]::Max(1, $systems.Count)));
                SystemsCompleted=$systemNumber; SystemsTotal=$systems.Count; Current=$systemInfo.RomSystemRoot;
                Items=@($systemItems.ToArray()); RomCount=$roms.Count; MetadataCount=$entries.Count;
                GamesDiscovered=$items.Count; MetacriticMatches=$systemMatchCount; WarningsCount=$warnings.Count;
                ElapsedSeconds=[Math]::Round($systemElapsed, 2)
            })
        }
    }
    Update-RomCuratorDuplicateGroups -Items @($items.ToArray()) | Out-Null
    if ($ProgressCallback) { & $ProgressCallback ([pscustomobject]@{ Operation='complete'; Message='Scan complete'; Percent=100; FileCount=$items.Count }) }
    [pscustomobject]@{
        StartedAt = $started
        CompletedAt = (Get-Date)
        Items = @($items.ToArray())
        Warnings = @($warnings.ToArray())
        Systems = @($systems.System)
        RatingRecordCount = $ratingRecords.Count
        Cancelled = [bool]($CancellationToken -and $CancellationToken.IsCancellationRequested)
    }
}

function Get-RomCuratorSystemStamps {
    param([Parameter(Mandatory)][object]$Settings)
    $stamps = @{}
    foreach ($system in @(Get-RomCuratorDiscoveredSystems -Settings $Settings)) {
        $stamps[$system.System] = [pscustomobject]@{
            System = $system.System
            GamelistPath = $system.GamelistPath
            RomSystemRoot = $system.RomSystemRoot
            Gamelist = Get-RomCuratorPathStamp $system.GamelistPath
            RomFolder = Get-RomCuratorPathStamp $system.RomSystemRoot
        }
    }
    return $stamps
}

function Save-RomCuratorLibraryCache {
    param(
        [Parameter(Mandatory)][object]$ScanResult,
        [Parameter(Mandatory)][object]$Settings,
        [string]$Path = (Get-RomCuratorLibraryCachePath)
    )
    $started = Get-Date
    Ensure-RomCuratorDirectory (Split-Path -Parent $Path) | Out-Null
    $cache = [pscustomobject]@{
        SchemaVersion = $script:CacheSchemaVersion
        SavedAt = (Get-Date).ToString('o')
        SettingsSignature = Get-RomCuratorSettingsSignature -Settings $Settings
        SourceStamps = Get-RomCuratorSystemStamps -Settings $Settings
        Discovery = @(Get-RomCuratorSystemDiscovery -Settings $Settings)
        RatingInfo = Get-RomCuratorMetacriticInfo -Path $Settings.RatingFilePath
        StartedAt = $ScanResult.StartedAt
        CompletedAt = $ScanResult.CompletedAt
        Items = @(Update-RomCuratorDuplicateGroups -Items @($ScanResult.Items))
        Warnings = @($ScanResult.Warnings)
        Systems = @($ScanResult.Systems)
        RatingRecordCount = $ScanResult.RatingRecordCount
    }
    $tmp = "$Path.tmp"
    $cache | ConvertTo-RomCuratorJson | Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
    [pscustomobject]@{ Path=$Path; DurationSeconds=[Math]::Round(((Get-Date)-$started).TotalSeconds, 3); ItemCount=@($ScanResult.Items).Count }
}

function Load-RomCuratorLibraryCache {
    param(
        [object]$Settings,
        [string]$Path = (Get-RomCuratorLibraryCachePath),
        [switch]$SkipValidation
    )
    $started = Get-Date
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Loaded=$false; Valid=$false; Reason='No cache found'; Path=$Path; Items=@(); Warnings=@(); Cache=$null; DurationSeconds=0 }
    }
    try {
        $cache = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $valid = $true
        $reason = 'Cache loaded'
        if ([int]$cache.SchemaVersion -ne $script:CacheSchemaVersion) {
            $valid = $false
            $reason = "Cache schema changed: $($cache.SchemaVersion) -> $script:CacheSchemaVersion"
        }
        if (-not $SkipValidation -and $Settings) {
            foreach ($rootProp in @('GamelistsRoot','RomsRoot')) {
                $root = [string]$Settings.$rootProp
                if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
                    $valid = $false
                    $reason = "$rootProp is missing: $root"
                }
            }
            $sig = $cache.SettingsSignature
            foreach ($prop in @('GamelistsRoot','RomsRoot','MediaRoot','MediaMode','RatingFilePath')) {
                if ($sig -and "$($sig.$prop)" -ne "$($Settings.$prop)") {
                    $valid = $false
                    $reason = "Settings changed since cache was saved ($prop)"
                    break
                }
            }
        }
        $items = @(Update-RomCuratorDuplicateGroups -Items @($cache.Items))
        [pscustomobject]@{
            Loaded = $true
            Valid = $valid
            Reason = $reason
            Path = $Path
            Items = @($items)
            Warnings = @($cache.Warnings)
            Cache = $cache
            DurationSeconds = [Math]::Round(((Get-Date)-$started).TotalSeconds, 3)
        }
    } catch {
        [pscustomobject]@{ Loaded=$false; Valid=$false; Reason="Cache read failed: $($_.Exception.Message)"; Path=$Path; Items=@(); Warnings=@(); Cache=$null; DurationSeconds=[Math]::Round(((Get-Date)-$started).TotalSeconds, 3) }
    }
}

function Get-RomCuratorChangedSystems {
    param(
        [Parameter(Mandatory)][object]$Cache,
        [Parameter(Mandatory)][object]$Settings
    )
    $changed = New-Object System.Collections.Generic.List[string]
    $current = Get-RomCuratorSystemStamps -Settings $Settings
    foreach ($systemName in $current.Keys) {
        $old = $null
        if ($Cache.SourceStamps) {
            $oldProp = $Cache.SourceStamps.PSObject.Properties | Where-Object { $_.Name -eq $systemName } | Select-Object -First 1
            if ($oldProp) { $old = $oldProp.Value }
        }
        if (-not $old) {
            $changed.Add($systemName)
            continue
        }
        $newStamp = $current[$systemName]
        $oldGameTick = if ($old.Gamelist.PSObject.Properties['LastWriteUtcTicks']) { "$($old.Gamelist.LastWriteUtcTicks)" } else { "$($old.Gamelist.LastWriteUtc)" }
        $newGameTick = if ($newStamp.Gamelist.PSObject.Properties['LastWriteUtcTicks']) { "$($newStamp.Gamelist.LastWriteUtcTicks)" } else { "$($newStamp.Gamelist.LastWriteUtc)" }
        $oldRomTick = if ($old.RomFolder.PSObject.Properties['LastWriteUtcTicks']) { "$($old.RomFolder.LastWriteUtcTicks)" } else { "$($old.RomFolder.LastWriteUtc)" }
        $newRomTick = if ($newStamp.RomFolder.PSObject.Properties['LastWriteUtcTicks']) { "$($newStamp.RomFolder.LastWriteUtcTicks)" } else { "$($newStamp.RomFolder.LastWriteUtc)" }
        if ($oldGameTick -ne $newGameTick -or $oldRomTick -ne $newRomTick) {
            $changed.Add($systemName)
        }
    }
    return @($changed.ToArray())
}

function Remove-RomCuratorLibraryCache {
    param([string]$Path = (Get-RomCuratorLibraryCachePath))
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
        return $true
    }
    return $false
}

function Get-RomCuratorDefaultExportProfiles {
    @(
        [pscustomobject]@{ Id='windows'; Name='Windows / loose folder export'; RomRoot='{system}'; MediaRoot='{system}\media'; GamelistPath='{system}\gamelist.xml'; MediaStyle='BesideRoms' },
        [pscustomobject]@{ Id='es-de'; Name='ES-DE'; RomRoot='roms\{system}'; MediaRoot='storage\downloaded_media\{system}'; GamelistPath='ES-DE\gamelists\{system}\gamelist.xml'; MediaStyle='Central' },
        [pscustomobject]@{ Id='batocera'; Name='Batocera / KNULLI'; RomRoot='roms\{system}'; MediaRoot='roms\{system}\media'; GamelistPath='roms\{system}\gamelist.xml'; MediaStyle='BesideRoms' },
        [pscustomobject]@{ Id='muos'; Name='muOS'; RomRoot='ROMS\{system}'; MediaRoot='ROMS\{system}\media'; GamelistPath='ROMS\{system}\gamelist.xml'; MediaStyle='BesideRoms' },
        [pscustomobject]@{ Id='rocknix'; Name='ROCKNIX'; RomRoot='roms\{system}'; MediaRoot='roms\{system}\media'; GamelistPath='roms\{system}\gamelist.xml'; MediaStyle='BesideRoms' },
        [pscustomobject]@{ Id='launchbox'; Name='LaunchBox-style export'; RomRoot='Games\{system}'; MediaRoot='Images\{system}'; GamelistPath='Metadata\{system}\gamelist.xml'; MediaStyle='LaunchBox' },
        [pscustomobject]@{ Id='custom'; Name='Generic custom profile'; RomRoot='{system}'; MediaRoot='{system}\media'; GamelistPath='{system}\gamelist.xml'; MediaStyle='BesideRoms' }
    )
}

function Get-RomCuratorExportProfiles {
    param([object]$Settings)
    $default = @(Get-RomCuratorDefaultExportProfiles)
    $path = if ($Settings -and $Settings.PSObject.Properties['ExportProfilesPath']) { $Settings.ExportProfilesPath } else { $null }
    if ($path -and (Test-Path -LiteralPath $path)) {
        try {
            $custom = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop)
            if ($custom.Count -gt 0) {
                foreach ($profile in $custom) { $profile }
                return
            }
        } catch {}
    }
    foreach ($profile in $default) { $profile }
}

function Save-RomCuratorExportProfiles {
    param(
        [Parameter(Mandatory)][object[]]$Profiles,
        [string]$Path = (Join-Path $script:ModuleRoot 'data\export_profiles.json')
    )
    Ensure-RomCuratorDirectory (Split-Path -Parent $Path) | Out-Null
    $Profiles | ConvertTo-RomCuratorJson | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-RomCuratorExportProfile {
    param(
        [Parameter(Mandatory)][string]$Id,
        [object]$Settings
    )
    @(Get-RomCuratorExportProfiles -Settings $Settings) | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

function Expand-RomCuratorProfilePath {
    param(
        [Parameter(Mandatory)][string]$Template,
        [Parameter(Mandatory)][string]$System
    )
    $safeSystem = New-RomCuratorSafeFileName $System
    return $Template.Replace('{system}', $safeSystem) -replace '\\\\','\'
}

function New-RomCuratorSafeFileName {
    param([AllowNull()][string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return 'unknown' }
    $invalid = [IO.Path]::GetInvalidFileNameChars()
    $chars = foreach ($ch in $Name.ToCharArray()) {
        if ($invalid -contains $ch) { '_' } else { $ch }
    }
    $value = -join $chars
    $value = $value -replace '\s+',' '
    $value = $value.Trim(' ', '.')
    if ([string]::IsNullOrWhiteSpace($value)) { return 'unknown' }
    return $value
}

function Get-RomCuratorNonConflictingPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $Path }
    $dir = Split-Path -Parent $Path
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    $ext = [IO.Path]::GetExtension($Path)
    for ($i = 1; $i -lt 10000; $i++) {
        $candidate = Join-Path $dir ("$name ($i)$ext")
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    throw "Could not find non-conflicting path for $Path"
}

function Test-RomCuratorCopyableItem {
    param([AllowNull()][object]$Item)
    if ($null -eq $Item) { return $false }
    $path = [string](Get-RomCuratorObjectProperty -Object $Item -Name 'RomPath' -Default '')
    $extension = [string](Get-RomCuratorObjectProperty -Object $Item -Name 'Extension' -Default '')
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    if ($extension -eq '[missing]') { return $false }
    return $true
}

function Get-RomCuratorSystemSummaries {
    param(
        [object[]]$Items,
        [object[]]$VisibleItems,
        [string[]]$ExcludedSystems,
        [string[]]$FullSelectedSystems
    )
    $visibleBySystem = @{}
    foreach ($item in @($VisibleItems)) {
        $system = [string](Get-RomCuratorObjectProperty -Object $item -Name 'System' -Default '')
        if ([string]::IsNullOrWhiteSpace($system)) { continue }
        if (-not $visibleBySystem.ContainsKey($system)) { $visibleBySystem[$system] = 0 }
        $visibleBySystem[$system]++
    }
    $excluded = New-Object System.Collections.Generic.HashSet[string]
    foreach ($system in @($ExcludedSystems)) { if ($system) { [void]$excluded.Add([string]$system) } }
    $fullSelected = New-Object System.Collections.Generic.HashSet[string]
    foreach ($system in @($FullSelectedSystems)) { if ($system) { [void]$fullSelected.Add([string]$system) } }

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($group in @($Items | Where-Object { $_ -and (Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default '') } | Group-Object System | Sort-Object Name)) {
        $groupItems = @($group.Group)
        $copyable = @($groupItems | Where-Object { Test-RomCuratorCopyableItem -Item $_ })
        $selected = @($groupItems | Where-Object { [bool](Get-RomCuratorObjectProperty -Object $_ -Name 'Selected' -Default $false) })
        $selectedCopyable = @($selected | Where-Object { Test-RomCuratorCopyableItem -Item $_ })
        $duplicateItems = @($groupItems | Where-Object { [bool](Get-RomCuratorObjectProperty -Object $_ -Name 'IsDuplicate' -Default $false) })
        $duplicateGroups = @($duplicateItems | Group-Object DuplicateKey)
        $romSize = [int64](Get-RomCuratorMeasureSum -Items $copyable -Property FileSize)
        $selectedRomSize = [int64](Get-RomCuratorMeasureSum -Items $selectedCopyable -Property FileSize)
        $mediaSize = [int64](Get-RomCuratorMeasureSum -Items $copyable -Property MediaSize)
        $warnings = @($groupItems | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-RomCuratorObjectProperty -Object $_ -Name 'IssuesText' -Default '')) })
        [void]$rows.Add([pscustomobject]@{
            System = $group.Name
            DisplayName = $group.Name
            Selected = $true
            FullSystemSelected = $fullSelected.Contains($group.Name)
            ExcludedFromAutoSelect = $excluded.Contains($group.Name)
            TotalEntries = $groupItems.Count
            CopyableGames = $copyable.Count
            MatchedGamelistEntries = @($groupItems | Where-Object { [bool](Get-RomCuratorObjectProperty -Object $_ -Name 'HasGamelistEntry' -Default $false) -and (Test-RomCuratorCopyableItem -Item $_) }).Count
            MissingRomEntries = @($groupItems | Where-Object { [string](Get-RomCuratorObjectProperty -Object $_ -Name 'Extension' -Default '') -eq '[missing]' }).Count
            OrphanRoms = @($groupItems | Where-Object { [string](Get-RomCuratorObjectProperty -Object $_ -Name 'IssuesText' -Default '') -like '*Orphan ROM*' }).Count
            SelectedGames = $selected.Count
            SelectedCopyableGames = $selectedCopyable.Count
            VisibleGames = if ($visibleBySystem.ContainsKey($group.Name)) { [int]$visibleBySystem[$group.Name] } else { 0 }
            DuplicateGroups = $duplicateGroups.Count
            DuplicateItems = $duplicateItems.Count
            RomSize = $romSize
            RomSizeGB = [Math]::Round($romSize / 1GB, 3)
            RomSizeText = Format-RomCuratorSize $romSize
            SelectedRomSize = $selectedRomSize
            SelectedRomSizeGB = [Math]::Round($selectedRomSize / 1GB, 3)
            SelectedRomSizeText = Format-RomCuratorSize $selectedRomSize
            MediaSize = $mediaSize
            MediaSizeGB = [Math]::Round($mediaSize / 1GB, 3)
            MediaSizeText = Format-RomCuratorSize $mediaSize
            TotalExportSize = $romSize + $mediaSize
            TotalExportSizeText = Format-RomCuratorSize ($romSize + $mediaSize)
            WarningCount = $warnings.Count
            WarningsText = if ($warnings.Count -gt 0) { "$($warnings.Count) warning(s)" } else { '' }
        })
    }
    return @($rows.ToArray())
}

function Get-RomCuratorFullSystemSelectionSummary {
    param(
        [object[]]$Items,
        [string[]]$Systems
    )
    $wanted = New-Object System.Collections.Generic.HashSet[string]
    foreach ($system in @($Systems)) { if ($system) { [void]$wanted.Add([string]$system) } }
    $itemsForSystems = @($Items | Where-Object { $wanted.Contains([string](Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default '')) -and (Test-RomCuratorCopyableItem -Item $_) })
    $romSize = [int64](Get-RomCuratorMeasureSum -Items $itemsForSystems -Property FileSize)
    $mediaSize = [int64](Get-RomCuratorMeasureSum -Items $itemsForSystems -Property MediaSize)
    [pscustomobject]@{
        SystemCount = $wanted.Count
        GameCount = $itemsForSystems.Count
        RomSize = $romSize
        RomSizeGB = [Math]::Round($romSize / 1GB, 3)
        MediaSize = $mediaSize
        MediaSizeGB = [Math]::Round($mediaSize / 1GB, 3)
        TotalSize = $romSize + $mediaSize
        TotalSizeGB = [Math]::Round(($romSize + $mediaSize) / 1GB, 3)
        Systems = @($Systems)
    }
}

function Get-RomCuratorExportPlan {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][object]$Settings,
        [string[]]$FullSystems,
        [switch]$IgnoreItemSelection,
        [switch]$IncludeMedia,
        [switch]$IncludeGamelists
    )
    $destination = $Settings.ExportDestination
    if ([string]::IsNullOrWhiteSpace($destination)) { throw 'Export destination is not configured.' }
    $profile = Get-RomCuratorExportProfile -Id $Settings.ExportProfile -Settings $Settings
    if (-not $profile) { throw "Export profile not found: $($Settings.ExportProfile)" }
    $aliasMap = Get-RomCuratorSystemAliases -Settings $Settings
    $copyItems = New-Object System.Collections.Generic.List[object]
    $fullSystemNames = New-Object System.Collections.Generic.List[string]
    $wantedFullSystems = @{}
    foreach ($systemName in @($FullSystems)) {
        if ([string]::IsNullOrWhiteSpace($systemName)) { continue }
        $systemKey = [string]$systemName
        if (-not $wantedFullSystems.ContainsKey($systemKey)) {
            [void]$fullSystemNames.Add($systemKey)
        }
        $wantedFullSystems[$systemKey] = $true
        $canonicalSystem = Resolve-RomCuratorSystemAlias -System $systemKey -Settings $Settings -AliasMap $aliasMap
        if (-not [string]::IsNullOrWhiteSpace($canonicalSystem)) {
            $wantedFullSystems[[string]$canonicalSystem] = $true
        }
    }

    $selected = @($Items | Where-Object {
        $copyable = Test-RomCuratorCopyableItem -Item $_
        $manual = (-not $IgnoreItemSelection) -and [bool](Get-RomCuratorObjectProperty -Object $_ -Name 'Selected' -Default $false)
        $system = [string](Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default '')
        $fullSystem = (-not [string]::IsNullOrWhiteSpace($system)) -and $wantedFullSystems.ContainsKey($system)
        $copyable -and ($manual -or $fullSystem)
    })
    $seenSources = New-Object System.Collections.Generic.HashSet[string]
    foreach ($item in $selected) {
        $sourceKey = [string](Get-RomCuratorObjectProperty -Object $item -Name 'RomPath' -Default '')
        if (-not $seenSources.Add($sourceKey)) { continue }
        $targetSystem = Resolve-RomCuratorSystemAlias -System $item.System -Settings $Settings -AliasMap $aliasMap
        $romRootRel = Expand-RomCuratorProfilePath -Template $profile.RomRoot -System $targetSystem
        $targetRel = if ($item.RelativePath) { $item.RelativePath } else { New-RomCuratorSafeFileName $item.OriginalName }
        $dest = Join-Path (Join-Path $destination $romRootRel) $targetRel
        $copyItems.Add([pscustomobject]@{
            Kind='ROM'; System=$item.System; CleanName=$item.CleanName; Source=$item.RomPath; Destination=$dest; Size=[int64]$item.FileSize; IsFolder=[bool]$item.IsFolder; Item=$item
        })
        if ($IncludeMedia) {
            foreach ($mediaProp in @('ImagePath','ThumbnailPath','MarqueePath','VideoPath','FanartPath','BoxartPath')) {
                $src = $item.$mediaProp
                if ([string]::IsNullOrWhiteSpace($src) -or -not (Test-Path -LiteralPath $src)) { continue }
                $mediaRootRel = Expand-RomCuratorProfilePath -Template $profile.MediaRoot -System $targetSystem
                $bucket = switch -Regex ($mediaProp) {
                    'Video' { 'videos'; break }
                    'Marquee' { 'marquees'; break }
                    'Fanart' { 'fanart'; break }
                    default { 'images' }
                }
                $destMedia = Join-Path (Join-Path (Join-Path $destination $mediaRootRel) $bucket) (Split-Path -Leaf $src)
                $size = try { [int64](Get-Item -LiteralPath $src).Length } catch { [int64]0 }
                $copyItems.Add([pscustomobject]@{
                    Kind=$mediaProp; System=$item.System; CleanName=$item.CleanName; Source=$src; Destination=$destMedia; Size=$size; IsFolder=$false; Item=$item
                })
            }
        }
    }
    $totalBytes = [int64](Get-RomCuratorMeasureSum -Items @($copyItems.ToArray()) -Property Size)
    $perSystem = @($selected | Group-Object System | ForEach-Object {
        $systemSize = [int64](Get-RomCuratorMeasureSum -Items @($_.Group) -Property FileSize)
        [pscustomobject]@{
            System=$_.Name
            Count=$_.Count
            Size=$systemSize
            SizeGB=[Math]::Round(([double]$systemSize / 1GB), 3)
            SizeText=Format-RomCuratorSize $systemSize
            FullSystem=$wantedFullSystems.ContainsKey($_.Name)
        }
    })
    [pscustomobject]@{
        CreatedAt = (Get-Date)
        Destination = $destination
        Profile = $profile
        IncludeMedia = [bool]$IncludeMedia
        IncludeGamelists = [bool]$IncludeGamelists
        FullSystems = [string[]]$fullSystemNames.ToArray()
        PlanMode = if ($IgnoreItemSelection) { 'FullSystems' } elseif ($fullSystemNames.Count -gt 0) { 'ItemsAndFullSystems' } else { 'Items' }
        GameSelectedCount = @($copyItems.ToArray() | Where-Object { $_.Kind -eq 'ROM' }).Count
        SelectedCount = @($copyItems.ToArray() | Where-Object { $_.Kind -in @('ROM','SystemFolder') }).Count
        FullSystemCount = $fullSystemNames.Count
        CopyItems = @($copyItems.ToArray())
        TotalBytes = $totalBytes
        TotalGB = [Math]::Round($totalBytes / 1GB, 3)
        TotalSizeText = Format-RomCuratorSize $totalBytes
        PerSystem = $perSystem
    }
}

function Copy-RomCuratorFileVerified {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [ValidateSet('Skip','Overwrite','Rename','Compare')][string]$OverwritePolicy = 'Skip'
    )
    $actualDestination = $Destination
    if (Test-Path -LiteralPath $actualDestination) {
        switch ($OverwritePolicy) {
            'Skip' { return [pscustomobject]@{ Status='Skipped'; Destination=$actualDestination; Bytes=0; Message='Destination exists' } }
            'Rename' { $actualDestination = Get-RomCuratorNonConflictingPath $actualDestination }
            'Compare' {
                $srcItem = Get-Item -LiteralPath $Source -ErrorAction Stop
                $dstItem = Get-Item -LiteralPath $actualDestination -ErrorAction Stop
                if ($srcItem.Length -eq $dstItem.Length -and $srcItem.LastWriteTime -le $dstItem.LastWriteTime.AddSeconds(2)) {
                    return [pscustomobject]@{ Status='Skipped'; Destination=$actualDestination; Bytes=0; Message='Destination same size/date' }
                }
            }
            'Overwrite' {}
        }
    }
    Ensure-RomCuratorDirectory (Split-Path -Parent $actualDestination) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $actualDestination -Force:($OverwritePolicy -in @('Overwrite','Compare')) -ErrorAction Stop
    $srcLen = (Get-Item -LiteralPath $Source -ErrorAction Stop).Length
    $dstLen = (Get-Item -LiteralPath $actualDestination -ErrorAction Stop).Length
    if ($srcLen -ne $dstLen) { throw "Size verification failed for $actualDestination" }
    return [pscustomobject]@{ Status='Copied'; Destination=$actualDestination; Bytes=[int64]$srcLen; Message='OK' }
}

function Copy-RomCuratorDirectoryVerified {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [ValidateSet('Skip','Overwrite','Rename','Compare')][string]$OverwritePolicy = 'Skip',
        [object]$CancellationToken,
        [scriptblock]$ProgressCallback
    )
    $results = New-Object System.Collections.Generic.List[object]
    $sourceRoot = [IO.Path]::GetFullPath($Source).TrimEnd('\') + '\'
    foreach ($file in Get-ChildItem -LiteralPath $Source -File -Recurse -Force -ErrorAction Stop) {
        if ($CancellationToken -and $CancellationToken.IsCancellationRequested) { break }
        $rel = $file.FullName.Substring($sourceRoot.Length)
        $destFile = Join-Path $Destination $rel
        if ($ProgressCallback) { & $ProgressCallback ([pscustomobject]@{ Operation='copy-file'; Current=$file.FullName }) }
        try {
            $results.Add((Copy-RomCuratorFileVerified -Source $file.FullName -Destination $destFile -OverwritePolicy $OverwritePolicy))
        } catch {
            $results.Add([pscustomobject]@{ Status='Error'; Destination=$destFile; Bytes=0; Message=$_.Exception.Message })
        }
    }
    return $results
}

function New-RomCuratorGamelistXml {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][object]$Settings,
        [Parameter(Mandatory)][object]$Profile,
        [Parameter(Mandatory)][string]$System,
        [string[]]$FullSystems
    )
    $doc = [System.Xml.Linq.XDocument]::new([System.Xml.Linq.XElement]::new('gameList'))
    $root = $doc.Root
    $fullWanted = New-Object System.Collections.Generic.HashSet[string]
    foreach ($systemName in @($FullSystems)) { if ($systemName) { [void]$fullWanted.Add([string]$systemName) } }
    foreach ($item in $Items | Where-Object { $_.System -eq $System -and (($_.Selected) -or $fullWanted.Contains([string]$_.System)) -and $_.Extension -ne '[missing]' }) {
        $game = [System.Xml.Linq.XElement]::new('game')
        $pathValue = './' + (($item.RelativePath -replace '\\','/') -replace '^\./','')
        $game.Add([System.Xml.Linq.XElement]::new('path', $pathValue))
        $game.Add([System.Xml.Linq.XElement]::new('name', $item.CleanName))
        if ($item.Description) { $game.Add([System.Xml.Linq.XElement]::new('desc', $item.Description)) }
        if ($item.Genre) { $game.Add([System.Xml.Linq.XElement]::new('genre', $item.Genre)) }
        if ($item.Players) { $game.Add([System.Xml.Linq.XElement]::new('players', $item.Players)) }
        if ($item.Favorite) { $game.Add([System.Xml.Linq.XElement]::new('favorite', $item.Favorite)) }
        if ($item.ReleaseDate) { $game.Add([System.Xml.Linq.XElement]::new('releasedate', $item.ReleaseDate)) }
        if ($item.Developer) { $game.Add([System.Xml.Linq.XElement]::new('developer', $item.Developer)) }
        if ($item.Publisher) { $game.Add([System.Xml.Linq.XElement]::new('publisher', $item.Publisher)) }
        if ($item.CriticScore) { $game.Add([System.Xml.Linq.XElement]::new('metacriticScore', [string]$item.CriticScore)) }
        if ($item.RatingTitleMatched) { $game.Add([System.Xml.Linq.XElement]::new('metacriticTitle', $item.RatingTitleMatched)) }
        $root.Add($game)
    }
    return $doc
}

function Write-RomCuratorManifest {
    param(
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][object[]]$Results,
        [Parameter(Mandatory)][string]$OutputFolder,
        [object[]]$Warnings
    )
    Ensure-RomCuratorDirectory $OutputFolder | Out-Null
    $manifestRows = @($Results | ForEach-Object {
        [pscustomobject]@{
            source_path = $_.Source
            destination_path = $_.Destination
            system = $_.System
            clean_name = $_.CleanName
            kind = $_.Kind
            file_size = $_.Size
            media_copied = ($_.Kind -ne 'ROM')
            metacritic_rating = $_.CriticScore
            match_confidence = $_.MatchConfidence
            copy_status = $_.Status
            errors_warnings = $_.Message
        }
    })
    $jsonPath = Join-Path $OutputFolder 'export_manifest.json'
    $csvPath = Join-Path $OutputFolder 'export_manifest.csv'
    $logPath = Join-Path $OutputFolder 'export_log.txt'
    $warningsPath = Join-Path $OutputFolder 'warnings.txt'
    $manifest = [pscustomobject]@{
        generated_at = (Get-Date).ToString('o')
        profile = $Plan.Profile.Id
        destination = $Plan.Destination
        total_bytes = $Plan.TotalBytes
        selected_count = $Plan.SelectedCount
        entries = $manifestRows
    }
    $manifest | ConvertTo-RomCuratorJson | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $manifestRows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    @(
        "RomCurator export log"
        "Generated: $(Get-Date -Format o)"
        "Destination: $($Plan.Destination)"
        "Profile: $($Plan.Profile.Name)"
        "Items: $($Results.Count)"
        ''
        foreach ($result in $Results) { "[$($result.Status)] $($result.Kind) $($result.Source) -> $($result.Destination) $($result.Message)" }
    ) | Set-Content -LiteralPath $logPath -Encoding UTF8
    if ($Warnings -and $Warnings.Count -gt 0) {
        @($Warnings | ForEach-Object { "[$($_.Severity)] $($_.Area) $($_.System) $($_.Message) $($_.Path)" }) | Set-Content -LiteralPath $warningsPath -Encoding UTF8
    }
    [pscustomobject]@{ Json=$jsonPath; Csv=$csvPath; Log=$logPath; Warnings=$warningsPath }
}

function Invoke-RomCuratorExport {
    param(
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][object[]]$AllItems,
        [ValidateSet('Skip','Overwrite','Rename','Compare')][string]$OverwritePolicy = 'Skip',
        [switch]$DryRun,
        [object]$CancellationToken,
        [scriptblock]$ProgressCallback
    )
    $results = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[object]
    $copiedBytes = [int64]0
    $index = 0
    $started = Get-Date
    foreach ($copy in @($Plan.CopyItems)) {
        if ($CancellationToken -and $CancellationToken.IsCancellationRequested) { break }
        $index++
        if ($ProgressCallback) {
            $elapsed = [Math]::Max(0.1, ((Get-Date) - $started).TotalSeconds)
            $speed = $copiedBytes / $elapsed
            $remaining = if ($speed -gt 0) { [TimeSpan]::FromSeconds([Math]::Max(0, ($Plan.TotalBytes - $copiedBytes) / $speed)) } else { [TimeSpan]::Zero }
            & $ProgressCallback ([pscustomobject]@{ Operation='export'; Current=$copy.Source; Index=$index; Count=$Plan.CopyItems.Count; BytesCopied=$copiedBytes; TotalBytes=$Plan.TotalBytes; SpeedBytesPerSecond=$speed; Remaining=$remaining })
        }
        if ($DryRun) {
            $critic = Get-RomCuratorObjectProperty -Object $copy.Item -Name 'CriticScore' -Default $null
            $confidence = Get-RomCuratorObjectProperty -Object $copy.Item -Name 'MatchConfidence' -Default $null
            $results.Add([pscustomobject]@{
                Status='DryRun'; Kind=$copy.Kind; System=$copy.System; CleanName=$copy.CleanName; Source=$copy.Source; Destination=$copy.Destination; Size=$copy.Size
                CriticScore=$critic; MatchConfidence=$confidence; Message='Preview only'
            })
            continue
        }
        try {
            if ($copy.IsFolder) {
                $copyResult = Copy-RomCuratorDirectoryVerified -Source $copy.Source -Destination $copy.Destination -OverwritePolicy $OverwritePolicy -CancellationToken $CancellationToken -ProgressCallback $ProgressCallback
                foreach ($r in $copyResult) {
                    $copiedBytes += [int64]$r.Bytes
                    $critic = Get-RomCuratorObjectProperty -Object $copy.Item -Name 'CriticScore' -Default $null
                    $confidence = Get-RomCuratorObjectProperty -Object $copy.Item -Name 'MatchConfidence' -Default $null
                    $results.Add([pscustomobject]@{
                        Status=$r.Status; Kind=$copy.Kind; System=$copy.System; CleanName=$copy.CleanName; Source=$copy.Source; Destination=$r.Destination; Size=$r.Bytes
                        CriticScore=$critic; MatchConfidence=$confidence; Message=$r.Message
                    })
                }
            } else {
                $r = Copy-RomCuratorFileVerified -Source $copy.Source -Destination $copy.Destination -OverwritePolicy $OverwritePolicy
                $copiedBytes += [int64]$r.Bytes
                $critic = Get-RomCuratorObjectProperty -Object $copy.Item -Name 'CriticScore' -Default $null
                $confidence = Get-RomCuratorObjectProperty -Object $copy.Item -Name 'MatchConfidence' -Default $null
                $results.Add([pscustomobject]@{
                    Status=$r.Status; Kind=$copy.Kind; System=$copy.System; CleanName=$copy.CleanName; Source=$copy.Source; Destination=$r.Destination; Size=$copy.Size
                    CriticScore=$critic; MatchConfidence=$confidence; Message=$r.Message
                })
            }
        } catch {
            $warnings.Add([pscustomobject]@{ Severity='Error'; Area='Export'; System=$copy.System; Message=$_.Exception.Message; Path=$copy.Source })
            $results.Add([pscustomobject]@{
                Status='Error'; Kind=$copy.Kind; System=$copy.System; CleanName=$copy.CleanName; Source=$copy.Source; Destination=$copy.Destination; Size=$copy.Size
                CriticScore=$copy.Item.CriticScore; MatchConfidence=$copy.Item.MatchConfidence; Message=$_.Exception.Message
            })
        }
    }
    if (-not $DryRun -and $Plan.IncludeGamelists) {
        $fullSystems = @()
        if ($Plan.PSObject.Properties['FullSystems']) { $fullSystems = @($Plan.FullSystems) }
        $systemsForGamelists = @($AllItems | Where-Object { ($_.Selected) -or ($fullSystems -contains $_.System) } | Group-Object System | Select-Object -ExpandProperty Name)
        foreach ($system in $systemsForGamelists) {
            try {
                $targetSystem = Resolve-RomCuratorSystemAlias -System $system -Settings ([pscustomobject]@{}) -AliasMap (Get-RomCuratorDefaultSystemAliases)
                $gamelistRel = Expand-RomCuratorProfilePath -Template $Plan.Profile.GamelistPath -System $targetSystem
                $gamelistPath = Join-Path $Plan.Destination $gamelistRel
                Ensure-RomCuratorDirectory (Split-Path -Parent $gamelistPath) | Out-Null
                $doc = New-RomCuratorGamelistXml -Items $AllItems -Settings ([pscustomobject]@{}) -Profile $Plan.Profile -System $system -FullSystems $fullSystems
                $doc.Save($gamelistPath)
                $results.Add([pscustomobject]@{ Status='Written'; Kind='Gamelist'; System=$system; CleanName=''; Source=''; Destination=$gamelistPath; Size=0; CriticScore=$null; MatchConfidence=$null; Message='Selected gamelist written' })
            } catch {
                $warnings.Add([pscustomobject]@{ Severity='Error'; Area='Gamelist Export'; System=$system; Message=$_.Exception.Message; Path='' })
            }
        }
    }
    $manifestFolder = Join-Path $Plan.Destination ('RomCurator_Export_' + (Get-Date -Format yyyyMMdd_HHmmss))
    $manifestPaths = Write-RomCuratorManifest -Plan $Plan -Results @($results.ToArray()) -OutputFolder $manifestFolder -Warnings @($warnings.ToArray())
    if ($ProgressCallback) { & $ProgressCallback ([pscustomobject]@{ Operation='export-complete'; BytesCopied=$copiedBytes; TotalBytes=$Plan.TotalBytes; Count=$results.Count }) }
    [pscustomobject]@{
        StartedAt=$started
        CompletedAt=(Get-Date)
        Results=@($results.ToArray())
        Warnings=@($warnings.ToArray())
        Manifest=$manifestPaths
        Cancelled=[bool]($CancellationToken -and $CancellationToken.IsCancellationRequested)
    }
}

function Select-RomCuratorByCriteria {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [int]$TopNOverall = 0,
        [int]$TopNPerSystem = 0,
        [int]$MinimumScore = 0,
        [double]$MaxTotalGB = 0,
        [string[]]$IncludeSystems,
        [string[]]$ExcludeSystems,
        [string[]]$IncludeGenres,
        [string[]]$ExcludeGenres,
        [switch]$PreferFavorites,
        [switch]$PreferMultiplayer,
        [switch]$ExcludeHidden,
        [switch]$ExcludeKidGame,
        [switch]$ExcludeUnmatched,
        [switch]$AutoSelectBestDuplicateOnly,
        [switch]$AllowDuplicatesAcrossSystems,
        [string[]]$PreferredSystems,
        [ValidateSet('HighestScore','BestScorePerGB')][string]$FillMode = 'HighestScore'
    )
    foreach ($item in $Items) { Set-RomCuratorObjectProperty -Object $item -Name 'Selected' -Value $false }
    Update-RomCuratorDuplicateGroups -Items $Items -PreferredSystems $PreferredSystems | Out-Null
    if (-not $PSBoundParameters.ContainsKey('AutoSelectBestDuplicateOnly')) { $AutoSelectBestDuplicateOnly = $true }

    $candidates = @($Items | Where-Object {
        $genreText = [string](Get-RomCuratorObjectProperty -Object $_ -Name 'Genre' -Default '')
        $system = [string](Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default '')
        $score = Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default $null
        $hidden = [string](Get-RomCuratorObjectProperty -Object $_ -Name 'Hidden' -Default '')
        $kid = [string](Get-RomCuratorObjectProperty -Object $_ -Name 'KidGame' -Default '')
        $includeGenreMatch = $true
        if ($IncludeGenres) {
            $includeGenreMatch = [bool](@($IncludeGenres | Where-Object { $genreText -like "*$_*" }).Count)
        }
        $excludeGenreMatch = $false
        if ($ExcludeGenres) {
            $excludeGenreMatch = [bool](@($ExcludeGenres | Where-Object { $genreText -like "*$_*" }).Count)
        }
        (Test-RomCuratorCopyableItem -Item $_) -and
        ($MinimumScore -le 0 -or ($score -and [int]$score -ge $MinimumScore)) -and
        (-not $IncludeSystems -or $IncludeSystems -contains $system) -and
        (-not $ExcludeSystems -or $ExcludeSystems -notcontains $system) -and
        $includeGenreMatch -and
        (-not $excludeGenreMatch) -and
        (-not $ExcludeHidden -or $hidden -notmatch '(?i)true|1|yes') -and
        (-not $ExcludeKidGame -or $kid -notmatch '(?i)true|1|yes') -and
        (-not $ExcludeUnmatched -or $score)
    })
    if ($PreferFavorites) {
        $candidates = @($candidates | Sort-Object @{Expression={ if ("$(Get-RomCuratorObjectProperty -Object $_ -Name 'Favorite' -Default '')" -match '(?i)true|1|yes') { 0 } else { 1 } }}, @{Expression={ [int](Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default 0) }; Descending=$true})
    } elseif ($PreferMultiplayer) {
        $candidates = @($candidates | Sort-Object @{Expression={ if ("$(Get-RomCuratorObjectProperty -Object $_ -Name 'Players' -Default '')" -match '[2-9]') { 0 } else { 1 } }}, @{Expression={ [int](Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default 0) }; Descending=$true})
    } elseif ($FillMode -eq 'BestScorePerGB') {
        $candidates = @($candidates | Sort-Object @{Expression={ 
            $size = [double](Get-RomCuratorObjectProperty -Object $_ -Name 'FileSize' -Default 0)
            $score = [double](Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default 0)
            if ($size -gt 0 -and $score -gt 0) { -($score / ($size / 1GB + 0.01)) } else { 0 }
        }})
    } else {
        $candidates = @($candidates | Sort-Object @{Expression={ [int](Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default 0) }; Descending=$true}, @{Expression={ [string](Get-RomCuratorObjectProperty -Object $_ -Name 'CleanName' -Default '') }})
    }
    if ($TopNPerSystem -gt 0) {
        $chosen = @()
        foreach ($group in $candidates | Group-Object System) {
            $chosen += @($group.Group | Select-Object -First $TopNPerSystem)
        }
        $candidates = @($chosen | Sort-Object @{Expression={ [int](Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default 0) }; Descending=$true}, @{Expression={ [string](Get-RomCuratorObjectProperty -Object $_ -Name 'CleanName' -Default '') }})
    }

    $used = [int64]0
    $limit = if ($MaxTotalGB -gt 0) { [int64]($MaxTotalGB * 1GB) } else { [int64]::MaxValue }
    $selectedCount = 0
    $duplicateSkipped = 0
    $seenKeys = New-Object System.Collections.Generic.HashSet[string]
    $bestByKey = @{}
    $candidateGroups = @{}
    foreach ($candidate in $candidates) {
        $key = Get-RomCuratorDuplicateKey -Item $candidate -IncludeSystem:$AllowDuplicatesAcrossSystems
        if (-not $candidateGroups.ContainsKey($key)) { $candidateGroups[$key] = New-Object System.Collections.Generic.List[object] }
        $candidateGroups[$key].Add($candidate)
    }
    foreach ($key in $candidateGroups.Keys) {
        $bestByKey[$key] = Select-RomCuratorBestDuplicate -Items @($candidateGroups[$key].ToArray()) -PreferredSystems $PreferredSystems
    }
    foreach ($item in $candidates) {
        if ($TopNOverall -gt 0 -and $selectedCount -ge $TopNOverall) { break }
        $dupKey = Get-RomCuratorDuplicateKey -Item $item -IncludeSystem:$AllowDuplicatesAcrossSystems
        if ($AutoSelectBestDuplicateOnly -and $bestByKey.ContainsKey($dupKey) -and $bestByKey[$dupKey] -ne $item) {
            $duplicateSkipped++
            continue
        }
        if ($seenKeys.Contains($dupKey)) {
            $duplicateSkipped++
            continue
        }
        $fileSize = [int64](Get-RomCuratorObjectProperty -Object $item -Name 'FileSize' -Default 0)
        if (($used + $fileSize) -le $limit) {
            Set-RomCuratorObjectProperty -Object $item -Name 'Selected' -Value $true
            [void]$seenKeys.Add($dupKey)
            $selectedCount++
            $used += $fileSize
        }
    }
    $summary = Get-RomCuratorSelectionSummary -Items $Items
    Set-RomCuratorObjectProperty -Object $summary -Name 'DuplicatesSkipped' -Value $duplicateSkipped
    Set-RomCuratorObjectProperty -Object $summary -Name 'SystemsExcluded' -Value @(if ($ExcludeSystems) { $ExcludeSystems } else { @() })
    Set-RomCuratorObjectProperty -Object $summary -Name 'AutoSelectCriteria' -Value ([pscustomobject]@{
        TopNOverall=$TopNOverall; TopNPerSystem=$TopNPerSystem; MinimumScore=$MinimumScore; MaxTotalGB=$MaxTotalGB;
        ExcludeSystems=@($ExcludeSystems); AllowDuplicatesAcrossSystems=[bool]$AllowDuplicatesAcrossSystems;
        AutoSelectBestDuplicateOnly=[bool]$AutoSelectBestDuplicateOnly; FillMode=$FillMode
    })
    return $summary
}

function Get-RomCuratorSelectionSummary {
    param([object[]]$Items = @())
    $selected = @($Items | Where-Object { [bool](Get-RomCuratorObjectProperty -Object $_ -Name 'Selected' -Default $false) })
    $selectedCopyable = @($selected | Where-Object { Test-RomCuratorCopyableItem -Item $_ })
    $romSize = [int64](Get-RomCuratorMeasureSum -Items $selectedCopyable -Property FileSize)
    $mediaSize = [int64](Get-RomCuratorMeasureSum -Items $selectedCopyable -Property MediaSize)
    [pscustomobject]@{
        SelectedCount = $selected.Count
        CopyableSelectedCount = $selectedCopyable.Count
        MissingSelectedCount = [Math]::Max(0, $selected.Count - $selectedCopyable.Count)
        RomSize = $romSize
        RomSizeGB = [Math]::Round($romSize / 1GB, 3)
        MediaSize = $mediaSize
        MediaSizeGB = [Math]::Round($mediaSize / 1GB, 3)
        TotalSize = $romSize + $mediaSize
        TotalSizeGB = [Math]::Round(($romSize + $mediaSize) / 1GB, 3)
        PerSystem = @($selectedCopyable | Group-Object System | ForEach-Object {
            $sum = [int64](Get-RomCuratorMeasureSum -Items @($_.Group) -Property FileSize)
            [pscustomobject]@{ System=$_.Name; Count=$_.Count; Size=$sum; SizeGB=[Math]::Round($sum / 1GB, 3) }
        })
        Warnings = @($selected | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-RomCuratorObjectProperty -Object $_ -Name 'IssuesText' -Default '')) } | Select-Object System,CleanName,IssuesText)
        DuplicateGroups = @(@($Items) | Where-Object { [bool](Get-RomCuratorObjectProperty -Object $_ -Name 'IsDuplicate' -Default $false) } | Group-Object DuplicateKey).Count
        DuplicatesSkipped = 0
        SystemsExcluded = @()
    }
}

function Get-RomCuratorPresetFolder {
    param([ValidateSet('user','community')][string]$Type = 'user')
    $dir = Join-Path (Get-RomCuratorAppDataPath 'selection-presets') $Type
    Ensure-RomCuratorDirectory $dir | Out-Null
    return $dir
}

function Remove-RomCuratorCommunityPresetLocalInfo {
    param([Parameter(Mandatory)][string]$Json)
    $changed = 0
    $patterns = @(
        '"[^"]*[A-Za-z]:\\\\[^"]*"',
        '"[^"]*\\\\\\\\[^"]*"',
        '"[^"]*Users\\\\[^"]*"',
        '"[^"]*AppData\\\\[^"]*"'
    )
    $result = $Json
    foreach ($pattern in $patterns) {
        $before = $result
        $result = [regex]::Replace($result, $pattern, '""', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($before -ne $result) { $changed++ }
    }
    [pscustomobject]@{ Json=$result; SanitizedCount=$changed }
}

function Test-RomCuratorCommunityPresetSafe {
    param([Parameter(Mandatory)][object]$Preset)
    $json = $Preset | ConvertTo-RomCuratorJson
    $findings = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in @('[A-Za-z]:\\','\\\\[^\\]+\\','Users\\','AppData\\')) {
        if ($json -match $pattern) { [void]$findings.Add($pattern) }
    }
    [pscustomobject]@{ Safe=($findings.Count -eq 0); Findings=@($findings.ToArray()) }
}

function Save-RomCuratorUserPreset {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Name,
        [object]$Settings,
        [object]$AutoSelectRules,
        [string]$AppVersion = '0.3.0'
    )
    $dir = Get-RomCuratorPresetFolder -Type user
    $safe = New-RomCuratorSafeFileName $Name
    $path = Join-Path $dir "$safe.user.json"
    $selected = @($Items | Where-Object { [bool](Get-RomCuratorObjectProperty -Object $_ -Name 'Selected' -Default $false) } | ForEach-Object {
        [pscustomobject]@{
            System = Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default ''
            RomPath = Get-RomCuratorObjectProperty -Object $_ -Name 'RomPath' -Default ''
            MediaPaths = @(
                Get-RomCuratorObjectProperty -Object $_ -Name 'ImagePath' -Default ''
                Get-RomCuratorObjectProperty -Object $_ -Name 'VideoPath' -Default ''
                Get-RomCuratorObjectProperty -Object $_ -Name 'ThumbnailPath' -Default ''
            ) | Where-Object { $_ }
            CleanName = Get-RomCuratorObjectProperty -Object $_ -Name 'CleanName' -Default ''
            NormalizedName = Get-RomCuratorDuplicateKey -Item $_
            SelectedGameId = "$(Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default '')|$(Get-RomCuratorObjectProperty -Object $_ -Name 'RelativePath' -Default '')"
            CriticScore = Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default $null
            FileSize = Get-RomCuratorObjectProperty -Object $_ -Name 'FileSize' -Default 0
            Genre = Get-RomCuratorObjectProperty -Object $_ -Name 'Genre' -Default ''
            Players = Get-RomCuratorObjectProperty -Object $_ -Name 'Players' -Default ''
        }
    })
    $payload = [pscustomobject]@{
        Type = 'User'
        PresetName = $Name
        CreatedAt = (Get-Date).ToString('o')
        AppVersion = $AppVersion
        ConfiguredRoots = if ($Settings) { Get-RomCuratorSettingsSignature -Settings $Settings } else { $null }
        ExportProfile = if ($Settings) { [string]$Settings.ExportProfile } else { '' }
        AutoSelectRules = $AutoSelectRules
        Games = @($selected)
    }
    $payload | ConvertTo-RomCuratorJson | Set-Content -LiteralPath $path -Encoding UTF8
    return [pscustomobject]@{ Path=$path; Type='User'; SelectedCount=$selected.Count; SanitizedCount=0 }
}

function Save-RomCuratorCommunityPreset {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Name,
        [object]$AutoSelectRules,
        [string]$AppVersion = '0.3.0'
    )
    $dir = Get-RomCuratorPresetFolder -Type community
    $safe = New-RomCuratorSafeFileName $Name
    $path = Join-Path $dir "$safe.community.json"
    $selected = @($Items | Where-Object { [bool](Get-RomCuratorObjectProperty -Object $_ -Name 'Selected' -Default $false) } | ForEach-Object {
        [pscustomobject]@{
            System = Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default ''
            CleanName = Get-RomCuratorObjectProperty -Object $_ -Name 'CleanName' -Default ''
            NormalizedName = Get-RomCuratorDuplicateKey -Item $_
            CriticScore = Get-RomCuratorObjectProperty -Object $_ -Name 'CriticScore' -Default $null
            Genre = Get-RomCuratorObjectProperty -Object $_ -Name 'Genre' -Default ''
            Players = Get-RomCuratorObjectProperty -Object $_ -Name 'Players' -Default ''
        }
    })
    $payload = [pscustomobject]@{
        Type = 'Community'
        PresetName = $Name
        CreatedAt = (Get-Date).ToString('o')
        AppVersion = $AppVersion
        AutoSelectRules = $AutoSelectRules
        Games = @($selected)
    }
    $json = $payload | ConvertTo-RomCuratorJson
    $clean = Remove-RomCuratorCommunityPresetLocalInfo -Json $json
    Set-Content -LiteralPath $path -Value $clean.Json -Encoding UTF8
    $saved = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop
    $safety = Test-RomCuratorCommunityPresetSafe -Preset $saved
    if (-not $safety.Safe) { throw "Community preset still contains local path-like data: $($safety.Findings -join ', ')" }
    return [pscustomobject]@{ Path=$path; Type='Community'; SelectedCount=$selected.Count; SanitizedCount=$clean.SanitizedCount }
}

function Save-RomCuratorSelectionPreset {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Name,
        [object]$Settings,
        [string]$PresetType = 'User',
        [object]$AutoSelectRules,
        [string]$AppVersion = '0.3.0'
    )
    if ($PresetType -eq 'Community') {
        return (Save-RomCuratorCommunityPreset -Items $Items -Name $Name -AutoSelectRules $AutoSelectRules -AppVersion $AppVersion).Path
    }
    return (Save-RomCuratorUserPreset -Items $Items -Name $Name -Settings $Settings -AutoSelectRules $AutoSelectRules -AppVersion $AppVersion).Path
}

function Load-RomCuratorSelectionPreset {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Path
    )
    $preset = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    foreach ($item in $Items) {
        Set-RomCuratorObjectProperty -Object $item -Name 'Selected' -Value $false
        Set-RomCuratorObjectProperty -Object $item -Name 'PresetMatchStatus' -Value ''
    }
    Update-RomCuratorDuplicateGroups -Items $Items | Out-Null

    $entries = @()
    $presetType = 'Legacy'
    if ($preset -is [array]) {
        $entries = @($preset)
    } elseif ($preset.PSObject.Properties['Type']) {
        $presetType = [string]$preset.Type
        $entries = @($preset.Games)
    } else {
        $entries = @($preset)
    }

    $matched = 0
    $missing = 0
    $ambiguous = 0
    $duplicateCandidates = 0
    $aliases = Get-RomCuratorDefaultSystemAliases
    foreach ($entry in $entries) {
        $entrySystem = [string](Get-RomCuratorObjectProperty -Object $entry -Name 'System' -Default '')
        $entryRomPath = [string](Get-RomCuratorObjectProperty -Object $entry -Name 'RomPath' -Default '')
        $entryName = [string](Get-RomCuratorObjectProperty -Object $entry -Name 'CleanName' -Default '')
        $entryKey = [string](Get-RomCuratorObjectProperty -Object $entry -Name 'NormalizedName' -Default '')
        if ([string]::IsNullOrWhiteSpace($entryKey)) { $entryKey = Normalize-RomCuratorGameName -Name $entryName -ForKey }

        $candidates = @()
        if (($presetType -eq 'User' -or $presetType -eq 'Legacy') -and -not [string]::IsNullOrWhiteSpace($entryRomPath)) {
            $candidates = @($Items | Where-Object { [string](Get-RomCuratorObjectProperty -Object $_ -Name 'RomPath' -Default '') -eq $entryRomPath })
        }
        if ($candidates.Count -eq 0) {
            $entryCanonical = Resolve-RomCuratorSystemAlias -System $entrySystem -AliasMap $aliases
            $candidates = @($Items | Where-Object {
                $itemKey = Get-RomCuratorDuplicateKey -Item $_
                $itemSystem = [string](Get-RomCuratorObjectProperty -Object $_ -Name 'System' -Default '')
                $itemCanonical = Resolve-RomCuratorSystemAlias -System $itemSystem -AliasMap $aliases
                $systemOk = [string]::IsNullOrWhiteSpace($entrySystem) -or $itemSystem -eq $entrySystem -or $itemCanonical -eq $entryCanonical
                $itemKey -eq $entryKey -and $systemOk
            })
        }
        if ($candidates.Count -eq 0) {
            $missing++
            continue
        }
        if ($candidates.Count -gt 1) {
            $ambiguous++
            $duplicateCandidates += $candidates.Count
        }
        $chosen = Select-RomCuratorBestDuplicate -Items $candidates
        Set-RomCuratorObjectProperty -Object $chosen -Name 'Selected' -Value $true
        Set-RomCuratorObjectProperty -Object $chosen -Name 'PresetMatchStatus' -Value $(if ($candidates.Count -gt 1) { 'AmbiguousBestChosen' } else { 'Matched' })
        $matched++
    }
    $summary = Get-RomCuratorSelectionSummary -Items $Items
    Set-RomCuratorObjectProperty -Object $summary -Name 'PresetMatches' -Value ([pscustomobject]@{
        Type=$presetType; Matched=$matched; Missing=$missing; Ambiguous=$ambiguous; DuplicateCandidates=$duplicateCandidates
    })
    return $summary
}

Export-ModuleMember -Function *-RomCurator*
