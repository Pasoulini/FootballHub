param(
    [switch]$RefreshRainmeter,
    [int]$ThrottleSeconds = 0
)

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$CacheDir = Join-Path $Root "Cache"
$IconDir = Join-Path $Root "Icons"
$DataFile = Join-Path $Root "Data.inc"
$RunStamp = Join-Path $CacheDir "last-run.txt"

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

if ($ThrottleSeconds -gt 0 -and (Test-Path $RunStamp)) {
    $lastRun = (Get-Item $RunStamp).LastWriteTime
    if (((Get-Date) - $lastRun).TotalSeconds -lt $ThrottleSeconds) {
        Write-Output "THROTTLED"
        exit 0
    }
}

function Ensure-BlankPng {
    $blank = Join-Path $CacheDir "blank.png"
    $base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII="
    [IO.File]::WriteAllBytes($blank, [Convert]::FromBase64String($base64))
    return $blank
}
$BlankPng = Ensure-BlankPng
$GoalIcon = Join-Path $IconDir "goal.png"
$PenaltyIcon = Join-Path $IconDir "penalty.png"
$RedCardIcon = Join-Path $IconDir "red-card.png"
$MissedPenaltyIcon = Join-Path $IconDir "missed-penalty.png"

# -------------------------------
# Settings
# -------------------------------
$TodayCardCount = 7
$TomorrowCount = 6
$NotStartedText = "Not started"
$KeepFinishedHours = 24
$EstimatedMatchHours = 2

# Read Scale from .ini
$SkinDir = Split-Path -Parent $Root
$IniFile = Join-Path $SkinDir "FootballHub.ini"
$Scale = 1.0
if (Test-Path $IniFile) {
    $iniContent = [IO.File]::ReadAllText($IniFile, [System.Text.Encoding]::UTF8)
    if ($iniContent -match "(?m)^Scale=([\d.]+)") {
        $Scale = [double]$Matches[1]
    }
}
function S($val) { return [Math]::Round($val * $Scale) }

# ==========================
# User Configuration
# ==========================
$ShowMissedPenalties = $true          # Show missed/saved penalties (true/false)
$PenaltyMinuteDisplay = "AsIs"         # How to show penalty minutes: AsIs, Hide, ShowPen
$FinishedSortOrder = "NewestFirst"     # Finished matches order: NewestFirst, OldestFirst

$Leagues = @(
    @{ Slug = "fifa.world";          Name = "World Cup";        Priority = 1;  Teams = @() },
    @{ Slug = "fifa.cwc";            Name = "Club World Cup";   Priority = 2;  Teams = @() },

    @{ Slug = "uefa.champions";      Name = "Champions League"; Priority = 3;  Teams = @() },
    @{ Slug = "uefa.europa";         Name = "Europa League";    Priority = 4;  Teams = @() },
    @{ Slug = "uefa.europa.conf";    Name = "Conference";       Priority = 5;  Teams = @() },

    @{ Slug = "eng.1";               Name = "Premier League";   Priority = 10; Teams = @("Arsenal", "Chelsea", "Liverpool", "Manchester City", "Man City", "Manchester United", "Man United") },
    @{ Slug = "eng.fa";              Name = "FA Cup";           Priority = 11; Teams = @("Arsenal", "Chelsea", "Liverpool", "Manchester City", "Man City", "Manchester United", "Man United") },
    @{ Slug = "eng.league_cup";      Name = "Carabao Cup";      Priority = 12; Teams = @("Arsenal", "Chelsea", "Liverpool", "Manchester City", "Man City", "Manchester United", "Man United") },

    @{ Slug = "esp.1";               Name = "LaLiga";           Priority = 20; Teams = @("Real Madrid", "Barcelona", "Atletico Madrid", "Atletico") },
    @{ Slug = "esp.copa_del_rey";    Name = "Copa del Rey";     Priority = 21; Teams = @("Real Madrid", "Barcelona", "Atletico Madrid", "Atletico") },

    @{ Slug = "ita.1";               Name = "Serie A";          Priority = 30; Teams = @("Juventus", "Inter", "Internazionale", "AC Milan", "Milan", "Napoli") },
    @{ Slug = "ita.coppa_italia";    Name = "Coppa Italia";     Priority = 31; Teams = @("Juventus", "Inter", "Internazionale", "AC Milan", "Milan", "Napoli") },

    @{ Slug = "ger.1";               Name = "Bundesliga";       Priority = 40; Teams = @("Bayern Munich", "Bayern", "Borussia Dortmund", "Dortmund", "Bayer Leverkusen", "Leverkusen") },
    @{ Slug = "ger.dfb_pokal";       Name = "DFB Pokal";        Priority = 41; Teams = @("Bayern Munich", "Bayern", "Borussia Dortmund", "Dortmund", "Bayer Leverkusen", "Leverkusen") },

    @{ Slug = "fra.1";               Name = "Ligue 1";          Priority = 50; Teams = @("PSG", "Paris Saint-Germain", "Paris SG") },
    @{ Slug = "fra.coupe_de_france"; Name = "Coupe de France";  Priority = 51; Teams = @("PSG", "Paris Saint-Germain", "Paris SG") },

    @{ Slug = "ksa.1";               Name = "Saudi Pro";        Priority = 60; Teams = @("Al Nassr", "Al-Nassr") },
    @{ Slug = "usa.1";               Name = "MLS";              Priority = 70; Teams = @("Inter Miami", "Inter Miami CF") }
)

