# JoinObject

[![CI](https://github.com/kreisi-dev/Join-Object/actions/workflows/ci.yml/badge.svg)](https://github.com/kreisi-dev/Join-Object/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/JoinObject.svg)](https://www.powershellgallery.com/packages/JoinObject)

PowerShell's pipeline lets you write remarkably elegant one-liners. As long as you stay within a single cmdlet's output, life is good:

```powershell
Get-Mailbox -RecipientTypeDetails SharedMailbox |
    Get-MailboxStatistics |
    Select-Object DisplayName, TotalItemSize
```

But the moment you need values from **two different cmdlets** in the same result, that elegance falls apart. `Get-MailboxStatistics` returns its *own* objects — the `Department`, `Office` or `PrimarySmtpAddress` you had on the `Get-Mailbox` object are gone. You're left with two awkward workarounds:

**1. Buffer everything in a loop:**

```powershell
$report = foreach ($mbx in Get-Mailbox -RecipientTypeDetails SharedMailbox) {
    $stats = Get-MailboxStatistics -Identity $mbx.PrimarySmtpAddress
    [pscustomobject]@{
        DisplayName   = $mbx.DisplayName
        Department    = $mbx.Department
        TotalItemSize = $stats.TotalItemSize
        ItemCount     = $stats.ItemCount
    }
}
```

**2. Or reach back out with computed properties:**

```powershell
Get-Mailbox -RecipientTypeDetails SharedMailbox |
    Select-Object DisplayName, Department,
        @{ Name = 'TotalItemSize'; Expression = { (Get-MailboxStatistics -Identity $_.PrimarySmtpAddress).TotalItemSize } },
        @{ Name = 'ItemCount';     Expression = { (Get-MailboxStatistics -Identity $_.PrimarySmtpAddress).ItemCount } }
```

Both work, but both hurt: the loop throws the pipeline away, and the computed properties call `Get-MailboxStatistics` *once per column* — the same expensive lookup, over and over.

## Enter Join-Object

<p align="center">
  <img src="docs/join-object.svg" alt="Two cmdlet outputs sharing a common identity (ID) are merged by Join-Object into a single object with all fields." width="460">
</p>

`Join-Object` (alias **`Join`**) brings the join back into the pipeline. For each object it finds a shared identity (like `PrimarySmtpAddress` or a GUID), calls the second cmdlet **once**, and merges both results into a single object — so you just keep piping:

```powershell
# Everything above, in one readable line:
Get-Mailbox -RecipientTypeDetails SharedMailbox |
    Join-Object Get-MailboxStatistics |
    Select-Object DisplayName, Department, TotalItemSize, ItemCount
```

```powershell
# It works for any pair of cmdlets that share an identity — e.g. services and their processes.
# -IdentityProperty picks the source property; -TargetParameter names the parameter of the
# target cmdlet (automatic discovery would pick Get-Process -Id here):
Get-Service |
    Join Get-Process -IdentityProperty Name -TargetParameter Name |
    Select-Object Name, Status, CPU, WorkingSet
```

`Join-Object` calls also chain, so you can pull data from three (or more) cmdlets in one pipeline:

```powershell
# Mailbox -> mailbox statistics -> AD user, joined in a single readable chain:
Get-RemoteMailbox |
    Join-Object Get-MailboxStatistics |
    Join-Object Get-ADUser -IdentityProperty SamAccountName |
    Select-Object Prim*, TotalItemSize, Enabled
```

No buffering, no repeated lookups, no computed-property gymnastics — just one pipe.

### Script-block support

`Cmdlet` also accepts a script block instead of a cmdlet name. The full input object is exposed as `$_`, giving you complete control over the enrichment call — no identity discovery or auto-splatting in this mode:

```powershell
Get-RemoteMailbox |
    Join-Object { Get-Mailbox -Identity $_.PrimarySmtpAddress -ErrorAction SilentlyContinue }
```

Check the [Releases page](https://github.com/kreisi-dev/Join-Object/releases) for the full version history.

## Installation

Install from the [PowerShell Gallery](https://www.powershellgallery.com/packages/JoinObject):

```powershell
Install-Module -Name JoinObject
Import-Module JoinObject
```

For development, clone the repository and import the manifest directly:

```powershell
git clone https://github.com/kreisi-dev/Join-Object.git JoinObject
Import-Module ./JoinObject/JoinObject.psd1
```

## More examples

```powershell
# Pass extra parameters to the target cmdlet via -Options, e.g. to suppress errors
Get-ADUser -Filter "Name -like 'John*'" |
    Join-Object Get-Mailbox -Options @{ ErrorAction = 'SilentlyContinue' }

# -With is an alias for -Options; -Force overwrites existing fields instead of
# suffixing collisions with _2, _3, ...
$Data | Join-Object Get-ADUser -With @{ Properties = 'Department', 'Office' } -Force
```

### Property collisions

If a property name exists on both the input object and the enrichment result, the second
value is kept under an incrementing suffix (`_2`, `_3`, ...) instead of being dropped:

```powershell
# Chaining calls that each return an 'Identity' property keeps every value:
Get-RemoteMailbox |
    Join-Object Get-MailboxStatistics |   # adds Identity_2
    Join-Object Get-ADUser -IdentityProperty SamAccountName   # adds Identity_3
```

Pass `-Force` to overwrite the existing value instead of suffixing it.

Full help is available after import:

```powershell
Get-Help Join-Object -Full
```

## Parameters (overview)

| Parameter          | Description                                                                  |
| ------------------ | ---------------------------------------------------------------------------- |
| `Cmdlet`           | Name of the cmdlet (or a script block) called to enrich the data.            |
| `InputObject`      | The object coming from the pipeline.                                         |
| `IdentityProperty` | Optional: explicit identity property of the input object.                    |
| `TargetParameter`  | Optional: explicit parameter of the target cmdlet that receives the identity. |
| `Options`          | Hashtable of additional parameters for the target cmdlet (alias: `With`).    |
| `Force`            | Overwrites existing properties instead of suffixing them with `_2`, `_3`, ... |

## Project structure

```
JoinObject/
├── JoinObject.psd1           # Module manifest
├── JoinObject.psm1           # Loader for the public functions
├── src/
│   └── Public/
│       └── Join-Object.ps1   # Implementation of Join-Object (alias: Join)
└── tests/
    └── Join-Object.Tests.ps1 # Pester tests
```

## Testing

Tests are written with [Pester](https://pester.dev) (5.x):

```powershell
Invoke-Pester -Path ./tests
```

## Requirements

- PowerShell 5.1 or later
- Pester 5.x (for running the tests)

## License

Released under the MIT License — see [LICENSE](LICENSE).
