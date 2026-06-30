# JoinObject

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
# It works for any pair of cmdlets that share an identity — e.g. services and their processes:
Get-Service |
    Join Get-Process -IdentityProperty Name |
    Select-Object Name, Status, CPU, WorkingSet
```

No buffering, no repeated lookups, no computed-property gymnastics — just one pipe.

## Installation

Clone the repository and import the module:

```powershell
git clone <repository-url> JoinObject
Import-Module ./JoinObject/JoinObject.psd1
```

## More examples

```powershell
# Pass extra parameters to the target cmdlet via -Options, e.g. to suppress errors
Get-ADUser -Filter "Name -like 'John*'" |
    Join-Object Get-Mailbox -Options @{ ErrorAction = 'SilentlyContinue' }

# -With is an alias for -Options; -Force overwrites existing fields instead of
# suffixing collisions with _Second
$Data | Join-Object Get-ADUser -With @{ Properties = 'Department', 'Office' } -Force
```

Full help is available after import:

```powershell
Get-Help Join-Object -Full
```

## Parameters (overview)

| Parameter          | Description                                                                  |
| ------------------ | ---------------------------------------------------------------------------- |
| `Cmdlet`           | Name of the cmdlet called to enrich the data.                                |
| `InputObject`      | The object coming from the pipeline.                                         |
| `IdentityProperty` | Optional: explicit identity property of the input object.                    |
| `Options`          | Hashtable of additional parameters for the target cmdlet (alias: `With`).    |
| `Force`            | Overwrites existing properties instead of suffixing them with `_Second`.     |

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
