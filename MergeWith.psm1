# MergeWith.psm1
# Loads all public functions from src/Public and exports them.

$Public = @(Get-ChildItem -Path "$PSScriptRoot/src/Public/*.ps1" -ErrorAction SilentlyContinue)

foreach ($file in $Public) {
    try {
        . $file.FullName
    } catch {
        Write-Error "Failed to load function $($file.FullName): $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function $Public.BaseName -Alias '*'
