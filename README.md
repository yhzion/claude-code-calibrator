# Claude Code Calibrator

Teach Claude once, apply automatically.

A Claude Code plugin that learns from your corrections and applies them consistently.

## Core Concept

```
User requests Claude to correct output
       ↓
Record mismatch with /calibrate
       ↓
Detect when same pattern repeats
       ↓
Promote to Skill with /calibrate review
       ↓
Claude automatically applies pattern going forward
```

## Installation

```bash
/plugin marketplace add yhzion/claude-code-calibrator
/plugin install calibrator@yhzion-claude-code-calibrator
```

### Update

```bash
/plugin marketplace update yhzion-claude-code-calibrator
```

### Uninstall

```bash
/plugin uninstall calibrator@yhzion-claude-code-calibrator
/plugin marketplace remove yhzion-claude-code-calibrator
```

## Usage

### Initialize

```bash
/calibrate init
```

Creates:
- `.claude/calibrator/patterns.db`
- `.claude/skills/learned/` directory

### Record Mismatches

```bash
/calibrate
```

Record patterns when Claude generates something different from your expectations:
1. Select category (missing/excess/style/other)
2. Enter situation and expectation
3. Automatically saved to database

### Review & Promote to Skills

```bash
/calibrate review
```

Promote patterns that have repeated 2+ times to Skills:
- View list of promotion candidates
- Preview and edit Skill before saving
- Creates `SKILL.md` in `.claude/skills/learned/`

### View Statistics

```bash
/calibrate status
```

- Total observation records
- Detected pattern count
- Skill promotion status
- Recent records

### Reset Data

```bash
/calibrate reset
```

Deletes all observation records and patterns. Generated Skills are preserved.

## How It Works

1. **Record**: Log situations where Claude's output didn't match expectations with `/calibrate`
2. **Aggregate**: Pattern count automatically increases when the same situation repeats
3. **Detect**: View patterns repeated 2+ times with `/calibrate review`
4. **Promote**: Once promoted to a Skill, Claude automatically applies it in similar situations

## Data Storage

| File | Purpose |
|------|---------|
| `.claude/calibrator/patterns.db` | SQLite DB (`observations`, `patterns`, `schema_version` tables) |
| `.claude/skills/learned/*/SKILL.md` | Promoted Skills |

## Security Considerations

### Data Privacy
- **patterns.db may contain sensitive data**: The database stores situations and expectations you record. Be mindful of what information you include.
- **Automatic .gitignore**: The init command automatically adds `.claude/calibrator/` to `.gitignore` to prevent accidental commits.
- **Backup exclusions**: Consider excluding `.claude/calibrator/` from cloud sync services if it contains sensitive information.

### File Permissions
- Ensure `.claude/` directory is not world-readable if it contains sensitive patterns
- The database file should only be accessible by your user account

### Input Validation
- SQL injection is prevented through quote escaping
- Path traversal is prevented in skill name generation
- Config validation warns about malformed configuration

## Troubleshooting

### Common Issues

**"sqlite3 is required but not installed"**
- macOS/Linux: sqlite3 is typically pre-installed
- Windows: Install from https://sqlite.org/download.html

**Skills not being applied**
- Ensure the skill was properly promoted (check `/calibrate status`)
- Verify the skill file exists in `.claude/skills/learned/`

## Requirements

- Claude Code
- sqlite3 CLI (pre-installed on macOS/Linux)
- SQLite version 3.24.0+ (for UPSERT support)

## License

MIT
