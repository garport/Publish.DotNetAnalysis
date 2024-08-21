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
    Write-Error "No SARIF files found in $baseDir. Please ensure you have run 'dotnet build' with the following properties added to your .csproj files:
    <PropertyGroup>
        <EmitCompilerGeneratedFiles>true</EmitCompilerGeneratedFiles>
        <ErrorLog>code-analysis.sarif</ErrorLog>
    </PropertyGroup>"
    exit 1
}

# Initialize an empty array for runs
$combinedRuns = @()

foreach ($sarifFile in $sarifFiles) {
    $content = Get-Content $sarifFile.FullName -Raw | ConvertFrom-Json
    $combinedRuns += $content.runs
}

# Create the combined SARIF structure
$combinedSarifContent = @{
    version = "2.1.0"
    runs    = $combinedRuns
}

# Convert to JSON
$combinedSarifJson = $combinedSarifContent | ConvertTo-Json -Depth 100

# Save the combined SARIF file
$combinedSarifFile = Join-Path $env:GITHUB_WORKSPACE "combined-code-analysis.sarif"
Set-Content -Path $combinedSarifFile -Value $combinedSarifJson

# Generate a markdown report from the SARIF findings
$findings = @()
foreach ($result in $combinedRuns) {
    foreach ($run in $result.results) {
        $ruleId = $run.ruleId
        $message = $run.message.text
        $fileUri = $run.locations.physicalLocation.artifactLocation.uri
        $startLine = $run.locations.physicalLocation.region.startLine
        $findings += "| $ruleId | $message | $fileUri | Line: $startLine |"
    }
}

$report = @"
## Code Analysis Report
| Rule | Message | File | Location |
|------|---------|------|----------|
$(($findings -join "`n"))
"@

$report | Out-File -FilePath $env:GITHUB_WORKSPACE\request-body.md -Encoding utf8
