# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Pester tests under `tests/`.

### Changed
- Renamed the `Merge-With` function to the verb-approved `Join-Object` (alias `Join`).
- Renamed the module from `MergeWith` to `JoinObject`.
- Switched all repository documentation to English.
- Hardened `Join-Object`: terminates cleanly when no identity parameter can be
  resolved, detects property collisions by key (handles `$null` values), and
  enriches from the first result when the target cmdlet returns several objects.

## [0.1.0] - 2026-06-15

### Added
- Initial version of the function (a pipeline join for PowerShell).
- Module manifest and loader (`.psd1` / `.psm1`).
