# Verify that the script is running as part of a pull request
if (-not $env:GITHUB_EVENT_NAME -eq 'pull_request') {
    Write-Error "This GitHub Action can only be run as part of a pull request."
    exit 1
}

# Define the SARIF file pattern
$sarifFiles = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Recurse -Filter *.sarif

if ($sarifFiles.Count -eq 0) {
    Write-Error "No SARIF files found. Please ensure you have run 'dotnet build' with the following properties added to your .csproj files:
    <PropertyGroup>
        <EmitCompilerGeneratedFiles>true</EmitCompilerGeneratedFiles>
        <ErrorLog>code-analysis.sarif</ErrorLog>
    </PropertyGroup>"
    exit 1
}

# Combine all SARIF files into one
$combinedSarifFile = Join-Path $env:GITHUB_WORKSPACE "combined-code-analysis.sarif"
$combinedSarifContent = @()
foreach ($sarifFile in $sarifFiles) {
    $content = Get-Content $sarifFile.FullName -Raw | ConvertFrom-Json
    $combinedSarifContent += $content
}

$combinedSarifJson = $combinedSarifContent | ConvertTo-Json -Depth 100
Set-Content -Path $combinedSarifFile -Value $combinedSarifJson

# Generate a markdown report from the SARIF findings
$findings = @()
foreach ($sarifFile in $sarifFiles) {
    $content = Get-Content $sarifFile.FullName -Raw | ConvertFrom-Json
    foreach ($result in $content.runs.results) {
        $ruleId = $result.ruleId
        $message = $result.message.text
        $fileUri = $result.locations.physicalLocation.artifactLocation.uri
        $startLine = $result.locations.physicalLocation.region.startLine
        $findings += "| $ruleId | $message | $fileUri | Line: $startLine |"
    }
}

$report = @"
## Code Analysis Report
| Rule | Message | File | Location |
|------|---------|------|----------|
$(($findings -join "`n"))
"@

# Post the report as a comment on the pull request
$body = @{
    body = $report
}
$body | ConvertTo-Json -Compress | Out-File -FilePath $env:GITHUB_WORKSPACE\request-body.json -Encoding utf8

# $uri = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/issues/$env:GITHUB_PULL_REQUEST/comments"
# $headers = @{
#     Authorization = "Bearer $env:GITHUB_TOKEN"
#     Accept        = "application/vnd.github.v3+json"
# }
# $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ($body | ConvertTo-Json)
