# MergeWith.psm1
# Lädt alle öffentlichen Funktionen aus src/Public und exportiert sie.

$Public = @(Get-ChildItem -Path "$PSScriptRoot/src/Public/*.ps1" -ErrorAction SilentlyContinue)

foreach ($file in $Public) {
    try {
        . $file.FullName
    } catch {
        Write-Error "Fehler beim Laden der Funktion $($file.FullName): $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function $Public.BaseName
