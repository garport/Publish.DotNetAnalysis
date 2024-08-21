# Publish.DotNetAnalysis
## Setup
Ensure `dotnet build` has been run before calling this action using these two properties:
```xml
<PropertyGroup>
  <EmitCompilerGeneratedFiles>true</EmitCompilerGeneratedFiles>
  <ErrorLog>code-analysis.sarif</ErrorLog>
</PropertyGroup>
```

The calling job will also need these permissions:
```yml
permissions:
  contents: read
  pull-requests: write
```