#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'MergeWith.psd1'
    Import-Module $modulePath -Force

    # A target cmdlet used for enrichment. 'Name' is a recognized identity parameter.
    function global:Get-TestEnrichment {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] $Name
        )
        [pscustomobject]@{ Status = 'New'; Extra = "extra-$Name" }
    }
}

AfterAll {
    Remove-Item Function:\Get-TestEnrichment -ErrorAction SilentlyContinue
    Remove-Module MergeWith -ErrorAction SilentlyContinue
}

Describe 'Module exports' {
    It 'exports the Join-Object function' {
        Get-Command Join-Object -Module MergeWith | Should -Not -BeNullOrEmpty
    }

    It 'exposes the Join alias resolving to Join-Object' {
        (Get-Alias Join).ResolvedCommandName | Should -Be 'Join-Object'
    }
}

Describe 'Join-Object' {
    It 'adds properties from the second cmdlet to the input object' {
        $source = [pscustomobject]@{ Name = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object Get-TestEnrichment

        $result.Name  | Should -Be 'svc1'
        $result.Extra | Should -Be 'extra-svc1'
    }

    It 'suffixes colliding properties with _Second by default' {
        $source = [pscustomobject]@{ Name = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object Get-TestEnrichment

        $result.Status        | Should -Be 'Old'
        $result.Status_Second | Should -Be 'New'
    }

    It 'overwrites colliding properties when -Force is used' {
        $source = [pscustomobject]@{ Name = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object Get-TestEnrichment -Force

        $result.Status | Should -Be 'New'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Status_Second'
    }

    It 'honors an explicit IdentityProperty' {
        $source = [pscustomobject]@{ Login = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object Get-TestEnrichment -IdentityProperty Login

        $result.Extra | Should -Be 'extra-svc1'
    }

    It 'passes the input through unchanged when no identity can be found' {
        $source = [pscustomobject]@{ Color = 'blue' }
        $result = $source | Join-Object Get-TestEnrichment -WarningAction SilentlyContinue

        $result.Color | Should -Be 'blue'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Extra'
    }

    It 'works through the Join alias' {
        $source = [pscustomobject]@{ Name = 'svc1' }
        $result = $source | Join Get-TestEnrichment

        $result.Extra | Should -Be 'extra-svc1'
    }
}
