# Development dependencies. Install with PSDepend:
#   Invoke-PSDepend -Path ./requirements.psd1 -Force
@{
    PSDependOptions = @{
        Target = 'CurrentUser'
    }

    Pester           = @{
        Version    = 'latest'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }

    PSScriptAnalyzer = 'latest'

    InvokeBuild      = 'latest'
}