# -------------------------------
# Helpers
# -------------------------------
function Convert-ToPlainText($text) {
    if ($null -eq $text) { return "" }

    $t = [string]$text
    try {
        $t = $t.Normalize([Text.NormalizationForm]::FormD)
        $t = [Text.RegularExpressions.Regex]::Replace($t, "\p{Mn}", "")
    } catch {}

    $plainPairs = @(
        @([char]0x00C6, "AE"), @([char]0x00E6, "ae"),
        @([char]0x0152, "OE"), @([char]0x0153, "oe"),
        @([char]0x00D8, "O"),  @([char]0x00F8, "o"),
        @([char]0x0141, "L"),  @([char]0x0142, "l"),
        @([char]0x00D0, "D"),  @([char]0x00F0, "d"),
        @([char]0x00DE, "Th"), @([char]0x00FE, "th"),
        @([char]0x00DF, "ss")
    )

    foreach ($pair in $plainPairs) {
        $t = $t.Replace([string]$pair[0], [string]$pair[1])
    }

    return $t
}

function SafeText($text) {
    if ($null -eq $text) { return "" }
    $t = Convert-ToPlainText $text
    $t = $t -replace "\r", " "
    $t = $t -replace "\n", " "
    $t = $t -replace "#", ""
    $t = $t.Trim()
    if ($t.Length -gt 140) {
        $t = $t.Substring(0, 137) + "..."
    }
    return $t
}

function To-ShortName($displayName) {
    if ([string]::IsNullOrWhiteSpace($displayName)) { return "" }
    $parts = $displayName.Trim() -split "\s+"
    if ($parts.Count -ge 2) {
        $first = $parts[0]
        $last = $parts[$parts.Count - 1]
        $initial = $first.Substring(0,1) + "."
        return SafeText ($initial + " " + $last)
    }
    return SafeText $displayName
}

function Get-Json($url) {
    try {
        return Invoke-RestMethod -Uri $url -Headers @{ "User-Agent" = "Mozilla/5.0" } -TimeoutSec 15 -ErrorAction Stop
    } catch {}

    try {
        $json = & curl.exe -L -s --max-time 15 -A "Mozilla/5.0" $url
        if (-not [string]::IsNullOrWhiteSpace($json)) {
            return $json | ConvertFrom-Json
        }
    } catch {}

    return $null
}

function Get-Scoreboard($leagueSlug, $dateText) {
    $url = "https://site.api.espn.com/apis/site/v2/sports/soccer/$leagueSlug/scoreboard?dates=$dateText&limit=100"
    return Get-Json $url
}

function Get-Summary($leagueSlug, $eventId) {
    $url = "https://site.api.espn.com/apis/site/v2/sports/soccer/$leagueSlug/summary?event=$eventId"
    return Get-Json $url
}

function Get-ShootoutData($summary) {
    if (-not $summary -or -not $summary.shootout) { return $null }
    return $summary.shootout
}

function Get-ShootoutScore($summary, $homeId, $awayId) {
    $shootout = Get-ShootoutData $summary
    if (-not $shootout) { return $null }

    $homeScore = 0
    $awayScore = 0
    $homeEvents = @()
    $awayEvents = @()

    foreach ($teamData in $shootout) {
        $teamId = [string]$teamData.id
        $sortedShots = @($teamData.shots | Sort-Object { [int]$_.shotNumber })

        foreach ($shot in $sortedShots) {
            $playerName = if ($shot.player) { SafeText $shot.player } else { "" }
            if ([string]::IsNullOrWhiteSpace($playerName)) { continue }

            $eventObj = [PSCustomObject]@{
                Text = if ($shot.didScore -eq $true) { SafeText $playerName } else { SafeText ("MP: " + $playerName) }
                Type = if ($shot.didScore -eq $true) { "penalty" } else { "missed_penalty" }
                ShotNumber = [int]$shot.ShotNumber
                Color = if ($shot.didScore -eq $true) { "" } else { "255,220,50,255" }
            }

            if ($shot.didScore -eq $true) {
                if ($teamId -eq [string]$homeId) { $homeScore++ }
                elseif ($teamId -eq [string]$awayId) { $awayScore++ }
            }

            if ($teamId -eq [string]$homeId) {
                $homeEvents += $eventObj
            } elseif ($teamId -eq [string]$awayId) {
                $awayEvents += $eventObj
            }
        }
    }

    return @{
        HomeScore = $homeScore
        AwayScore = $awayScore
        HomeEvents = $homeEvents
        AwayEvents = $awayEvents
    }
}

function Get-StatusState($event) {
    if ($event.status.type.state) { return $event.status.type.state }
    if ($event.competitions[0].status.type.state) { return $event.competitions[0].status.type.state }
    return "pre"
}

function Get-StatusText($event) {
    if ($event.status.type.shortDetail) { return $event.status.type.shortDetail }
    if ($event.competitions[0].status.type.shortDetail) { return $event.competitions[0].status.type.shortDetail }
    return ""
}

