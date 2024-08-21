# Verify that the script is running as part of a pull request
if ($env:GITHUB_EVENT_NAME -ne 'pull_request') {
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
    $combinedSarifContent += $content.runs.results
}

# Create a valid SARIF structure
$combinedSarifJson = @{
    version = "2.1.0"
    runs = @(
        @{
            tool = @{
                driver = @{
                    name = "Combined SARIF Analysis"
                }
            }
            results = $combinedSarifContent
        }
    )
} | ConvertTo-Json -Depth 100

Set-Content -Path $combinedSarifFile -Value $combinedSarifJson

# Generate a markdown report from the SARIF findings
$repoUrl = "https://github.com/${env:GITHUB_REPOSITORY}"
$findings = @()
foreach ($sarifFile in $sarifFiles) {
    $content = Get-Content $sarifFile.FullName -Raw | ConvertFrom-Json
    foreach ($result in $content.runs.results) {
        $ruleId = $result.ruleId
        $message = $result.message.text
        $fileUri = $result.locations.physicalLocation.artifactLocation.uri
        $startLine = $result.locations.physicalLocation.region.startLine

        # Format file URI to a GitHub URL
        # Handle potential issues with file paths
        $fileUri = $fileUri -replace [regex]::Escape($env:GITHUB_WORKSPACE + "\") , "" 
        $fileUrl = "$repoUrl/blob/${env:GITHUB_REF}/$fileUri"
        $link = "$fileUrl#L$startLine"

        $findings += "| $ruleId | $message | [File]($link) | Line: $startLine |"
    }
}

$report = @"
## Code Analysis Report
| Rule | Message | File | Location |
|------|---------|------|----------|
$(($findings -join "`n"))
"@

$report | Out-File -FilePath $env:GITHUB_WORKSPACE\request-body.md -Encoding utf8
