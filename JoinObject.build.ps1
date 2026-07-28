# Build script for Invoke-Build (https://github.com/nightroman/Invoke-Build).
# Bootstrap once: Install-Module InvokeBuild, PSDepend -Scope CurrentUser
# Then:           Invoke-Build   (runs Deps + Lint + Test)

# 'task' is the standard Invoke-Build DSL keyword (alias of Add-BuildTask).
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
param()

task Deps {
    Invoke-PSDepend -Path "$BuildRoot/requirements.psd1" -Force
}

task Lint {
    $findings = Invoke-ScriptAnalyzer -Path $BuildRoot -Recurse -Severity Error, Warning
    if ($findings) {
        $findings | Format-Table -AutoSize | Out-String
        throw "PSScriptAnalyzer found $(@($findings).Count) finding(s)."
    }
    'PSScriptAnalyzer: clean.'
}

# Coverage ratchet: fail when coverage drops below the target, which sits just
# under the measured baseline (95.0 % on 2026-07-28). Raise it when coverage improves.
task Test {
    $config = New-PesterConfiguration
    $config.Run.Path = "$BuildRoot/tests"
    $config.Run.Throw = $true
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = "$BuildRoot/JoinObject"
    $config.CodeCoverage.OutputPath = "$BuildRoot/coverage.xml"
    $result = Invoke-Pester -Configuration $config
    $target = 90
    $coverage = [math]::Round($result.CodeCoverage.CoveragePercent, 1)
    if ($coverage -lt $target) {
        throw "Code coverage $coverage % is below the target of $target %."
    }
    "Code coverage: $coverage % (target: $target %)."
}

task . Deps, Lint, Test
