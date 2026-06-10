param(
    [string]$ProjectId,
    [string]$PrdPath,
    [string]$PrdJson,
    [ValidateSet("User Story", "Product Backlog Item")]
    [string]$StoryType = "User Story",
    [string]$AssignedTo,
    [string]$IterationPath,
    [string]$BaseUrl = "http://localhost:8181",
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"

function ConvertTo-TextArray {
    param($Value)

    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) {
        return @($Value | ForEach-Object { "$_" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $text = "$Value"
    return @($text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-MarkdownSection {
    param(
        [string]$Markdown,
        [string]$Heading
    )

    $escaped = [regex]::Escape($Heading)
    $pattern = "(?ms)^##\s+$escaped\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Markdown, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-PrdFromMarkdown {
    param(
        [string]$Markdown,
        [string]$FallbackTitle
    )

    $title = $FallbackTitle
    $titleMatch = [regex]::Match($Markdown, "(?m)^#\s+(.+?)\s*$")
    if ($titleMatch.Success) { $title = $titleMatch.Groups[1].Value.Trim() }

    $userStoriesText = Get-MarkdownSection -Markdown $Markdown -Heading "User Stories"
    $storyMatches = [regex]::Matches($userStoriesText, "(?m)^\s*\d+\.\s+(.+?)\s*$")
    $stories = @($storyMatches | ForEach-Object { $_.Groups[1].Value.Trim() })
    if ($stories.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($userStoriesText)) {
        $stories = @($userStoriesText -split "`r?`n" | ForEach-Object { $_.Trim(" -`t") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $implementation = Get-MarkdownSection -Markdown $Markdown -Heading "Implementation Decisions"
    $testing = Get-MarkdownSection -Markdown $Markdown -Heading "Testing Decisions"

    return [ordered]@{
        title = $title
        problemStatement = Get-MarkdownSection -Markdown $Markdown -Heading "Problem Statement"
        solution = Get-MarkdownSection -Markdown $Markdown -Heading "Solution"
        userStories = $stories
        implementationDecisions = Get-DecisionLines $implementation
        testingDecisions = Get-DecisionLines $testing
        outOfScope = Get-MarkdownSection -Markdown $Markdown -Heading "Out of Scope"
        furtherNotes = Get-MarkdownSection -Markdown $Markdown -Heading "Further Notes"
    }
}

function Get-DecisionLines {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    $matches = [regex]::Matches($Text, "(?m)^\s*(?:[-*]|\d+\.)\s+(.+?)\s*$")
    if ($matches.Count -gt 0) {
        return @($matches | ForEach-Object { $_.Groups[1].Value.Trim() })
    }

    return @($Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-PrdFromJson {
    param([string]$Json)

    $obj = $Json | ConvertFrom-Json
    return [ordered]@{
        title = if ($obj.title) { "$($obj.title)" } else { "PRD Feature" }
        problemStatement = if ($obj.problemStatement) { "$($obj.problemStatement)" } else { "" }
        solution = if ($obj.solution) { "$($obj.solution)" } else { "" }
        userStories = ConvertTo-TextArray $obj.userStories
        implementationDecisions = ConvertTo-TextArray $obj.implementationDecisions
        testingDecisions = ConvertTo-TextArray $obj.testingDecisions
        outOfScope = if ($obj.outOfScope) { "$($obj.outOfScope)" } else { "" }
        furtherNotes = if ($obj.furtherNotes) { "$($obj.furtherNotes)" } else { "" }
    }
}

function ConvertTo-StoryTitle {
    param([string]$Story)

    $match = [regex]::Match($Story, "(?i)^As\s+[^,]+,\s*I want\s+(.+?)(?:,\s*so that\s+.+)?$")
    if ($match.Success) { return (Limit-Text $match.Groups[1].Value.Trim() 120) }
    return (Limit-Text $Story.Trim() 120)
}

function ConvertTo-TaskTitle {
    param([string]$Decision)

    $title = $Decision.Trim()
    $title = [regex]::Replace($title, "(?i)^the\s+", "")
    return (Limit-Text $title 120)
}

function Limit-Text {
    param(
        [string]$Text,
        [int]$MaxLength
    )

    if ($Text.Length -le $MaxLength) { return $Text }
    return $Text.Substring(0, $MaxLength - 1).TrimEnd() + "..."
}

function Test-ActionableDecision {
    param([string]$Decision)

    return $Decision -match "(?i)\b(build|add|update|implement|integrate|validate|test|cover|migrate|expose|persist|remove|refactor|modify|create|wire|load|handle|support|publish|resolve)\b"
}

function Get-Tokens {
    param([string]$Text)

    $stop = @("the", "and", "for", "with", "that", "this", "from", "into", "when", "then", "user", "story", "task", "feature", "want", "need", "should", "will", "can", "able", "using")
    return @([regex]::Matches($Text.ToLowerInvariant(), "[a-z0-9]{3,}") | ForEach-Object { $_.Value } | Where-Object { $stop -notcontains $_ } | Select-Object -Unique)
}

function Find-ParentStoryIndex {
    param(
        [string]$TaskText,
        [array]$Stories
    )

    $taskTokens = @(Get-Tokens $TaskText)
    if ($taskTokens.Count -eq 0) { return $null }

    $bestIndex = $null
    $bestScore = 0
    for ($i = 0; $i -lt $Stories.Count; $i++) {
        $storyTokens = @(Get-Tokens ("$($Stories[$i].title) $($Stories[$i].description)"))
        $score = @($taskTokens | Where-Object { $storyTokens -contains $_ }).Count
        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestIndex = $i
        }
    }

    if ($bestScore -ge 2) { return $bestIndex }
    return $null
}

function New-Description {
    param([System.Collections.IDictionary]$Parts)

    $sections = New-Object System.Collections.Generic.List[string]
    foreach ($key in $Parts.Keys) {
        $value = $Parts[$key]
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $sections.Add("<h3>$key</h3>`n<p>$([System.Net.WebUtility]::HtmlEncode($value).Replace("`r`n", "<br>").Replace("`n", "<br>"))</p>")
        }
    }
    return ($sections -join "`n")
}

function New-WorkItemPlan {
    param([System.Collections.IDictionary]$Prd)

    $featureDescription = New-Description ([ordered]@{
        "Problem Statement" = $Prd.problemStatement
        "Solution" = $Prd.solution
        "Out of Scope" = $Prd.outOfScope
        "Further Notes" = $Prd.furtherNotes
    })

    $stories = @()
    foreach ($story in $Prd.userStories) {
        $stories += [ordered]@{
            title = ConvertTo-StoryTitle $story
            type = $StoryType
            description = New-Description ([ordered]@{ "User Story" = $story })
            source = $story
        }
    }

    $taskInputs = @()
    foreach ($decision in $Prd.implementationDecisions) {
        if (Test-ActionableDecision $decision) { $taskInputs += [ordered]@{ sourceSection = "Implementation Decisions"; text = $decision } }
    }
    foreach ($decision in $Prd.testingDecisions) {
        if (Test-ActionableDecision $decision) { $taskInputs += [ordered]@{ sourceSection = "Testing Decisions"; text = $decision } }
    }

    $tasks = @()
    foreach ($task in $taskInputs) {
        $parentStoryIndex = Find-ParentStoryIndex -TaskText $task.text -Stories $stories
        $tasks += [ordered]@{
            title = ConvertTo-TaskTitle $task.text
            type = "Task"
            description = New-Description ([ordered]@{ $task.sourceSection = $task.text })
            parent = if ($null -ne $parentStoryIndex) { "story:$parentStoryIndex" } else { "feature" }
            source = $task.text
        }
    }

    return [ordered]@{
        feature = [ordered]@{
            title = (Limit-Text $Prd.title 120)
            type = "Feature"
            description = $featureDescription
        }
        stories = $stories
        tasks = $tasks
    }
}

function Invoke-SprintlyGet {
    param([string]$Path)

    Invoke-RestMethod -Method Get -Uri "$script:Base/$Path"
}

function Resolve-ProjectId {
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        $projects = @(Invoke-SprintlyGet "api/projects")
        $names = ($projects | ForEach-Object { $_.name }) -join ", "
        throw "ProjectId is required before creating live Azure DevOps work items. Available projects: $names"
    }

    $projects = @(Invoke-SprintlyGet "api/projects")
    $match = $projects | Where-Object { $_.id -eq $Candidate -or $_.name -eq $Candidate } | Select-Object -First 1
    if ($null -eq $match) {
        $names = ($projects | ForEach-Object { "$($_.name) [$($_.id)]" }) -join ", "
        throw "Project '$Candidate' was not found by Sprintly. Available projects: $names"
    }

    return "$($match.id)"
}

function New-SprintlyWorkItem {
    param(
        [string]$ResolvedProjectId,
        [string]$Title,
        [string]$Type,
        [string]$Description,
        [Nullable[int]]$ParentId
    )

    $body = [ordered]@{
        title = $Title
        type = $Type
        description = $Description
    }
    if (-not [string]::IsNullOrWhiteSpace($AssignedTo)) { $body.assignedTo = $AssignedTo }
    if ($ParentId.HasValue -and $ParentId.Value -gt 0) { $body.parentId = $ParentId.Value }
    if (-not [string]::IsNullOrWhiteSpace($IterationPath)) { $body.iterationPath = $IterationPath }

    $json = $body | ConvertTo-Json -Depth 8
    $project = [System.Uri]::EscapeDataString($ResolvedProjectId)
    Invoke-RestMethod -Method Post -Uri "$script:Base/api/projects/$project/workitems" -ContentType "application/json" -Body $json
}

if ([string]::IsNullOrWhiteSpace($PrdPath) -and [string]::IsNullOrWhiteSpace($PrdJson)) {
    throw "Provide -PrdPath for a Markdown/JSON PRD file or -PrdJson for structured PRD JSON."
}
if (-not [string]::IsNullOrWhiteSpace($PrdPath) -and -not [string]::IsNullOrWhiteSpace($PrdJson)) {
    throw "Provide only one of -PrdPath or -PrdJson."
}

if (-not [string]::IsNullOrWhiteSpace($PrdJson)) {
    $prd = Get-PrdFromJson $PrdJson
}
else {
    if (-not (Test-Path -LiteralPath $PrdPath)) { throw "PRD path not found: $PrdPath" }
    $raw = Get-Content -LiteralPath $PrdPath -Raw
    if ([System.IO.Path]::GetExtension($PrdPath) -eq ".json") {
        $prd = Get-PrdFromJson $raw
    }
    else {
        $fallbackTitle = [System.IO.Path]::GetFileNameWithoutExtension($PrdPath)
        $prd = Get-PrdFromMarkdown -Markdown $raw -FallbackTitle $fallbackTitle
    }
}

$plan = New-WorkItemPlan $prd

if ($PlanOnly) {
    $plan | ConvertTo-Json -Depth 16
    return
}

$script:Base = $BaseUrl.TrimEnd("/")
try {
    Invoke-SprintlyGet "api/health" | Out-Null
}
catch {
    throw "Sprintly backend is not reachable at $script:Base. Start it from backend with: dotnet run"
}

$resolvedProjectId = Resolve-ProjectId $ProjectId

$createdFeature = New-SprintlyWorkItem -ResolvedProjectId $resolvedProjectId -Title $plan.feature.title -Type $plan.feature.type -Description $plan.feature.description -ParentId $null
$createdStories = @()
foreach ($story in $plan.stories) {
    $createdStories += New-SprintlyWorkItem -ResolvedProjectId $resolvedProjectId -Title $story.title -Type $story.type -Description $story.description -ParentId $createdFeature.id
}

$createdTasks = @()
foreach ($task in $plan.tasks) {
    $parentId = $createdFeature.id
    if ($task.parent -match "^story:(\d+)$") {
        $storyIndex = [int]$Matches[1]
        if ($storyIndex -lt $createdStories.Count) { $parentId = $createdStories[$storyIndex].id }
    }
    $createdTasks += New-SprintlyWorkItem -ResolvedProjectId $resolvedProjectId -Title $task.title -Type $task.type -Description $task.description -ParentId $parentId
}

[ordered]@{
    projectId = $resolvedProjectId
    feature = $createdFeature
    stories = $createdStories
    tasks = $createdTasks
} | ConvertTo-Json -Depth 16