function Get-StatusBadge($event) {
    $state = Get-StatusState $event
    $detail = Get-StatusText $event

    switch ($state) {
        "in"   { return "LIVE" }
        "post" { return "FT" }
        default {
            try {
                return ([DateTimeOffset]::Parse($event.date)).ToLocalTime().ToString("HH:mm")
            } catch {
                return "UPCOMING"
            }
        }
    }
}

function Get-LocalDateTime($event) {
    try {
        return ([DateTimeOffset]::Parse($event.date)).ToLocalTime().DateTime
    } catch {
        return Get-Date
    }
}

function Get-HomeAway($event) {
    $competition = $event.competitions[0]
    if (-not $competition -or -not $competition.competitors) { return $null }

    $homeCompetitor = $competition.competitors | Where-Object { $_.homeAway -eq "home" } | Select-Object -First 1
    $away = $competition.competitors | Where-Object { $_.homeAway -eq "away" } | Select-Object -First 1

    if (-not $homeCompetitor -and $competition.competitors.Count -ge 1) { $homeCompetitor = $competition.competitors[0] }
    if (-not $away -and $competition.competitors.Count -ge 2) { $away = $competition.competitors[1] }

    if (-not $homeCompetitor -or -not $away) { return $null }

    return @{ Home = $homeCompetitor; Away = $away }
}

function TeamName($team) {
    if ($team.team.shortDisplayName) { return $team.team.shortDisplayName }
    if ($team.team.abbreviation) { return $team.team.abbreviation }
    return $team.team.displayName
}

function Get-TeamSearchText($team) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($field in @("shortDisplayName", "displayName", "name", "abbreviation", "location")) {
        if ($team.team.$field) {
            $parts.Add((Convert-ToPlainText $team.team.$field).ToLowerInvariant())
        }
    }
    return (($parts | Select-Object -Unique) -join " | ")
}

function TeamMatchesImportantList($team, $importantTeams) {
    if (-not $importantTeams -or $importantTeams.Count -eq 0) { return $true }

    $searchText = Get-TeamSearchText $team
    foreach ($importantTeam in $importantTeams) {
        $needle = (Convert-ToPlainText $importantTeam).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($needle) -and $searchText.Contains($needle)) {
            return $true
        }
    }

    return $false
}

function ShouldIncludeLeagueMatch($league, $homeTeam, $awayTeam) {
    if (-not $league.Teams -or $league.Teams.Count -eq 0) { return $true }
    return (TeamMatchesImportantList $homeTeam $league.Teams) -or (TeamMatchesImportantList $awayTeam $league.Teams)
}

function TeamLogo($team) {
    if ($team.team.logos -and $team.team.logos.Count -gt 0 -and $team.team.logos[0].href) {
        return $team.team.logos[0].href
    }
    if ($team.team.logo) {
        return $team.team.logo
    }
    return $null
}

function Save-Logo($url, $filename) {
    $out = Join-Path $CacheDir $filename
    if ([string]::IsNullOrWhiteSpace($url)) {
        return $BlankPng
    }

    try {
        Invoke-WebRequest -Uri $url -OutFile $out -Headers @{ "User-Agent" = "Mozilla/5.0" } -TimeoutSec 20 -ErrorAction Stop | Out-Null
        if (Test-Path $out) {
            return $out
        }
    } catch {}

    try {
        & curl.exe -L -s --max-time 20 -A "Mozilla/5.0" -o $out $url | Out-Null
        if ((Test-Path $out) -and ((Get-Item $out).Length -gt 0)) {
            return $out
        }
    } catch {}

    return $BlankPng
}

function Normalize-GoalText($txt) {
    $t = SafeText $txt
    $t = $t -replace "Goal scored by ", ""
    $t = $t -replace "Goal by ", ""
    return $t
}

function Get-PlayTeamId($play) {
    if ($play.team -and $play.team.id) {
        return [string]$play.team.id
    }
    if ($play.team -and $play.team.'$ref' -and $play.team.'$ref' -match "/teams/(\d+)") {
        return $Matches[1]
    }
    if ($play.athletesInvolved -and $play.athletesInvolved.Count -gt 0 -and $play.athletesInvolved[0].team.id) {
        return [string]$play.athletesInvolved[0].team.id
    }
    return $null
}

