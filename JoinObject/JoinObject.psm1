# Dot-source every function file under Public/ and Private/, then export only the
# public functions. New public functions must also be listed in FunctionsToExport
# in the module manifest (JoinObject.psd1) to be visible to consumers.

$Public  = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1"  -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)

foreach ($file in @($Public + $Private)) {
    try {
        . $file.FullName
    } catch {
        throw "Failed to import function $($file.FullName): $_"
    }
}

if ($Public.Count -gt 0) {
    Export-ModuleMember -Function $Public.BaseName -Alias '*'
}

# Version metadata (ModuleVersion, Prerelease, ...) only reaches Get-Command when the
# module is imported via its manifest. A direct 'Import-Module .../JoinObject.psm1' bypasses
# the manifest, so Get-Command reports Version 0.0 - warn so it's not mistaken for a bug.
# Module.Version itself isn't populated yet while this script runs (even via the manifest),
# so detect the manifest-less case via PrivateData instead, which IS already populated by then.
if (-not $ExecutionContext.SessionState.Module.PrivateData) {
    Write-Warning "JoinObject was imported directly from JoinObject.psm1, so its version is not available. Import 'JoinObject.psd1' instead, e.g.: Import-Module '$PSScriptRoot/JoinObject.psd1'"
}
