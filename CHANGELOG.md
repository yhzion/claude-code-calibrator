# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Stricter SQLite schema constraints (category enum, length limits) and performance indexes

### Changed

- `.gitignore` SQLite journal ignores are now scoped to `.claude/calibrator/`

### Removed

- Auto-detection hook (`PostToolUse` hook for Bash error detection)
- Auto-calibrate skill (`auto-calibrate.md`)
- `/calibrate auto` command for toggling auto-detection
- `auto-detect.enabled` flag file support
- Locale/i18n support (English-only for now to reduce error surface)
- `config.json`/`jq` dependency (defaults are now fixed to reduce runtime variability)

## [0.1.0] - 2024-12-17

### Added

- Initial release of Claude Code Calibrator plugin
- `/calibrate init` command - Initialize SQLite database and directory structure
- `/calibrate` command - Record expectation mismatches with category selection (missing/excess/style/other)
- `/calibrate review` command - Review patterns and promote to Skills (2+ occurrences threshold)
- `/calibrate status` command - View statistics and recent observations
- `/calibrate reset` command - Reset all observation data (preserves generated Skills)
- SQLite-based pattern storage (`patterns.db`)
- Automatic pattern detection for repeated mismatches
- Skill template for generated learning files

[Unreleased]: https://github.com/yhzion/claude-code-calibrator/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yhzion/claude-code-calibrator/releases/tag/v0.1.0
