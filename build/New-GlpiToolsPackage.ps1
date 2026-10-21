<#
.SYNOPSIS
Builds the distribution packages (.nupkg, .zip and SHA256SUMS) of the GlpiTools module.

.DESCRIPTION
Exports the module files from a git ref (tag, branch or commit) into a staging folder,
validates the manifest, and generates:
  - GlpiTools.<version>.nupkg  (PSResourceGet package, built through a temporary local repository)
  - GlpiTools-<version>.zip    (GlpiTools/<version>/... layout, ready to extract into $env:PSModulePath)
  - SHA256SUMS-<version>       (checksums of both files)
The repository working tree is never modified.

.PARAMETER Ref
Git ref to package. Default: HEAD.

.PARAMETER OutputPath
Folder where the packages are written. Default: ./build/out (created when missing).

.EXAMPLE
./build/New-GlpiToolsPackage.ps1 -Ref v2.0.0

.EXAMPLE
./build/New-GlpiToolsPackage.ps1 -Ref v1.8.0 -OutputPath ~/releases

.NOTES
Requires git and PowerShell 7 with Microsoft.PowerShell.PSResourceGet.
Publish the result with: gh release create <tag> <files> --title "GlpiTools <version>" --notes-file <notes>
#>
[CmdletBinding()]
param(
    [string]$Ref = 'HEAD',
    [string]$OutputPath = (Join-Path $PSScriptRoot 'out')
)

$ErrorActionPreference = 'Stop'

# Items that belong to the module; anything else in the repository is left out of the package
$moduleItems = 'GlpiTools.psd1', 'GlpiTools.psm1', 'Public', 'Private', 'README.md', 'LICENSE', 'CHANGELOG.md', 'examples'

$repoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel).Trim()
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("GlpiToolsBuild-" + [guid]::NewGuid().ToString('N'))
$repoName = 'GlpiToolsBuild-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$repoRegistered = $false

try {
    $src = Join-Path $work 'src'
    $stage = Join-Path $work 'stage/GlpiTools'
    $feed = Join-Path $work 'feed'
    New-Item -ItemType Directory -Path $src, $stage, $feed -Force | Out-Null

    # Export the ref as zip and extract it, so the build is independent of the working tree
    $archive = Join-Path $work 'src.zip'
    git -C $repoRoot archive --format=zip -o $archive $Ref
    if ($LASTEXITCODE -ne 0) { throw "git archive failed for ref '$Ref'." }
    Expand-Archive -Path $archive -DestinationPath $src

    # Copy only the module items that exist in this ref
    foreach ($item in $moduleItems) {
        $path = Join-Path $src $item
        if (Test-Path $path) { Copy-Item $path -Destination $stage -Recurse }
    }

    # Validate the manifest and read the version from it
    $manifest = Test-ModuleManifest -Path (Join-Path $stage 'GlpiTools.psd1') -WarningAction SilentlyContinue
    $version = $manifest.Version.ToString()
    Write-Verbose "Packaging GlpiTools $version from '$Ref'"

    # Make sure the staged module imports and exports commands
    Import-Module (Join-Path $stage 'GlpiTools.psd1') -Force
    $count = (Get-Command -Module GlpiTools).Count
    Remove-Module GlpiTools -Force
    if ($count -eq 0) { throw 'The staged module exports no commands.' }

    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $OutputPath = (Resolve-Path $OutputPath).Path

    # Build the nupkg through a temporary local repository
    Register-PSResourceRepository -Name $repoName -Uri $feed -Trusted
    $repoRegistered = $true
    Publish-PSResource -Path $stage -Repository $repoName -SkipDependenciesCheck -SkipModuleManifestValidate
    $nupkg = Join-Path $OutputPath "GlpiTools.$version.nupkg"
    Copy-Item (Join-Path $feed "GlpiTools.$version.nupkg") $nupkg -Force

    # Build the zip with the GlpiTools/<version>/ layout
    $zipRoot = Join-Path $work 'zip'
    $zipModule = Join-Path $zipRoot "GlpiTools/$version"
    New-Item -ItemType Directory -Path $zipModule -Force | Out-Null
    Copy-Item (Join-Path $stage '*') -Destination $zipModule -Recurse
    $zip = Join-Path $OutputPath "GlpiTools-$version.zip"
    Remove-Item $zip -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $zipRoot 'GlpiTools') -DestinationPath $zip

    # Write the checksums with relative file names
    $sums = Join-Path $OutputPath "SHA256SUMS-$version"
    $lines = foreach ($file in $nupkg, $zip) {
        '{0}  {1}' -f (Get-FileHash $file -Algorithm SHA256).Hash.ToLower(), (Split-Path $file -Leaf)
    }
    Set-Content -Path $sums -Value $lines

    Write-Host "GlpiTools $version ($count commands) packaged in $OutputPath"
    Get-Item $nupkg, $zip, $sums
}
finally {
    # Remove the temporary repository and the working folder even on failure
    if ($repoRegistered) { Unregister-PSResourceRepository -Name $repoName -ErrorAction SilentlyContinue }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
