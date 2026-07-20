function Join-Object {
    <#
    .SYNOPSIS
        Dynamically merges objects from the pipeline with data from another cmdlet.

    .DESCRIPTION
        Joins objects from the pipeline with data from another cmdlet. It takes an input
        object, identifies a common identity property (like UPN or GUID), calls a second
        cmdlet with that identity, and merges the properties of both results into a single
        object.

        Also available via the alias 'Join'.

    .PARAMETER Cmdlet
        The cmdlet to call for the enrichment. Accepts either:
          - The name of a cmdlet (e.g., 'Get-ADUser', 'Get-MailboxStatistics'). The identity
            parameter is discovered automatically and the source identity value is splatted in.
          - A script block (e.g., { Get-Mailbox -Identity $_.PrimarySmtpAddress }). The full input
            object is exposed as $_ (and $PSItem), giving you complete control over the call. No
            identity discovery or auto-splatting happens in this mode.

    .PARAMETER InputObject
        The object coming from the pipeline.

    .PARAMETER IdentityProperty
        Optional: Explicitly define which property of the InputObject should be used as the identity.

    .PARAMETER TargetParameter
        Optional: Explicitly name the parameter of the target cmdlet that receives the identity
        value, instead of relying on automatic discovery. Use this when the discovery picks the
        wrong parameter (e.g. Get-Process resolves to -Id, but you want -Name). Not applicable
        in script-block mode.

    .PARAMETER Options
        A hashtable of additional parameters to pass to the target cmdlet (e.g., @{Properties = '*'}).
        Aliases: Args, With, Splat, Parameters

    .PARAMETER Force
        If set, properties from the second cmdlet will overwrite existing properties of the InputObject.

    .EXAMPLE
        Get-Mailbox | Join-Object Get-MailboxStatistics
        Simple merge: Adds mailbox statistics to your mailbox objects.

    .EXAMPLE
        Get-Service | Join Get-Process -IdentityProperty Name -TargetParameter Name
        Joins services with their corresponding processes by name (using the 'Join' alias).
        -TargetParameter is needed here because automatic discovery would pick Get-Process -Id.

    .EXAMPLE
        Get-ADUser -Filter "Name -like 'John*'" | Join-Object Get-Mailbox -Options @{ErrorAction = 'SilentlyContinue'}
        Joins AD users with their Exchange mailboxes, suppressing errors if a user has no mailbox.

    .EXAMPLE
        $Data | Join-Object Get-ADUser -With @{Properties = "Department", "Office"} -Force
        Merges AD attributes and overwrites any existing 'Department' or 'Office' fields in the source data.

    .EXAMPLE
        Get-RemoteMailbox | Join-Object { Get-Mailbox -Identity $_.PrimarySmtpAddress -ErrorAction SilentlyContinue }
        Script-block form: the input object is exposed as $_, so you control exactly how the target is called.
    #>
    [CmdletBinding()]
    [Alias('Join')]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateNotNull()]
        # Either a cmdlet name ([string]) or a [scriptblock] for full control over the target call.
        [object] $Cmdlet,

        [Parameter(ValueFromPipeline)]
        $InputObject,

        [string] $IdentityProperty,

        [string] $TargetParameter,

        [Alias("Args", "With", "Splat", "Parameters")]
        [hashtable] $Options,

        [switch] $Force
    )

    begin {
        # A script block gives the caller full control over the target call: no cmdlet to resolve,
        # no identity parameter to discover. The input object is exposed as $_ in process{}.
        $isScriptBlock = $Cmdlet -is [scriptblock]

        if (-not $isScriptBlock -and $Cmdlet -isnot [string]) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new("The Cmdlet parameter must be a cmdlet name ([string]) or a [scriptblock], but got [$($Cmdlet.GetType().Name)]."),
                'InvalidCmdletArgument',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $Cmdlet
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        if (-not $isScriptBlock) {
            # Resolve the target cmdlet. A missing cmdlet surfaces as a clean terminating error.
            $cmdInfo = Get-Command $Cmdlet -ErrorAction Stop
            $targetParams = @($cmdInfo.Parameters.Keys)

            if ($TargetParameter) {
                # Explicit override: skip discovery, but fail fast if the parameter doesn't exist.
                if ($targetParams -notcontains $TargetParameter) {
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.ArgumentException]::new("Cmdlet '$Cmdlet' has no parameter '$TargetParameter'."),
                        'TargetParameterNotFound',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $TargetParameter
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
                $idParam = $TargetParameter
            } else {
                # Common identity parameter names used across many modules
                $preferredIdParams = @("Identity","UserId","Mailbox","PrimarySmtpAddress","Guid","Id","Name")
                $idParam = $preferredIdParams | Where-Object { $targetParams -contains $_ } | Select-Object -First 1

                if (-not $idParam) {
                    # Terminate up front so process{} never runs with an undefined identity parameter.
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.ArgumentException]::new("Could not determine an identity parameter for cmdlet '$Cmdlet'. Expected one of: $($preferredIdParams -join ', '). Use -TargetParameter to name it explicitly."),
                        'IdentityParameterNotFound',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $Cmdlet
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }
        }
    }

    process {
        if ($null -eq $InputObject) { return }

        $inputProps = $InputObject.PSObject.Properties

        if ($isScriptBlock) {
            # Script-block form: expose the whole input object as $_ and let the caller drive the call.
            # Identity discovery, IdentityProperty and Options do not apply here.
            $obj2 = try {
                $InputObject | ForEach-Object $Cmdlet
            } catch {
                # Failed enrichment falls back to passthrough; surface the reason on the
                # verbose stream so failures are distinguishable from "no match".
                Write-Verbose "Enrichment script block failed: $($_.Exception.Message). Passing the input object through unchanged."
                $null
            }
        } else {
            # 1. Locate the source property for identity
            if ($IdentityProperty) {
                $srcProp = $inputProps | Where-Object Name -eq $IdentityProperty
            } else {
                # Heuristic search for identity-related fields in the source object. Iterate the
                # preferred list (not the object's properties) so the list order decides the
                # priority - matching how the target parameter is discovered in begin{}.
                $preferredProps = @("ExternalDirectoryObjectId","PrimarySmtpAddress","UserPrincipalName","Identity","Alias","Guid","Id","Name")
                $srcProp = $preferredProps | ForEach-Object { $inputProps[$_] } | Where-Object { $_ } | Select-Object -First 1
            }

            if (-not $srcProp) {
                if ($IdentityProperty) {
                    Write-Warning "Input object has no '$IdentityProperty' property. Passing it through unchanged."
                } else {
                    Write-Warning "No identity property found on the input object. Passing it through unchanged."
                }
                return $InputObject
            }

            # 2. Prepare Splatting for the target cmdlet
            $splat = @{ $idParam = $srcProp.Value }

            if ($Options) {
                foreach ($key in $Options.Keys) {
                    # Add user options if they don't conflict with the dynamic identity
                    if (-not $splat.ContainsKey($key)) {
                        $splat[$key] = $Options[$key]
                    }
                }
            }

            # Default to a terminating ErrorAction so failures reach the catch below,
            # but let an ErrorAction supplied via -Options win instead of overriding it.
            if (-not $splat.ContainsKey('ErrorAction')) {
                $splat['ErrorAction'] = 'Stop'
            }

            # 3. Execute secondary cmdlet
            $obj2 = try {
                & $Cmdlet @splat
            } catch {
                # Failed enrichment falls back to passthrough; surface the reason on the
                # verbose stream so failures are distinguishable from "no match".
                Write-Verbose "Call to '$Cmdlet' with $idParam '$($srcProp.Value)' failed: $($_.Exception.Message). Passing the input object through unchanged."
                $null
            }
        }

        # If the target returns multiple objects, enrich from the first match - but say so,
        # instead of silently dropping the rest.
        if ($obj2 -is [System.Collections.IEnumerable] -and $obj2 -isnot [string]) {
            $matches2 = @($obj2)
            if ($matches2.Count -gt 1) {
                Write-Warning "The enrichment returned $($matches2.Count) objects; merging only the first one."
            }
            $obj2 = $matches2 | Select-Object -First 1
        }

        # If no match is found, pass through the original object
        if ($null -eq $obj2) { return $InputObject }

        # 4. Merge data into an ordered dictionary to preserve the property order
        $mergedResult = [ordered]@{}

        # Load properties from source object
        foreach ($p in $inputProps) {
            $mergedResult[$p.Name] = $p.Value
        }

        # Add or overwrite properties from the second object
        foreach ($p in $obj2.PSObject.Properties) {
            # Use key existence (not value) so source properties with a $null value still collide.
            if ($mergedResult.Contains($p.Name)) {
                if ($Force) {
                    $mergedResult[$p.Name] = $p.Value
                } else {
                    # Avoid property collisions by adding an incrementing suffix (_2, _3, ...) so
                    # repeated collisions - e.g. from chaining several Join-Object calls - don't
                    # silently overwrite each other under the same fixed name.
                    $suffix = 2
                    while ($mergedResult.Contains("$($p.Name)_$suffix")) {
                        $suffix++
                    }
                    $mergedResult["$($p.Name)_$suffix"] = $p.Value
                }
            } else {
                $mergedResult[$p.Name] = $p.Value
            }
        }

        # Return as a clean PSObject
        [pscustomobject]$mergedResult
    }
}