function Get-PlayName($play) {
    $name = ""
    if ($play.athletesInvolved -and $play.athletesInvolved.Count -gt 0) {
        if ($play.athletesInvolved[0].shortName) {
            $name = $play.athletesInvolved[0].shortName
        } elseif ($play.athletesInvolved[0].displayName) {
            $name = $play.athletesInvolved[0].displayName
        }
    }

    if ([string]::IsNullOrWhiteSpace($name) -and $play.participants -and $play.participants.Count -gt 0) {
        $firstParticipant = $play.participants[0]
        if ($firstParticipant.athlete) {
            if ($firstParticipant.athlete.shortName) {
                $name = $firstParticipant.athlete.shortName
            } elseif ($firstParticipant.athlete.displayName) {
                $name = To-ShortName $firstParticipant.athlete.displayName
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        if ($play.text) {
            $name = Normalize-GoalText $play.text
        } elseif ($play.shortText) {
            $name = Normalize-GoalText $play.shortText
        }
    }

    return SafeText $name
}

function Get-PlayMinute($play) {
    $minute = ""
    if ($play.clock -and $play.clock.displayValue) {
        $minute = SafeText $play.clock.displayValue
    }
    return $minute
}

function Get-GoalInfo($play) {
    $name = Get-PlayName $play
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    $minute = Get-PlayMinute $play
    $type = "goal"
    if ($play.penaltyKick -eq $true -and -not [string]::IsNullOrWhiteSpace($minute)) {
        switch ($PenaltyMinuteDisplay) {
            "Hide"    { }
            "ShowPen" { $minute = "Pen" }
            default   { $minute = $minute + " (p)" }
        }
        $type = "penalty"
    } elseif ($play.penaltyKick -eq $true) {
        $type = "penalty"
    }

    return [PSCustomObject]@{
        Name = SafeText $name
        Minute = $minute
        Type = $type
    }
}

function Get-RedCardInfo($play) {
    $isRed = $false
    if ($play.redCard -eq $true) { $isRed = $true }
    if ($play.type -and $play.type.text -and ([string]$play.type.text) -match "Red Card") { $isRed = $true }
    if (-not $isRed) { return $null }

    $name = Get-PlayName $play
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    $minute = Get-PlayMinute $play
    $text = ""
    if ([string]::IsNullOrWhiteSpace($minute)) {
        $text = "RC: " + $name
    } else {
        $text = "RC: " + $name + " " + $minute
    }

    return [PSCustomObject]@{
        Text = SafeText $text
        Type = "red"
        Color = "255,80,80,255"
    }
}

function Add-ScorersFromPlays($plays, $homeId, $awayId, $homeScorers, $awayScorers) {
    foreach ($play in $plays) {
        $goal = Get-GoalInfo $play
        if (-not $goal) { continue }

        $teamId = Get-PlayTeamId $play

        if ($teamId -eq [string]$homeId) {
            $homeScorers.Add($goal)
        } elseif ($teamId -eq [string]$awayId) {
            $awayScorers.Add($goal)
        } else {
            if ($homeScorers.Count -le $awayScorers.Count) {
                $homeScorers.Add($goal)
            } else {
                $awayScorers.Add($goal)
            }
        }
    }
}

function Add-RedCardsFromPlays($plays, $homeId, $awayId, $homeRedCards, $awayRedCards) {
    foreach ($play in $plays) {
        $line = Get-RedCardInfo $play
        if (-not $line) { continue }

        $teamId = Get-PlayTeamId $play
        if ($teamId -eq [string]$homeId) {
            $homeRedCards.Add($line)
        } elseif ($teamId -eq [string]$awayId) {
            $awayRedCards.Add($line)
        }
    }
}

function Get-MissedPenaltyInfo($play) {
    $isMissed = $false
    if ($play.type -and $play.type.text) {
        $typeText = [string]$play.type.text
        if ($typeText -match "Missed Penalty|Penalty Miss|Saved Penalty|Penalty Saved|Penalty - Saved|Penalty - Missed") {
            $isMissed = $true
        }
    }
    if (-not $isMissed) { return $null }

    $name = Get-PlayName $play
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    $minute = Get-PlayMinute $play
    $text = ""
    if ([string]::IsNullOrWhiteSpace($minute)) {
        $text = "MP: " + $name
    } else {
        $text = "MP: " + $name + " " + $minute
    }

    return [PSCustomObject]@{
        Text = SafeText $text
        Type = "missed_penalty"
        Color = "255,220,50,255"
    }
}

function Add-MissedPenaltiesFromPlays($plays, $homeId, $awayId, $homeMissed, $awayMissed) {
    foreach ($play in $plays) {
        $missed = Get-MissedPenaltyInfo $play
        if (-not $missed) { continue }

        $teamId = Get-PlayTeamId $play
        if ($teamId -eq [string]$homeId) {
            $homeMissed.Add($missed)
        } elseif ($teamId -eq [string]$awayId) {
            $awayMissed.Add($missed)
        }
    }
}

function Format-ScorerLines($goals) {
    $formatted = New-Object System.Collections.Generic.List[object]
    $validGoals = @($goals | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) })

    foreach ($group in ($validGoals | Group-Object { SafeText $_.Name } | Select-Object -First 4)) {
        $name = SafeText $group.Name
        $minutes = @($group.Group | ForEach-Object { SafeText $_.Minute } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 6)
        $type = if (@($group.Group | Where-Object { $_.Type -eq "penalty" }).Count -gt 0) { "penalty" } else { "goal" }
        $text = ""
        if ($minutes.Count -gt 0) {
            $text = $name + " " + ($minutes -join ", ")
        } else {
            $text = $name
        }
        $sortMinute = 0
        if ($minutes.Count -gt 0) {
            $m = $minutes[0] -replace "[^0-9]", ""
            if ($m) { $sortMinute = [int]$m }
        }
        $formatted.Add([PSCustomObject]@{ Text = SafeText $text; Type = $type; SortMinute = $sortMinute })
    }

    return $formatted.ToArray()
}

function Get-SortMinute($text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return 999 }
    $matches = [regex]::Matches($text, "(\d+)'?")
    if ($matches.Count -gt 0) {
        $last = $matches[$matches.Count - 1]
        return [int]$last.Groups[1].Value
    }
    return 999
}

