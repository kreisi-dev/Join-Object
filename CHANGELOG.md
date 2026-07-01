# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.9.0] - 2026-07-01

### Added
- Pester tests under `tests/`.
- `Join-Object` now accepts a script block for the `Cmdlet` parameter, exposing the
  full input object as `$_` for complete control over the enrichment call (no identity
  discovery or auto-splatting in this mode).

### Changed
- Renamed the `Merge-With` function to the verb-approved `Join-Object` (alias `Join`).
- Renamed the module from `MergeWith` to `JoinObject`.
- Switched all repository documentation to English.
- Hardened `Join-Object`: terminates cleanly when no identity parameter can be
  resolved, detects property collisions by key (handles `$null` values), and
  enriches from the first result when the target cmdlet returns several objects.
- Repeated property collisions now get an incrementing suffix (`_2`, `_3`, ...)
  instead of a fixed `_Second` name, which previously let a third collision on the
  same property silently overwrite the value from the second.

### Fixed
- `JoinObject.psm1` now warns when imported directly (bypassing the module
  manifest), since that path leaves `Get-Command`'s reported version at `0.0`.

## [0.1.0] - 2026-06-15

### Added
- Initial version of the function (a pipeline join for PowerShell).
- Module manifest and loader (`.psd1` / `.psm1`).
