$ErrorActionPreference = 'Stop'

function Extract-JohnData {
    param([string]$Path)

    $lines = Get-Content -Path $Path -Encoding UTF8
    $johnBookNumber = 43
    $inJohn = $false
    $chapters = [ordered]@{}

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -match '^Book No:\s*(\d+)\s*$') {
            $bookNo = [int]$matches[1]
            if ($inJohn -and $bookNo -ne $johnBookNumber) {
                break
            }

            $inJohn = ($bookNo -eq $johnBookNumber)
            continue
        }

        if (-not $inJohn) {
            continue
        }

        if ($line -match '^\S+\s+(\d+):(\d+)\s+(.+)$') {
            $chapter = $matches[1]
            $verse = $matches[2]
            $text = $matches[3].Trim()

            if (-not $chapters.Contains($chapter)) {
                $chapters[$chapter] = [ordered]@{}
            }

            $chapters[$chapter][$verse] = $text
        }
    }

    return [ordered]@{
        book = 'Giang'
        chapters = $chapters
    }
}

function Parse-PartRange {
    param([string]$Part)

    $rangeText = $Part -replace '^[^0-9]+', ''
    if ($rangeText -notmatch '^(\d+):(\d+)(?:-(?:(\d+):)?(\d+))?$') {
        return $null
    }

    $startChapter = [int]$matches[1]
    $startVerse = [int]$matches[2]
    $endChapter = if ([string]::IsNullOrEmpty($matches[3])) { $startChapter } else { [int]$matches[3] }
    $endVerse = if ([string]::IsNullOrEmpty($matches[4])) { $startVerse } else { [int]$matches[4] }

    return [ordered]@{
        startChapter = $startChapter
        startVerse = $startVerse
        endChapter = $endChapter
        endVerse = $endVerse
    }
}

function Get-ChapterMaxVerse {
    param(
        [object]$Book,
        [int]$Chapter
    )

    $chapterKey = [string]$Chapter
    $chapterData = $Book.chapters[$chapterKey]
    if ($null -eq $chapterData) {
        return 0
    }

    $max = ($chapterData.Keys | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum
    if ($null -eq $max) {
        return 0
    }

    return [int]$max
}

function Get-VersesForRange {
    param(
        [object]$Book,
        [object]$Range
    )

    $result = @()

    for ($chapter = $Range.startChapter; $chapter -le $Range.endChapter; $chapter++) {
        $startVerse = if ($chapter -eq $Range.startChapter) { $Range.startVerse } else { 1 }
        $endVerse = if ($chapter -eq $Range.endChapter) { $Range.endVerse } else { Get-ChapterMaxVerse -Book $Book -Chapter $chapter }

        for ($verse = $startVerse; $verse -le $endVerse; $verse++) {
            $chapterKey = [string]$chapter
            $verseKey = [string]$verse

            $chapterData = $Book.chapters[$chapterKey]
            if ($null -ne $chapterData) {
                $verseText = $chapterData[$verseKey]
                if (-not [string]::IsNullOrWhiteSpace($verseText)) {
                $result += [ordered]@{
                    ref = "Giăng $chapter`:$verse"
                    text = $verseText
                }
                }
            }
        }
    }

    return $result
}

$root = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $root '_data'

$john1925 = Extract-JohnData -Path (Join-Path $dataDir 'vie1925.txt')
$john2010 = Extract-JohnData -Path (Join-Path $dataDir 'vie2010.txt')

$sessionsPath = Join-Path $dataDir 'sessions.yml'
$sessionLines = Get-Content -Path $sessionsPath -Encoding UTF8
$weeks = [ordered]@{}
$currentWeek = ''

foreach ($line in $sessionLines) {
    if ($line -match '^(w-\d+):\s*$') {
        $currentWeek = $matches[1]
        $weeks[$currentWeek] = [ordered]@{}
        continue
    }

    if ([string]::IsNullOrEmpty($currentWeek)) {
        continue
    }

    if ($line -match "^\s+title:\s*'([^']+)'\s*$") {
        $weeks[$currentWeek].title = $matches[1]
        continue
    }

    if ($line -match "^\s+part:\s*'([^']+)'\s*$") {
        $weeks[$currentWeek].part = $matches[1]
        continue
    }
}

$johnWeeks = [ordered]@{}
foreach ($weekKey in $weeks.Keys) {
    $part = $weeks[$weekKey].part
    if ([string]::IsNullOrWhiteSpace($part) -or $part -notmatch '\d+:\d+') {
        continue
    }

    $range = Parse-PartRange -Part $part
    if ($null -eq $range) {
        continue
    }

    $johnWeeks[$weekKey] = [ordered]@{
        title = $weeks[$weekKey].title
        part = $part
        vie1925 = Get-VersesForRange -Book $john1925 -Range $range
        vie2010 = Get-VersesForRange -Book $john2010 -Range $range
    }
}

$john1925 | ConvertTo-Json -Depth 100 | Set-Content -Path (Join-Path $dataDir 'john_vie1925.yml') -Encoding UTF8
$john2010 | ConvertTo-Json -Depth 100 | Set-Content -Path (Join-Path $dataDir 'john_vie2010.yml') -Encoding UTF8
$johnWeeks | ConvertTo-Json -Depth 100 | Set-Content -Path (Join-Path $dataDir 'john_weeks.yml') -Encoding UTF8

Write-Output "Generated john_vie1925.yml, john_vie2010.yml, john_weeks.yml"
