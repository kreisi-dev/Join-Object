#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../JoinObject.psd1'
    Import-Module $modulePath -Force

    # A target cmdlet used for enrichment. 'Name' is a recognized identity parameter.
    function global:Get-TestEnrichment {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] $Name
        )
        [pscustomobject]@{ Status = 'New'; Extra = "extra-$Name" }
    }

    # A target cmdlet without any recognized identity parameter. The parameter only
    # needs to exist for Join-Object's discovery; its value is irrelevant.
    function global:Get-TestNoIdentity {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Color', Justification = 'Test double: the parameter must exist for identity discovery, its value is not used.')]
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] $Color
        )
        [pscustomobject]@{ Shade = 'dark' }
    }

    # A target cmdlet that always fails, to exercise the passthrough-on-error path.
    function global:Get-TestFailing {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Name', Justification = 'Test double: the parameter must exist for identity discovery, its value is not used.')]
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] $Name
        )
        throw 'boom'
    }

    # Echoes the ErrorAction it was called with, to verify -Options is not overridden.
    function global:Get-TestEchoEA {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] $Name
        )
        [pscustomobject]@{ EffectiveEA = [string]$PSBoundParameters['ErrorAction'] }
    }

    # Returns two objects, to exercise the multiple-match warning.
    function global:Get-TestMultiMatch {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Name', Justification = 'Test double: the parameter must exist for identity discovery, its value is not used.')]
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)] $Name
        )
        [pscustomobject]@{ Rank = 'first' }
        [pscustomobject]@{ Rank = 'second' }
    }

    # Mimics Get-Process: -Id wins the automatic discovery, but only -Name accepts a string.
    function global:Get-TestAmbiguous {
        [CmdletBinding()]
        param(
            [int] $Id,
            [string] $Name
        )
        if ($PSBoundParameters.ContainsKey('Name')) {
            [pscustomobject]@{ Matched = "name-$Name" }
        } elseif ($PSBoundParameters.ContainsKey('Id')) {
            [pscustomobject]@{ Matched = "id-$Id" }
        }
    }
}

