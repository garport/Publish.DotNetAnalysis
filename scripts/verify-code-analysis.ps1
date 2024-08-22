# Ensure the script is running as part of a pull request
if (-not $env:GITHUB_EVENT_NAME -eq 'pull_request') {
    Write-Error "This GitHub Action can only be run as part of a pull request."
    exit 1
}

# Get the base directory from environment variable, default to current directory
$baseDir = $env:SARIF_BASE_DIR
if (-not $baseDir) {
    $baseDir = $env:GITHUB_WORKSPACE
}

# Define the SARIF file pattern
$sarifFiles = Get-ChildItem -Path $baseDir -Recurse -Filter *.sarif

if ($sarifFiles.Count -eq 0) {
    Write-Error "No SARIF files found in $baseDir. Please ensure you have run 'dotnet build' with the appropriate properties added to your .csproj files."
    exit 1
}

# Combine all SARIF files into one, ignoring suppressed warnings
$combinedSarifFile = Join-Path $env:GITHUB_WORKSPACE "combined-code-analysis.sarif"
$combinedSarifContent = @()
foreach ($sarifFile in $sarifFiles) {
    $content = Get-Content $sarifFile.FullName -Raw | ConvertFrom-Json
    foreach ($result in $content.runs[0].results) {
        # Ignore results with suppressions
        if (-not $result.suppressions) {
            $combinedSarifContent += $result
        }
    }
}

$combinedSarifJson = [pscustomobject]@{
    version = "1.0.0"
    runs = @([pscustomobject]@{
        tool = [pscustomobject]@{
            name = "CombinedTool"
            version = "1.0.0"
        }
        results = $combinedSarifContent
    })
} | ConvertTo-Json -Depth 100
Set-Content -Path $combinedSarifFile -Value $combinedSarifJson

# Generate a markdown report from the SARIF findings
$findings = @()
foreach ($sarifFile in $sarifFiles) {
    $content = Get-Content $sarifFile.FullName -Raw | ConvertFrom-Json
    foreach ($result in $content.runs[0].results) {
        # Ignore results with suppressions
        if (-not $result.suppressionStates) {
         $ruleId = $result.ruleId
         $message = $result.message
         $fileUri = $result.locations[0].resultfile.uri
         $startLine = $result.locations[0].resultfile.region.startLine
         $findings += "| $ruleId | $message | $fileUri | Line: $startLine |"
        }
    }
}

$report = @"
## Code Analysis Report
| Rule | Message | File | Location |
|------|---------|------|----------|
$(($findings -join "`n"))
"@

$report | Out-File -FilePath $env:GITHUB_WORKSPACE\request-body.md -Encoding utf8
