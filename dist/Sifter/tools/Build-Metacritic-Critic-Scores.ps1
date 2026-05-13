<#
Metacritic Critic Score JSONL Builder - PowerShell-only version v5

Fixes:
- Page 0 now uses https://www.metacritic.com/browse/game/ with NO ?page=0
- Next pages use Metacritic's current pagination offset:
    local page index 0 -> /browse/game/
    local page index 1 -> /browse/game/?page=2
    local page index 2 -> /browse/game/?page=3
- Removed dependency on [System.Web.HttpUtility]
- Forces parser output into an array so .Count always works
- Retries multiple Metacritic URL patterns per page
- Writes debug HTML/TXT if parsing fails
- Works in Windows PowerShell 5.1 and PowerShell 7+
- No Python required
- No external PowerShell modules required

Output:
  metacritic_game_critic_scores.jsonl
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\metacritic_game_critic_scores.jsonl",
    [int]$StartPage = 0,
    [int]$MaxPages = 591,
    [int]$DelaySeconds = 3,
    [int]$TimeoutSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-UtcIso {
    return [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

function ConvertTo-JsonLine {
    param([object]$Object)

    return ($Object | ConvertTo-Json -Compress -Depth 30)
}

function Get-Sha256Text {
    param([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Html-Decode {
    param([string]$Text)

    if ($null -eq $Text) { return $null }
    return [System.Net.WebUtility]::HtmlDecode($Text)
}

function Clean-Text {
    param([string]$Text)

    if ($null -eq $Text) { return $null }

    $t = $Text -replace "<script[\s\S]*?</script>", " "
    $t = $t -replace "<style[\s\S]*?</style>", " "
    $t = $t -replace "<noscript[\s\S]*?</noscript>", " "
    $t = $t -replace "<[^>]+>", " "
    $t = Html-Decode $t
    $t = $t -replace "\s+", " "
    return $t.Trim()
}

function Get-ReleaseDateText {
    param([string]$Text)

    $m = [regex]::Match($Text, "\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+\d{1,2},\s+\d{4}\b")
    if ($m.Success) { return $m.Value }
    return $null
}

function Get-RatingText {
    param([string]$Text)

    $m = [regex]::Match($Text, "\bRated\s+([A-Z0-9+]+)\b")
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Get-AbsoluteUrl {
    param(
        [string]$BaseUrl,
        [string]$Href
    )

    if ([string]::IsNullOrWhiteSpace($Href)) { return $null }

    try {
        $baseUri = [Uri]::new($BaseUrl)
        $full = [Uri]::new($baseUri, $Href)
        return $full.AbsoluteUri
    }
    catch {
        return $Href
    }
}

function Get-TitleFromListingText {
    param([string]$Text)

    $t = Clean-Text $Text
    if ([string]::IsNullOrWhiteSpace($t)) { return $null }

    # Remove crawler/link-marker style prefix if present, for example "77†1. "
    $t = $t -replace "^\d+†", ""

    # Remove leading rank like "1. " or "1,489. "
    $t = $t -replace "^\d{1,3}(?:,\d{3})*\.\s+", ""

    # Stop at first visible date.
    $dateMatch = [regex]::Match($t, "\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+\d{1,2},\s+\d{4}\b")
    if ($dateMatch.Success) {
        $candidate = $t.Substring(0, $dateMatch.Index).Trim()
        if ($candidate.Length -gt 0) { return $candidate }
    }

    # Stop at Metascore.
    $candidate = ($t -replace "\b\d{1,3}\s+Metascore\b[\s\S]*$", "").Trim()
    if ($candidate.Length -gt 0) { return $candidate }

    return $null
}

function Parse-RecordChunk {
    param(
        [string]$Chunk,
        [string]$PageUrl,
        [int]$PageNumber,
        [string]$DetailHref,
        [double]$BaseConfidence
    )

    $text = Clean-Text $Chunk
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    if ($text -notmatch "\b\d{1,3}\s+Metascore\b") { return $null }

    $scoreMatch = [regex]::Match($text, "\b(?<score>\d{1,3})\s+Metascore\b")
    if (-not $scoreMatch.Success) { return $null }

    $score = [int]$scoreMatch.Groups["score"].Value
    if ($score -lt 0 -or $score -gt 100) { return $null }

    $rank = $null
    $rankMatch = [regex]::Match($text, "(?:^|\s)(?<rank>\d{1,3}(?:,\d{3})*)\.\s+")
    if ($rankMatch.Success) {
        $rank = [int](($rankMatch.Groups["rank"].Value) -replace ",", "")
    }

    $title = Get-TitleFromListingText $text
    if ([string]::IsNullOrWhiteSpace($title)) { return $null }

    $detailUrl = $null
    if (-not [string]::IsNullOrWhiteSpace($DetailHref)) {
        $detailUrl = Get-AbsoluteUrl -BaseUrl $PageUrl -Href $DetailHref
    }

    $confidence = $BaseConfidence
    if ($null -ne $rank) { $confidence += 0.05 }
    if ($null -ne (Get-ReleaseDateText $text)) { $confidence += 0.05 }
    if ($null -ne $detailUrl) { $confidence += 0.10 }
    if ($confidence -gt 0.95) { $confidence = 0.95 }

    return [ordered]@{
        schema_version = 1
        source = "metacritic"
        source_listing_url = $PageUrl
        retrieved_at_utc = Get-UtcIso
        local_page_index = $PageNumber
        rank = $rank
        title = $title
        release_date_text = Get-ReleaseDateText $text
        rating = Get-RatingText $text
        metascore = $score
        metascore_scale = 100
        detail_url = $detailUrl
        parse_confidence = [Math]::Round($confidence, 3)
        raw_text_hash = Get-Sha256Text $text
    }
}

function Parse-RecordsFromHtml {
    param(
        [string]$Html,
        [string]$PageUrl,
        [int]$PageNumber
    )

    $records = New-Object System.Collections.Generic.List[object]
    $seen = @{}

    # Strategy 1: HTML card/link chunks.
    # Allows absolute or relative /game/ links.
    $linkPattern = '<a[^>]+href="(?<href>(?:https://www\.metacritic\.com)?/game/[^"]+)"[^>]*>(?<inner>[\s\S]{0,9000}?)</a>'
    $matches = [regex]::Matches($Html, $linkPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    foreach ($m in $matches) {
        $record = Parse-RecordChunk -Chunk $m.Groups["inner"].Value -PageUrl $PageUrl -PageNumber $PageNumber -DetailHref $m.Groups["href"].Value -BaseConfidence 0.70
        if ($null -eq $record) { continue }

        $dedupeKey = "$($record.rank)|$($record.title)|$($record.metascore)|$($record.detail_url)"
        if ($seen.ContainsKey($dedupeKey)) { continue }
        $seen[$dedupeKey] = $true
        $records.Add($record) | Out-Null
    }

    # Strategy 2: plain text fallback.
    # Works on rendered/text versions:
    # "1. The Legend of Zelda: Ocarina of Time Nov 23, 1998 ... 99 Metascore"
    if ($records.Count -eq 0) {
        $plain = Clean-Text $Html

        $pattern = "(?<chunk>\b\d{1,3}(?:,\d{3})*\.\s+.{1,4500}?\b\d{1,3}\s+Metascore\b)"
        $matches2 = [regex]::Matches($plain, $pattern)

        foreach ($m2 in $matches2) {
            $chunk = $m2.Groups["chunk"].Value

            # Clip after the first Metascore so one regex match does not swallow multiple records.
            $endMatch = [regex]::Match($chunk, "\b\d{1,3}\s+Metascore\b")
            if ($endMatch.Success) {
                $chunk = $chunk.Substring(0, $endMatch.Index + $endMatch.Length)
            }

            $record = Parse-RecordChunk -Chunk $chunk -PageUrl $PageUrl -PageNumber $PageNumber -DetailHref $null -BaseConfidence 0.60
            if ($null -eq $record) { continue }

            $dedupeKey = "$($record.rank)|$($record.title)|$($record.metascore)"
            if ($seen.ContainsKey($dedupeKey)) { continue }
            $seen[$dedupeKey] = $true
            $records.Add($record) | Out-Null
        }
    }

    # Strategy 3: Metacritic may expose JSON blobs containing title/metascore.
    # This is intentionally conservative and only writes records if title + valid metascore are nearby.
    if ($records.Count -eq 0) {
        $jsonishPattern = '"(?:title|name)"\s*:\s*"(?<title>[^"]{1,200})"[\s\S]{0,1500}?"(?:metascore|score)"\s*:\s*(?<score>\d{1,3})'
        $matches3 = [regex]::Matches($Html, $jsonishPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        foreach ($m3 in $matches3) {
            $title = Html-Decode $m3.Groups["title"].Value
            $score = [int]$m3.Groups["score"].Value
            if ($score -lt 0 -or $score -gt 100) { continue }

            $dedupeKey = "json|$title|$score"
            if ($seen.ContainsKey($dedupeKey)) { continue }
            $seen[$dedupeKey] = $true

            $records.Add([ordered]@{
                schema_version = 1
                source = "metacritic"
                source_listing_url = $PageUrl
                retrieved_at_utc = Get-UtcIso
                local_page_index = $PageNumber
                rank = $null
                title = $title
                release_date_text = $null
                rating = $null
                metascore = $score
                metascore_scale = 100
                detail_url = $null
                parse_confidence = 0.50
                raw_text_hash = Get-Sha256Text ($title + "|" + $score)
            }) | Out-Null
        }
    }

    return @($records.ToArray())
}

function Validate-Jsonl {
    param([string]$Path)

    $count = 0
    Get-Content -LiteralPath $Path -Encoding UTF8 | ForEach-Object {
        $line = $_
        if ([string]::IsNullOrWhiteSpace($line)) { return }
        $obj = $line | ConvertFrom-Json
        if ($obj.source -ne "metacritic") {
            throw "Unexpected source on JSONL line $($count + 1): $($obj.source)"
        }
        if ($null -ne $obj.metascore -and ([int]$obj.metascore -lt 0 -or [int]$obj.metascore -gt 100)) {
            throw "Invalid metascore on JSONL line $($count + 1): $($obj.metascore)"
        }
        $count++
    }

    return $count
}

function Get-PageCandidateUrls {
    param([int]$LocalPageIndex)

    $candidates = New-Object System.Collections.Generic.List[string]

    if ($LocalPageIndex -eq 0) {
        # Important: current Metacritic can return empty/no-results for ?page=0.
        $candidates.Add("https://www.metacritic.com/browse/game/") | Out-Null
        $candidates.Add("https://www.metacritic.com/browse/games/score/metascore/all/all/filtered/?sort%3Ddesc=") | Out-Null
        $candidates.Add("https://www.metacritic.com/browse/game/all/all/all-time/metascore/") | Out-Null
    }
    else {
        # Current Metacritic text pagination maps:
        # first page: no page parameter
        # second page/ranks 25+: ?page=2
        $sitePage = $LocalPageIndex + 1

        $candidates.Add("https://www.metacritic.com/browse/game/?page=$sitePage") | Out-Null
        $candidates.Add("https://www.metacritic.com/browse/games/score/metascore/all/all/filtered/?page=$sitePage&sort%3Ddesc=") | Out-Null
        $candidates.Add("https://www.metacritic.com/browse/game/all/all/all-time/metascore/?page=$sitePage") | Out-Null
    }

    # Dedupe while preserving order.
    $seenUrl = @{}
    $deduped = New-Object System.Collections.Generic.List[string]
    foreach ($u in $candidates) {
        if (-not $seenUrl.ContainsKey($u)) {
            $seenUrl[$u] = $true
            $deduped.Add($u) | Out-Null
        }
    }

    return @($deduped.ToArray())
}

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}

$outputDirectory = Split-Path -Parent $OutputPath
if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
    $outputDirectory = "."
}

$errorLog = Join-Path $outputDirectory "metacritic_game_critic_scores.errors.jsonl"
if (Test-Path -LiteralPath $errorLog) {
    Remove-Item -LiteralPath $errorLog -Force
}

$total = 0
$seenGlobal = @{}

$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/147 Safari/537.36"
    "Accept-Language" = "en-US,en;q=0.9"
    "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

Write-Host ""
Write-Host "Metacritic Critic Score JSONL Builder v5"
Write-Host "========================================"
Write-Host "Output: $OutputPath"
Write-Host "Local page indexes: $StartPage through $($StartPage + $MaxPages - 1)"
Write-Host "URL mapping: index 0 -> /browse/game/ ; index 1 -> ?page=2"
Write-Host ""

for ($localPage = $StartPage; $localPage -lt ($StartPage + $MaxPages); $localPage++) {
    $pageWorked = $false
    $lastHtml = $null
    $lastUrl = $null
    $lastError = $null

    $candidateUrls = @(Get-PageCandidateUrls -LocalPageIndex $localPage)

    foreach ($pageUrl in $candidateUrls) {
        Write-Host "[fetch] local_page=$localPage $pageUrl"

        try {
            $response = Invoke-WebRequest -Uri $pageUrl -Headers $headers -TimeoutSec $TimeoutSeconds -UseBasicParsing

            if ($response.StatusCode -eq 403 -or $response.StatusCode -eq 429) {
                throw "HTTP $($response.StatusCode). Metacritic blocked or rate-limited the request."
            }

            $html = [string]$response.Content
            $lastHtml = $html
            $lastUrl = $pageUrl

            $records = @(Parse-RecordsFromHtml -Html $html -PageUrl $pageUrl -PageNumber $localPage)

            if ($records.Count -eq 0) {
                Write-Warning "No records parsed from candidate URL."
                continue
            }

            $wroteThisPage = 0

            foreach ($record in $records) {
                $globalKey = "$($record.rank)|$($record.title)|$($record.release_date_text)|$($record.metascore)"
                if ($seenGlobal.ContainsKey($globalKey)) { continue }

                $seenGlobal[$globalKey] = $true
                Add-Content -LiteralPath $OutputPath -Value (ConvertTo-JsonLine $record) -Encoding UTF8
                $wroteThisPage++
            }

            $total += $wroteThisPage
            Write-Host "[write] local_page=$localPage records=$wroteThisPage total=$total"
            $pageWorked = $true
            break
        }
        catch {
            $lastError = $_.Exception.Message
            Write-Warning $lastError
            continue
        }
    }

    if (-not $pageWorked) {
        if ($null -ne $lastHtml) {
            $debugHtml = Join-Path $outputDirectory ("metacritic_debug_page_{0}.html" -f $localPage)
            Set-Content -LiteralPath $debugHtml -Value $lastHtml -Encoding UTF8

            $plain = Clean-Text $lastHtml
            $debugText = Join-Path $outputDirectory ("metacritic_debug_page_{0}.txt" -f $localPage)
            Set-Content -LiteralPath $debugText -Value $plain -Encoding UTF8
        }
        else {
            $debugHtml = $null
            $debugText = $null
        }

        $err = [ordered]@{
            retrieved_at_utc = Get-UtcIso
            local_page_index = $localPage
            url = $lastUrl
            error = if ($null -ne $lastError) { $lastError } else { "No score records parsed from any candidate URL." }
            debug_html = $debugHtml
            debug_text = $debugText
            candidate_urls = $candidateUrls
            note = "If debug_text contains visible game rows, upload it so the parser can be adjusted. If it contains No Results Found or a bot-check page, Metacritic is not returning usable HTML to PowerShell."
        }
        Add-Content -LiteralPath $errorLog -Value (ConvertTo-JsonLine $err) -Encoding UTF8

        Write-Warning "Could not parse local page index $localPage from any candidate URL."
        Write-Warning "See error log: $errorLog"
        break
    }

    Start-Sleep -Seconds $DelaySeconds
}

if (Test-Path -LiteralPath $OutputPath) {
    $validated = Validate-Jsonl -Path $OutputPath
    Write-Host ""
    Write-Host "[valid] $OutputPath lines=$validated"
    Write-Host ""
    Write-Host "Done."
}
else {
    Write-Host ""
    Write-Warning "Output file was not created."
    Write-Host "Error log: $errorLog"
}
