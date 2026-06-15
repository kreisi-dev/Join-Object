@{
    # Skript-Modul, das mit diesem Manifest verknüpft ist.
    RootModule        = 'MergeWith.psm1'

    # Version des Moduls.
    ModuleVersion     = '0.1.0'

    # Eindeutige ID für dieses Modul.
    GUID              = 'b2d6e3a4-5c1f-4e88-9a7d-1f0c2e6b9a31'

    # Autor des Moduls.
    Author            = 'Rene Kreisbeck'

    # Copyright-Hinweis.
    Copyright         = '(c) Rene Kreisbeck. Alle Rechte vorbehalten.'

    # Beschreibung der Funktionalität dieses Moduls.
    Description       = 'Stellt Join-Object bereit – ein "Left Join" für die PowerShell-Pipeline, der Objekte dynamisch mit den Ergebnissen eines weiteren Cmdlets anreichert. Verfügbar auch über den Alias "Join".'

    # Mindestversion der PowerShell-Engine.
    PowerShellVersion = '5.1'

    # Vom Modul exportierte Funktionen.
    FunctionsToExport = @('Join-Object')

    # Vom Modul exportierte Cmdlets.
    CmdletsToExport   = @()

    # Vom Modul exportierte Variablen.
    VariablesToExport = @()

    # Vom Modul exportierte Aliase.
    AliasesToExport   = @('Join')

    # Private Daten, u.a. für die PowerShell Gallery.
    PrivateData = @{
        PSData = @{
            Tags         = @('Merge', 'Join', 'Pipeline', 'Objects', 'Utility')
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = 'Erste Veröffentlichung von Join-Object (Alias: Join).'
        }
    }
}