AfterAll {
    Remove-Item Function:\Get-TestEnrichment -ErrorAction SilentlyContinue
    Remove-Item Function:\Get-TestNoIdentity -ErrorAction SilentlyContinue
    Remove-Item Function:\Get-TestFailing -ErrorAction SilentlyContinue
    Remove-Item Function:\Get-TestEchoEA -ErrorAction SilentlyContinue
    Remove-Item Function:\Get-TestMultiMatch -ErrorAction SilentlyContinue
    Remove-Item Function:\Get-TestAmbiguous -ErrorAction SilentlyContinue
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

    It 'suffixes colliding properties with _2 by default' {
        $source = [pscustomobject]@{ Name = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object Get-TestEnrichment

        $result.Status        | Should -Be 'Old'
        $result.Status_2 | Should -Be 'New'
    }

    It 'overwrites colliding properties when -Force is used' {
        $source = [pscustomobject]@{ Name = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object Get-TestEnrichment -Force

        $result.Status | Should -Be 'New'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Status_2'
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

        $result.Status   | Should -BeNullOrEmpty
        $result.Status_2 | Should -Be 'New'
    }

    It 'picks the identity property by preferred-list priority, not by property order' {
        # 'Alias' ranks higher than 'Name' in the preferred list, even though 'Name' comes first.
        $source = [pscustomobject]@{ Name = 'n1'; Alias = 'a1' }
        $result = $source | Join-Object Get-TestEnrichment

        $result.Extra | Should -Be 'extra-a1'
    }

    It 'merges the first object and warns when the target returns multiple matches' {
        $source = [pscustomobject]@{ Name = 'svc1' }
        $output = $source | Join-Object Get-TestMultiMatch 3>&1
        $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $result = @($output | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })

        $warnings.Count | Should -Be 1
        $warnings[0].Message | Should -Match '2 objects'
        $result[0].Rank | Should -Be 'first'
    }

    It 'throws a terminating error when Cmdlet is neither a string nor a script block' {
        { [pscustomobject]@{ Name = 'svc1' } | Join-Object 42 } |
            Should -Throw -ErrorId 'InvalidCmdletArgument,Join-Object'
    }

    It 'calls the target cmdlet with ErrorAction Stop by default' {
        $source = [pscustomobject]@{ Name = 'svc1' }
        $result = $source | Join-Object Get-TestEchoEA

        $result.EffectiveEA | Should -Be 'Stop'
    }

    It 'lets an ErrorAction from -Options win over the built-in default' {
        $source = [pscustomobject]@{ Name = 'svc1' }
        $result = $source | Join-Object Get-TestEchoEA -Options @{ ErrorAction = 'SilentlyContinue' }

        $result.EffectiveEA | Should -Be 'SilentlyContinue'
    }

    It 'passes additional -Options parameters through to the target cmdlet' {
        $source = [pscustomobject]@{ Login = 'svc1' }
        $result = $source | Join-Object Get-TestEnrichment -IdentityProperty Login -Options @{ Verbose = $false }

        $result.Extra | Should -Be 'extra-svc1'
    }

    It 'routes the identity to an explicitly named target parameter' {
        $source = [pscustomobject]@{ Name = 'svc1' }
        $result = $source | Join-Object Get-TestAmbiguous -TargetParameter Name

        $result.Matched | Should -Be 'name-svc1'
    }

    It 'falls back to passthrough when automatic discovery picks an incompatible parameter' {
        # Discovery prefers -Id over -Name; binding the string to [int] fails -> passthrough.
        $source = [pscustomobject]@{ Name = 'svc1' }
        $result = $source | Join-Object Get-TestAmbiguous

        $result.PSObject.Properties.Name | Should -Not -Contain 'Matched'
        $result.Name | Should -Be 'svc1'
    }

    It 'throws a terminating error when the explicit target parameter does not exist' {
        $source = [pscustomobject]@{ Name = 'svc1' }
        { $source | Join-Object Get-TestEnrichment -TargetParameter DoesNotExist } |
            Should -Throw -ErrorId 'TargetParameterNotFound,Join-Object'
    }

    It 'passes the input through unchanged when the target cmdlet fails' {
        $source = [pscustomobject]@{ Name = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object Get-TestFailing

        $result.Status | Should -Be 'Old'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Extra'
    }

    It 'reports a failing target cmdlet on the verbose stream' {
        $source = [pscustomobject]@{ Name = 'svc1' }
        $output = $source | Join-Object Get-TestFailing -Verbose 4>&1
        $verbose = @($output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })

        $verbose.Count | Should -BeGreaterThan 0
        $verbose[-1].Message | Should -Match 'boom'
        $verbose[-1].Message | Should -Match 'Get-TestFailing'
    }

    It 'increments the suffix on repeated collisions instead of overwriting _2' {
        # Simulates chaining several Join-Object calls that all yield a 'Status' property.
        $source = [pscustomobject]@{ Name = 'svc1'; Status = 'Old'; Status_2 = 'FromSecondJoin' }
        $result = $source | Join-Object Get-TestEnrichment

        $result.Status   | Should -Be 'Old'
        $result.Status_2 | Should -Be 'FromSecondJoin'
        $result.Status_3 | Should -Be 'New'
    }
}

Describe 'Join-Object with a script block' {
    It 'exposes the whole input object as $_ and merges the result' {
        $source = [pscustomobject]@{ Login = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object { Get-TestEnrichment -Name $_.Login }

        $result.Login         | Should -Be 'svc1'
        $result.Extra         | Should -Be 'extra-svc1'
        $result.Status        | Should -Be 'Old'
        $result.Status_2 | Should -Be 'New'
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
        $result.PSObject.Properties.Name | Should -Not -Contain 'Status_2'
    }

    It 'passes the input through unchanged when the script block yields nothing' {
        $source = [pscustomobject]@{ Login = 'svc1'; Status = 'Old' }
        $result = $source | Join-Object { }

        $result.Login | Should -Be 'svc1'
        $result.PSObject.Properties.Name | Should -Not -Contain 'Extra'
    }

    It 'reports a failing script block on the verbose stream and passes the input through' {
        $source = [pscustomobject]@{ Login = 'svc1' }
        $output = $source | Join-Object { throw 'boom' } -Verbose 4>&1
        $verbose = @($output | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })
        $result = @($output | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] })

        $verbose.Count | Should -BeGreaterThan 0
        $verbose[-1].Message | Should -Match 'boom'
        $result[0].Login | Should -Be 'svc1'
    }
}
