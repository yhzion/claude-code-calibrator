# Claude Code Calibrator

A Claude Code plugin that corrects patterns where LLM Agents repeatedly generate outputs that don't match user expectations.

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

## Usage

### Initialize

```bash
/calibrate init
```

During initialization, you'll be prompted to select your preferred language:
- English (default)
- Korean (한국어)
- Japanese (日本語)
- Chinese (中文)

Creates:
- `.claude/calibrator/patterns.db`
- `.claude/calibrator/config.json`
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
| `.claude/calibrator/patterns.db` | SQLite DB (observations, patterns tables) |
| `.claude/calibrator/config.json` | Configuration file (language, threshold, etc.) |
| `.claude/skills/learned/*/SKILL.md` | Promoted Skills |

## Supported Languages

All user-facing messages support multiple languages:
- `en` - English (default)
- `ko` - Korean
- `ja` - Japanese
- `zh` - Chinese

Language can be selected during `/calibrate init` or changed later by re-running init.

## Requirements

- Claude Code
- sqlite3 CLI (pre-installed on macOS/Linux)
- jq (JSON processor) - Install via `brew install jq` on macOS or `apt install jq` on Linux

## License

MIT