function Join-EventLines($scorerLines, $redCardLines, $missedPenaltyLines) {
    $all = New-Object System.Collections.Generic.List[object]
    foreach ($line in $scorerLines) {
        if ($line -and -not [string]::IsNullOrWhiteSpace($line.Text)) {
            if (-not ($line.PSObject.Properties.Name -contains "SortMinute")) {
                $line | Add-Member -NotePropertyName "SortMinute" -NotePropertyValue (Get-SortMinute $line.Text) -Force
            }
            $all.Add($line)
        }
    }
    foreach ($line in $redCardLines) {
        if ($line -and -not [string]::IsNullOrWhiteSpace($line.Text)) {
            if (-not ($line.PSObject.Properties.Name -contains "SortMinute")) {
                $line | Add-Member -NotePropertyName "SortMinute" -NotePropertyValue (Get-SortMinute $line.Text) -Force
            }
            $all.Add($line)
        }
    }
    if ($missedPenaltyLines) {
        foreach ($line in $missedPenaltyLines) {
            if ($line -and -not [string]::IsNullOrWhiteSpace($line.Text)) {
                if (-not ($line.PSObject.Properties.Name -contains "SortMinute")) {
                    $line | Add-Member -NotePropertyName "SortMinute" -NotePropertyValue (Get-SortMinute $line.Text) -Force
                }
                $all.Add($line)
            }
        }
    }
    return @($all | Sort-Object { $_.SortMinute } | Select-Object -First 4)
}

function Get-ScorerWidth($lines) {
    $maxLen = 0
    foreach ($line in $lines) {
        $text = if ($line.PSObject.Properties.Name -contains "Text") { [string]$line.Text } else { [string]$line }
        if ($text -and $text.Length -gt $maxLen) {
            $maxLen = $text.Length
        }
    }

    if ($maxLen -gt 30 -or $lines.Count -ge 4) { return 340 }
    if ($maxLen -gt 22 -or $lines.Count -ge 3) { return 300 }
    return 260
}

function Get-ScorerLines($leagueSlug, $event, $homeId, $awayId) {
    $homeScorers = New-Object System.Collections.Generic.List[object]
    $awayScorers = New-Object System.Collections.Generic.List[object]
    $homeRedCards = New-Object System.Collections.Generic.List[object]
    $awayRedCards = New-Object System.Collections.Generic.List[object]
    $homeMissedPenalties = New-Object System.Collections.Generic.List[object]
    $awayMissedPenalties = New-Object System.Collections.Generic.List[object]

    $eventDetails = @()
    $competition = @($event.competitions) | Select-Object -First 1
    if ($competition -and $competition.details) {
        $eventDetails = @($competition.details)
    }
    Add-ScorersFromPlays (@($eventDetails | Where-Object { $_.scoringPlay -eq $true })) $homeId $awayId $homeScorers $awayScorers
    Add-RedCardsFromPlays $eventDetails $homeId $awayId $homeRedCards $awayRedCards
    if ($ShowMissedPenalties) {
        Add-MissedPenaltiesFromPlays $eventDetails $homeId $awayId $homeMissedPenalties $awayMissedPenalties
    }

    $summary = Get-Summary $leagueSlug $event.id
    $shootoutScore = $null
    $shootoutHomeEvents = @()
    $shootoutAwayEvents = @()

    if ($summary) {
        $shootoutData = Get-ShootoutScore $summary $homeId $awayId
        if ($shootoutData) {
            $shootoutScore = @{ Home = $shootoutData.HomeScore; Away = $shootoutData.AwayScore }
            $shootoutHomeEvents = $shootoutData.HomeEvents
            $shootoutAwayEvents = $shootoutData.AwayEvents
        }

        if (($homeScorers.Count + $awayScorers.Count) -eq 0 -and -not $shootoutData) {
            $summaryPlays = @()
            if ($summary.scoringPlays) {
                $summaryPlays = @($summary.scoringPlays)
            } elseif ($summary.plays) {
                $summaryPlays = @($summary.plays)
            }
            Add-ScorersFromPlays (@($summaryPlays | Where-Object { $_.scoringPlay -eq $true })) $homeId $awayId $homeScorers $awayScorers
            Add-RedCardsFromPlays $summaryPlays $homeId $awayId $homeRedCards $awayRedCards
        }

        if ($ShowMissedPenalties) {
            $eventDetails = @()
            if ($summary.plays) {
                $eventDetails = @($summary.plays)
            } elseif ($competition -and $competition.details) {
                $eventDetails = @($competition.details)
            }
            Add-MissedPenaltiesFromPlays $eventDetails $homeId $awayId $homeMissedPenalties $awayMissedPenalties

            if ($summary.keyEvents) {
                Add-MissedPenaltiesFromPlays @($summary.keyEvents) $homeId $awayId $homeMissedPenalties $awayMissedPenalties
            }
        }
    }

    if ($shootoutHomeEvents.Count -gt 0) {
        $homeLines = @($shootoutHomeEvents | Select-Object -First 5)
        $awayLines = @($shootoutAwayEvents | Select-Object -First 5)
    } else {
        $homeLines = @(Join-EventLines (Format-ScorerLines $homeScorers) $homeRedCards $homeMissedPenalties)
        $awayLines = @(Join-EventLines (Format-ScorerLines $awayScorers) $awayRedCards $awayMissedPenalties)
    }

    return @{
        HomeLines = $homeLines
        AwayLines = $awayLines
        HomeWidth = Get-ScorerWidth $homeLines
        AwayWidth = Get-ScorerWidth $awayLines
        Home = SafeText ((@($homeLines | Select-Object -First 3 | ForEach-Object { $_.Text }) -join ", "))
        Away = SafeText ((@($awayLines | Select-Object -First 3 | ForEach-Object { $_.Text }) -join ", "))
        ShootoutScore = $shootoutScore
    }
}

