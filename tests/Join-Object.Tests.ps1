#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'JoinObject.psd1'
    Import-Module $modulePath -Force

    # A target cmdlet used for enrichment. 'Name' is a recognized identity parameter.
    function global:Get-TestEnrichment {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] $Name
        )
        [pscustomobject]@{ Status = 'New'; Extra = "extra-$Name" }
    }

    # A target cmdlet without any recognized identity parameter.
    function global:Get-TestNoIdentity {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] $Color
        )
        [pscustomobject]@{ Shade = 'dark' }
    }
}

AfterAll {
    Remove-Item Function:\Get-TestEnrichment -ErrorAction SilentlyContinue
    Remove-Item Function:\Get-TestNoIdentity -ErrorAction SilentlyContinue
    Remove-Module JoinObject -ErrorAction SilentlyContinue
}

Describe 'Module exports' {
    It 'exports the Join-Object function' {
        Get-Command Join-Object -Module JoinObject | Should -Not -BeNullOrEmpty
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

    It 'throws a terminating error when no identity parameter can be resolved' {
        $source = [pscustomobject]@{ Name = 'svc1' }
        { $source | Join-Object Get-TestNoIdentity } |
            Should -Throw -ErrorId 'IdentityParameterNotFound,Join-Object'
    }

    It 'treats a $null-valued source property as a collision' {
        $source = [pscustomobject]@{ Name = 'svc1'; Status = $null }
        $result = $source | Join-Object Get-TestEnrichment

        $result.Status        | Should -BeNullOrEmpty
        $result.Status_Second | Should -Be 'New'
    }
}

Describe 'Join-Object with a script block' {
    It 'exposes the whole input object as $_ and merges the result' {
        $source = [pscustomobject]@{ Login = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object { Get-TestEnrichment -Name $_.Login }

        $result.Login         | Should -Be 'svc1'
        $result.Extra         | Should -Be 'extra-svc1'
        $result.Status        | Should -Be 'Old'
        $result.Status_Second | Should -Be 'New'
    }

    It 'does not require a recognized identity parameter' {
        # Get-TestNoIdentity throws in the cmdlet-name form; a script block bypasses identity discovery.
        $source = [pscustomobject]@{ Color = 'blue' }
        $result = $source | Join-Object { Get-TestNoIdentity -Color $_.Color }

        $result.Color | Should -Be 'blue'
        $result.Shade | Should -Be 'dark'
    }

    It 'honors -Force for colliding properties' {
        $source = [pscustomobject]@{ Login = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object { Get-TestEnrichment -Name $_.Login } -Force

        $result.Status | Should -Be 'New'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Status_Second'
    }

    It 'passes the input through unchanged when the script block yields nothing' {
        $source = [pscustomobject]@{ Login = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object { }

        $result.Login | Should -Be 'svc1'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Extra'
    }
}
