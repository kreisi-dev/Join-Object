@{
    # Script module associated with this manifest.
    RootModule        = 'JoinObject.psm1'

    # Version of this module.
    ModuleVersion     = '0.2.0'

    # Unique ID for this module.
    GUID              = 'b2d6e3a4-5c1f-4e88-9a7d-1f0c2e6b9a31'

    # Author of this module.
    Author            = 'Rene Kreisbeck'

    # Copyright statement.
    Copyright         = '(c) Rene Kreisbeck. All rights reserved.'

    # Description of the functionality provided by this module.
    Description       = 'Provides Join-Object - a pipeline join for PowerShell that dynamically enriches objects with the results of another cmdlet. Also available via the alias "Join".'

    # Minimum version of the PowerShell engine required.
    PowerShellVersion = '5.1'

    # Functions exported from this module.
    FunctionsToExport = @('Join-Object')

    # Cmdlets exported from this module.
    CmdletsToExport   = @()

    # Variables exported from this module.
    VariablesToExport = @()

    # Aliases exported from this module.
    AliasesToExport   = @('Join')

    # Private data, e.g. for the PowerShell Gallery.
    PrivateData = @{
        PSData = @{
            Tags         = @('Join', 'Pipeline', 'Objects', 'Utility')
            LicenseUri   = ''
            ProjectUri   = ''
            Prerelease   = 'beta2'
            ReleaseNotes = 'Beta: adds script-block support for the Cmdlet parameter, giving full control over the enrichment call via $_. beta2: repeated property collisions now get an incrementing suffix (_2, _3, ...) instead of overwriting a fixed _Second name.'
        }
    }
}