# -------------------------------
# Fetch Today + Tomorrow
# -------------------------------
$now = Get-Date
$localToday = $now.Date
$localTomorrow = $localToday.AddDays(1)
$todayDates = @(
    $localToday.AddDays(-2).ToString("yyyyMMdd"),
    $localToday.AddDays(-1).ToString("yyyyMMdd"),
    $localToday.ToString("yyyyMMdd")
) | Select-Object -Unique
$tomorrowDates = @(
    $localToday.ToString("yyyyMMdd"),
    $localTomorrow.ToString("yyyyMMdd")
) | Select-Object -Unique

$todayEvents = @()
$tomorrowEvents = @()

foreach ($league in $Leagues) {
    foreach ($date in $todayDates) {
        $todayBoard = Get-Scoreboard $league.Slug $date
        if ($todayBoard -and $todayBoard.events) {
            foreach ($ev in $todayBoard.events) {
                $ha = Get-HomeAway $ev
                if (-not $ha) { continue }
                if (-not (ShouldIncludeLeagueMatch $league $ha.Home $ha.Away)) { continue }

                $todayEvents += [PSCustomObject]@{
                    Event = $ev
                    LeagueName = $league.Name
                    LeagueSlug = $league.Slug
                    LeaguePriority = $league.Priority
                    Home = $ha.Home
                    Away = $ha.Away
                    State = Get-StatusState $ev
                    When = Get-LocalDateTime $ev
                }
            }
        }
    }

    foreach ($date in $tomorrowDates) {
        $tomorrowBoard = Get-Scoreboard $league.Slug $date
        if ($tomorrowBoard -and $tomorrowBoard.events) {
            foreach ($ev in $tomorrowBoard.events) {
                $ha = Get-HomeAway $ev
                if (-not $ha) { continue }
                if (-not (ShouldIncludeLeagueMatch $league $ha.Home $ha.Away)) { continue }

                $tomorrowEvents += [PSCustomObject]@{
                    Event = $ev
                    LeagueName = $league.Name
                    LeaguePriority = $league.Priority
                    Home = $ha.Home
                    Away = $ha.Away
                    State = Get-StatusState $ev
                    When = Get-LocalDateTime $ev
                }
            }
        }
    }

    Start-Sleep -Milliseconds 50
}

# dedupe by event id
$todayEvents = $todayEvents | Group-Object { $_.Event.id } | ForEach-Object { $_.Group[0] }
$tomorrowEvents = $tomorrowEvents | Group-Object { $_.Event.id } | ForEach-Object { $_.Group[0] }

function SortRank($state) {
    switch ($state) {
        "in"   { return 0 }
        "pre"  { return 1 }
        "post" { return 2 }
        default { return 3 }
    }
}

function ShouldShowTodayEvent($item) {
    if ($item.State -eq "in") { return $true }
    if ($item.State -eq "pre") { return $item.When.Date -eq $localToday }

    if ($item.State -eq "post") {
        $estimatedEnd = $item.When.AddHours($EstimatedMatchHours)
        return $now -le $estimatedEnd.AddHours($KeepFinishedHours)
    }

    return $false
}

$filteredEvents = @($todayEvents | Where-Object { ShouldShowTodayEvent $_ })

$preInEvents = @($filteredEvents | Where-Object { $_.State -eq "pre" -or $_.State -eq "in" })
$postEvents = @($filteredEvents | Where-Object { $_.State -eq "post" })

$preInSorted = $preInEvents |
    Sort-Object `
        @{ Expression = { SortRank $_.State }; Ascending = $true },
        @{ Expression = { $_.LeaguePriority }; Ascending = $true },
        @{ Expression = { $_.When }; Ascending = $true }

$postSorted = $postEvents |
    Sort-Object `
        @{ Expression = { $_.LeaguePriority }; Ascending = $true },
        @{ Expression = { $_.When }; Ascending = ($FinishedSortOrder -ne "NewestFirst") }

$todaySorted = @($preInSorted) + @($postSorted)

