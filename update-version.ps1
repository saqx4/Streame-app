# Update Streame app version across all platforms
# Usage: .\update-version.ps1 -Version "2.1.0"

param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

# Validate version format (X.Y.Z)
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "Invalid version format. Use X.Y.Z (e.g., 2.1.0)"
    exit 1
}

# Get current build number from mobile pubspec
$mobilePubspec = "packages\mobile\pubspec.yaml"
if (Test-Path $mobilePubspec) {
    $content = Get-Content $mobilePubspec
    $versionLine = $content | Select-String "^version:"
    if ($versionLine) {
        if ($versionLine.Line -match '^\d+\.\d+\.\d+\+(\d+)$') {
            $currentBuild = [int]$Matches[1]
            $newBuild = $currentBuild + 1
        } else {
            $newBuild = 22 # default if pattern doesn't match
        }
    } else {
        $newBuild = 22
    }
} else {
    Write-Error "Mobile pubspec not found"
    exit 1
}

$fullVersion = "$Version+$newBuild"
Write-Host "Updating to version: $fullVersion" -ForegroundColor Green

# Update mobile
$mobilePath = "packages\mobile\pubspec.yaml"
if (Test-Path $mobilePath) {
    (Get-Content $mobilePath) -replace '^version: .*', "version: $fullVersion" | Set-Content $mobilePath
    Write-Host "Updated mobile: $fullVersion" -ForegroundColor Cyan
}

# Update desktop
$desktopPath = "packages\desktop\pubspec.yaml"
if (Test-Path $desktopPath) {
    (Get-Content $desktopPath) -replace '^version: .*', "version: $fullVersion" | Set-Content $desktopPath
    Write-Host "Updated desktop: $fullVersion" -ForegroundColor Cyan
}

# Update TV
$tvPath = "packages\tv\pubspec.yaml"
if (Test-Path $tvPath) {
    (Get-Content $tvPath) -replace '^version: .*', "version: $fullVersion" | Set-Content $tvPath
    Write-Host "Updated TV: $fullVersion" -ForegroundColor Cyan
}

Write-Host "Version update complete!" -ForegroundColor Green
