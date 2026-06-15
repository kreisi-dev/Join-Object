# MergeWith

`MergeWith` is a PowerShell module providing the **`Join-Object`** function (alias **`Join`**) — a pipeline join for PowerShell. It takes objects from the pipeline, determines a common identity property (e.g. UPN or GUID), calls a second cmdlet with it, and merges the properties of both results into a single object.

## Installation

Clone the repository and import the module:

```powershell
git clone <repository-url> MergeWith
Import-Module ./MergeWith/MergeWith.psd1
```

## Usage

```powershell
# Attach mailbox statistics to mailbox objects
Get-Mailbox | Join-Object Get-MailboxStatistics

# Short form using the 'Join' alias and an explicit identity property
Get-Service | Join Get-Process -IdentityProperty Name

# Join AD users with their mailboxes, suppressing errors
Get-ADUser -Filter "Name -like 'John*'" |
    Join-Object Get-Mailbox -Options @{ ErrorAction = 'SilentlyContinue' }

# Merge AD attributes and overwrite existing fields
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
MergeWith/
├── MergeWith.psd1            # Module manifest
├── MergeWith.psm1            # Loader for the public functions
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