$tomorrowSorted = $tomorrowEvents |
    Where-Object { $_.State -eq "pre" -and $_.When.Date -eq $localTomorrow } |
    Sort-Object `
        @{ Expression = { $_.LeaguePriority }; Ascending = $true },
        @{ Expression = { $_.When }; Ascending = $true }

$cards = @()
foreach ($item in ($todaySorted | Select-Object -First $TodayCardCount)) {
    $homeName = TeamName $item.Home
    $awayName = TeamName $item.Away
    $homeScore = if ($item.Home.score -ne $null -and $item.Home.score -ne "") { [string]$item.Home.score } else { "-" }
    $awayScore = if ($item.Away.score -ne $null -and $item.Away.score -ne "") { [string]$item.Away.score } else { "-" }
    $scoreText = if ($item.State -eq "pre") { $NotStartedText } else { "$homeScore  -  $awayScore" }
    $statusBadge = Get-StatusBadge $item.Event
    $statusText = SafeText (Get-StatusText $item.Event)

    $homeLogoPath = Save-Logo (TeamLogo $item.Home) ("home_" + $item.Event.id + ".png")
    $awayLogoPath = Save-Logo (TeamLogo $item.Away) ("away_" + $item.Event.id + ".png")

    $homeScorers = ""
    $awayScorers = ""
    $homeScorerLines = @()
    $awayScorerLines = @()
    $homeScorerWidth = 260
    $awayScorerWidth = 260

    if ($item.State -eq "in" -or $item.State -eq "post") {
        $sc = Get-ScorerLines $item.LeagueSlug $item.Event $item.Home.team.id $item.Away.team.id
        $homeScorers = $sc.Home
        $awayScorers = $sc.Away
        $homeScorerLines = @($sc.HomeLines)
        $awayScorerLines = @($sc.AwayLines)
        $homeScorerWidth = $sc.HomeWidth
        $awayScorerWidth = $sc.AwayWidth

        if ($sc.ShootoutScore) {
            $scoreText = "(" + $sc.ShootoutScore.Home + ")  " + $homeScore + "  -  " + $awayScore + "  (" + $sc.ShootoutScore.Away + ")"
        }
    }

    $cards += [PSCustomObject]@{
        League = SafeText $item.LeagueName
        Badge = SafeText $statusBadge
        Detail = $statusText
        Home = SafeText $homeName
        Away = SafeText $awayName
        HomeScore = SafeText $homeScore
        AwayScore = SafeText $awayScore
        ScoreText = SafeText $scoreText
        HomeLogo = $homeLogoPath
        AwayLogo = $awayLogoPath
        HomeScorers = SafeText $homeScorers
        AwayScorers = SafeText $awayScorers
        HomeScorerLines = $homeScorerLines
        AwayScorerLines = $awayScorerLines
        HomeScorerWidth = $homeScorerWidth
        AwayScorerWidth = $awayScorerWidth
        Hidden = 0
    }
}

$visibleCardCount = $cards.Count

while ($cards.Count -lt $TodayCardCount) {
    $cards += [PSCustomObject]@{
        League = ""
        Badge = ""
        Detail = ""
        Home = ""
        Away = ""
        HomeScore = ""
        AwayScore = ""
        ScoreText = ""
        HomeLogo = $BlankPng
        AwayLogo = $BlankPng
        HomeScorers = ""
        AwayScorers = ""
        HomeScorerLines = @()
        AwayScorerLines = @()
        HomeScorerWidth = 260
        AwayScorerWidth = 260
        Hidden = 1
    }
}

$tomorrowLines = @()
$tm = @($tomorrowSorted | Select-Object -First $TomorrowCount)
if ($tm.Count -gt 0) {
    foreach ($m in $tm) {
        $time = $m.When.ToString("HH:mm")
        $homeDisplay = TeamName $m.Home
        $awayDisplay = TeamName $m.Away
        $tomorrowLines += "$time  $homeDisplay vs $awayDisplay"
    }
} else {
    $tomorrowLines = @("No major matches found")
}

$updated = "Updated " + (Get-Date).ToString("HH:mm")

$cardBaseY = (S 82)
$cardSpacing = (S 10)
$scorerLineHeight = (S 13)
$cardBaseHeight = (S 100)
$cardYPositions = @()
$cardHeights = @()
$currentY = $cardBaseY

for ($i = 0; $i -lt $cards.Count; $i++) {
    $c = $cards[$i]
    if ($c.Hidden -eq 1) {
        $cardYPositions += $currentY
        $cardHeights += $cardBaseHeight
        continue
    }
    $maxScorers = [Math]::Max($c.HomeScorerLines.Count, $c.AwayScorerLines.Count)
    $cardH = $cardBaseHeight + ($maxScorers * $scorerLineHeight)
    $cardHeights += $cardH
    $cardYPositions += $currentY
    $currentY += $cardH + $cardSpacing
}

$tomorrowBgY = $currentY
$tomorrowTitleY = $tomorrowBgY + (S 12)
$tomorrowLineCount = [Math]::Max(1, [Math]::Min($TomorrowCount, $tomorrowLines.Count))
$tomorrowBgH = (S 42) + ($tomorrowLineCount * (S 15))
$panelH = $tomorrowBgY + $tomorrowBgH + (S 18)

# -------------------------------
# Write Data.inc
# -------------------------------
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("[Variables]")
$lines.Add("LastUpdated=" + (SafeText $updated))
$lines.Add("IconBlank=" + (SafeText $BlankPng))
$lines.Add("IconGoal=" + (SafeText $GoalIcon))
$lines.Add("IconPenalty=" + (SafeText $PenaltyIcon))
$lines.Add("IconRedCard=" + (SafeText $RedCardIcon))
$lines.Add("IconMissedPenalty=" + (SafeText $MissedPenaltyIcon))
$lines.Add("PanelH=" + $panelH)
$lines.Add("TomorrowBgY=" + $tomorrowBgY)
$lines.Add("TomorrowBgH=" + $tomorrowBgH)
$lines.Add("TomorrowTitleY=" + $tomorrowTitleY)
for ($j = 1; $j -le $TomorrowCount; $j++) {
    $tomorrowText = ""
    if ($tomorrowLines.Count -ge $j) {
        $tomorrowText = $tomorrowLines[$j - 1]
    }
    $lines.Add("TomorrowLine${j}=" + (SafeText $tomorrowText))
    $lines.Add("TomorrowLine${j}Y=" + ($tomorrowBgY + (S 30) + (($j - 1) * (S 15))))
}

for ($i = 1; $i -le $TodayCardCount; $i++) {
    $c = $cards[$i - 1]
    $lines.Add("Card${i}Hidden=" + (SafeText $c.Hidden))
    $lines.Add("Card${i}BgY=" + $cardYPositions[$i - 1])
    $lines.Add("Card${i}BgH=" + $cardHeights[$i - 1])
    $lines.Add("Card${i}League=" + (SafeText $c.League))
    $lines.Add("Card${i}Badge=" + (SafeText $c.Badge))
    $lines.Add("Card${i}Detail=" + (SafeText $c.Detail))
    $lines.Add("Card${i}Home=" + (SafeText $c.Home))
    $lines.Add("Card${i}Away=" + (SafeText $c.Away))
    $lines.Add("Card${i}HomeScore=" + (SafeText $c.HomeScore))
    $lines.Add("Card${i}AwayScore=" + (SafeText $c.AwayScore))
    $lines.Add("Card${i}ScoreText=" + (SafeText $c.ScoreText))
    $lines.Add("Card${i}HomeLogo=" + (SafeText $c.HomeLogo))
    $lines.Add("Card${i}AwayLogo=" + (SafeText $c.AwayLogo))
    $lines.Add("Card${i}HomeScorers=" + (SafeText $c.HomeScorers))
    $lines.Add("Card${i}AwayScorers=" + (SafeText $c.AwayScorers))
    $lines.Add("Card${i}HomeScorerW=" + (SafeText $c.HomeScorerWidth))
    $lines.Add("Card${i}AwayScorerW=" + (SafeText $c.AwayScorerWidth))
    for ($j = 1; $j -le 5; $j++) {
        $homeLine = ""
        $awayLine = ""
        $homeIcon = $BlankPng
        $awayIcon = $BlankPng
        $homeColor = ""
        $awayColor = ""
        if ($c.HomeScorerLines -and $c.HomeScorerLines.Count -ge $j) {
            $homeItem = $c.HomeScorerLines[$j - 1]
            $homeLine = if ($homeItem.PSObject.Properties.Name -contains "Text") { $homeItem.Text } else { $homeItem }
            if ($homeItem.PSObject.Properties.Name -contains "Type") {
                switch ($homeItem.Type) {
                    "penalty"         { $homeIcon = $PenaltyIcon }
                    "missed_penalty"  { $homeIcon = $MissedPenaltyIcon }
                    "red"             { $homeIcon = $RedCardIcon }
                    "goal"            { $homeIcon = $GoalIcon }
                    default           { $homeIcon = $BlankPng }
                }
            }
            if ($homeItem.PSObject.Properties.Name -contains "Color" -and $homeItem.Color) {
                $homeColor = $homeItem.Color
            }
        }
        if ($c.AwayScorerLines -and $c.AwayScorerLines.Count -ge $j) {
            $awayItem = $c.AwayScorerLines[$j - 1]
            $awayLine = if ($awayItem.PSObject.Properties.Name -contains "Text") { $awayItem.Text } else { $awayItem }
            if ($awayItem.PSObject.Properties.Name -contains "Type") {
                switch ($awayItem.Type) {
                    "penalty"         { $awayIcon = $PenaltyIcon }
                    "missed_penalty"  { $awayIcon = $MissedPenaltyIcon }
                    "red"             { $awayIcon = $RedCardIcon }
                    "goal"            { $awayIcon = $GoalIcon }
                    default           { $awayIcon = $BlankPng }
                }
            }
            if ($awayItem.PSObject.Properties.Name -contains "Color" -and $awayItem.Color) {
                $awayColor = $awayItem.Color
            }
        }
        $lines.Add("Card${i}HomeScorer${j}=" + (SafeText $homeLine))
        $lines.Add("Card${i}AwayScorer${j}=" + (SafeText $awayLine))
        $lines.Add("Card${i}HomeScorerIcon${j}=" + (SafeText $homeIcon))
        $lines.Add("Card${i}AwayScorerIcon${j}=" + (SafeText $awayIcon))
        $lines.Add("Card${i}HomeScorerColor${j}=" + $(if ($homeColor) { $homeColor } else { "245,247,250,255" }))
        $lines.Add("Card${i}AwayScorerColor${j}=" + $(if ($awayColor) { $awayColor } else { "245,247,250,255" }))
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllLines($DataFile, $lines, $utf8NoBom)
[IO.File]::WriteAllText($RunStamp, (Get-Date).ToString("o"), $utf8NoBom)

if ($RefreshRainmeter) {
    $rainmeterExe = "C:\Program Files\Rainmeter\Rainmeter.exe"
    if (Test-Path $rainmeterExe) {
        & $rainmeterExe "!Refresh" "FootballHub"
    }
}

Write-Output "OK"
