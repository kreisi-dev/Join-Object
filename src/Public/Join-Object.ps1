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
        The name of the cmdlet to call for the enrichment (e.g., 'Get-ADUser', 'Get-Mailbox Statistics').

    .PARAMETER InputObject
        The object coming from the pipeline.

    .PARAMETER IdentityProperty
        Optional: Explicitly define which property of the InputObject should be used as the identity.

    .PARAMETER Options
        A hashtable of additional parameters to pass to the target cmdlet (e.g., @{Properties = '*'}).
        Aliases: Args, With, Splat, Parameters

    .PARAMETER Force
        If set, properties from the second cmdlet will overwrite existing properties of the InputObject.

    .EXAMPLE
        Get-Mailbox | Join-Object Get-MailboxStatistics
        Simple merge: Adds mailbox statistics to your mailbox objects.

    .EXAMPLE
        Get-Service | Join Get-Process -IdentityProperty Name
        Joins services with their corresponding processes by name (using the 'Join' alias).

    .EXAMPLE
        Get-ADUser -Filter "Name -like 'John*'" | Join-Object Get-Mailbox -Options @{ErrorAction = 'SilentlyContinue'}
        Joins AD users with their Exchange mailboxes, suppressing errors if a user has no mailbox.

    .EXAMPLE
        $Data | Join-Object Get-ADUser -With @{Properties = "Department", "Office"} -Force
        Merges AD attributes and overwrites any existing 'Department' or 'Office' fields in the source data.
    #>
    [CmdletBinding()]
    [Alias('Join')]
    param(
        [Parameter(Mandatory, Position=0)]
        [string] $Cmdlet,

        [Parameter(ValueFromPipeline)]
        $InputObject,

        [string] $IdentityProperty,

        [Alias("Args", "With", "Splat", "Parameters")]
        [hashtable] $Options,

        [switch] $Force
    )

    begin {
        # Resolve the target cmdlet. A missing cmdlet surfaces as a clean terminating error.
        $cmdInfo = Get-Command $Cmdlet -ErrorAction Stop
        $targetParams = @($cmdInfo.Parameters.Keys)

        # Common identity parameter names used across many modules
        $preferredIdParams = @("Identity","UserId","Mailbox","PrimarySmtpAddress","Guid","Id","Name")
        $idParam = $preferredIdParams | Where-Object { $targetParams -contains $_ } | Select-Object -First 1

        if (-not $idParam) {
            # Terminate up front so process{} never runs with an undefined identity parameter.
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new("Could not determine an identity parameter for cmdlet '$Cmdlet'. Expected one of: $($preferredIdParams -join ', ')."),
                'IdentityParameterNotFound',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $Cmdlet
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }

    process {
        if ($null -eq $InputObject) { return }

        # 1. Locate the source property for identity
        $inputProps = $InputObject.PSObject.Properties

        if ($IdentityProperty) {
            $srcProp = $inputProps | Where-Object Name -eq $IdentityProperty
        } else {
            # Heuristic search for identity-related fields in the source object
            $preferredProps = @("ExternalDirectoryObjectId","PrimarySmtpAddress","UserPrincipalName","Identity","Alias","Guid","Id","Name")
            $srcProp = $inputProps | Where-Object { $preferredProps -contains $_.Name } | Select-Object -First 1
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

        # 3. Execute secondary cmdlet
        $obj2 = try {
            & $Cmdlet @splat -ErrorAction Stop
        } catch {
            $null
        }

        # If the target returns multiple objects, enrich from the first match.
        if ($obj2 -is [System.Collections.IEnumerable] -and $obj2 -isnot [string]) {
            $obj2 = $obj2 | Select-Object -First 1
        }

        # If no match is found, pass through the original object
        if ($null -eq $obj2) { return $InputObject }

        # 4. Merge data using an ordered dictionary for performance
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
                    # Avoid property collisions by adding a suffix
                    $mergedResult["$($p.Name)_Second"] = $p.Value
                }
            } else {
                $mergedResult[$p.Name] = $p.Value
            }
        }

        # Return as a clean PSObject
        [pscustomobject]$mergedResult
    }
}
