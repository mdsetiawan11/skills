param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Type,

    [string]$Description,
    [string]$AssignedTo,
    [int]$ParentId,
    [string]$IterationPath,
    [string]$BaseUrl = "http://localhost:8181"
)

$ErrorActionPreference = "Stop"

$base = $BaseUrl.TrimEnd("/")

try {
    Invoke-RestMethod -Method Get -Uri "$base/api/health" | Out-Null
}
catch {
    throw "Sprintly backend is not reachable at $base. Start it from backend with: dotnet run"
}

$body = [ordered]@{
    title = $Title
    type = $Type
    description = $null
    assignedTo = $null
    parentId = $null
    iterationPath = $null
}

if (-not [string]::IsNullOrWhiteSpace($Description)) { $body.description = $Description }
if (-not [string]::IsNullOrWhiteSpace($AssignedTo)) { $body.assignedTo = $AssignedTo }
if ($ParentId -gt 0) { $body.parentId = $ParentId }
if (-not [string]::IsNullOrWhiteSpace($IterationPath)) { $body.iterationPath = $IterationPath }

$json = $body | ConvertTo-Json -Depth 8
$project = [System.Uri]::EscapeDataString($ProjectId)
$created = Invoke-RestMethod `
    -Method Post `
    -Uri "$base/api/projects/$project/workitems" `
    -ContentType "application/json" `
    -Body $json

$created | ConvertTo-Json -Depth 8
