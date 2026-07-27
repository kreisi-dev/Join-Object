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

task Test {
    $config = New-PesterConfiguration
    $config.Run.Path = "$BuildRoot/tests"
    $config.Run.Throw = $true
    $config.Output.Verbosity = 'Detailed'
    Invoke-Pester -Configuration $config
}

task . Deps, Lint, Test
