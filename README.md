# MergeWith

`MergeWith` ist ein PowerShell-Modul mit der Funktion **`Join-Object`** (Alias **`Join`**) – einem „Left Join" für die PowerShell-Pipeline. Es nimmt Objekte aus der Pipeline, ermittelt eine gemeinsame Identitätseigenschaft (z. B. UPN oder GUID), ruft damit ein zweites Cmdlet auf und führt die Eigenschaften beider Ergebnisse zu einem Objekt zusammen.

## Installation

Repository klonen und das Modul importieren:

```powershell
git clone <repository-url> MergeWith
Import-Module ./MergeWith/MergeWith.psd1
```

## Verwendung

```powershell
# Postfachstatistiken an Postfach-Objekte anhängen
Get-Mailbox | Join-Object Get-MailboxStatistics

# Kurzform über den Alias 'Join' und eine explizite Identitätseigenschaft
Get-Service | Join Get-Process -IdentityProperty Name

# AD-Benutzer mit Postfächern verbinden, Fehler unterdrücken
Get-ADUser -Filter "Name -like 'John*'" |
    Join-Object Get-Mailbox -Options @{ ErrorAction = 'SilentlyContinue' }

# AD-Attribute mergen und bestehende Felder überschreiben
$Data | Join-Object Get-ADUser -With @{ Properties = 'Department', 'Office' } -Force
```

Die vollständige Hilfe ist nach dem Import verfügbar:

```powershell
Get-Help Join-Object -Full
```

## Parameter (Kurzüberblick)

| Parameter          | Beschreibung                                                                 |
| ------------------ | --------------------------------------------------------------------------- |
| `Cmdlet`           | Name des Cmdlets, das zur Anreicherung aufgerufen wird.                      |
| `InputObject`      | Das Objekt aus der Pipeline.                                                 |
| `IdentityProperty` | Optional: explizite Identitätseigenschaft des Eingabeobjekts.               |
| `Options`          | Hashtable mit zusätzlichen Parametern für das Ziel-Cmdlet (Aliase: `With`). |
| `Force`            | Überschreibt bestehende Eigenschaften statt sie mit `_Second` zu suffixen.  |

## Projektstruktur

```
MergeWith/
├── MergeWith.psd1            # Modul-Manifest
├── MergeWith.psm1            # Lader für die öffentlichen Funktionen
└── src/
    └── Public/
        └── Join-Object.ps1   # Implementierung von Join-Object (Alias: Join)
```

## Anforderungen

- PowerShell 5.1 oder höher

## Lizenz

Veröffentlicht unter der MIT-Lizenz – siehe [LICENSE](LICENSE).
