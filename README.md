# Claude Code Calibrator

Teach Claude once, apply automatically.

A Claude Code plugin that learns from your corrections and applies them consistently.

## Core Concept

### Manual Recording
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

### Auto-Detection (Default)
```
Claude fixes lint/type/build/test error
       ↓
Pattern automatically recorded (no /calibrate needed)
       ↓
Same pattern repeats 2+ times
       ↓
Claude suggests: "💡 Pattern repeated 2x → /calibrate review"
       ↓
Promote to Skill with /calibrate review
```

## Installation
First, add the plugin to your local marketplace, and then install it:
```bash
/plugin marketplace add yhzion/claude-code-calibrator
/plugin install calibrator@yhzion-claude-code-calibrator
```

### Update

```bash
/plugin marketplace update yhzion-claude-code-calibrator
```

### Uninstall
To completely remove the plugin, first uninstall it and then remove it from the marketplace:
```bash
/plugin uninstall calibrator@yhzion-claude-code-calibrator
/plugin marketplace remove yhzion-claude-code-calibrator
```

## Usage

### Initialize

```bash
/calibrate init
```

Creates the Calibrator database and directory structure.

<details>
<summary>📖 Detailed Usage</summary>

**What it creates:**
- `.claude/calibrator/patterns.db` - SQLite database
- `.claude/skills/` - Directory for promoted Skills
- Adds entries to `.gitignore` (for Git projects)

**Flow:**

1. **Confirmation:**
   - "Initialize Calibrator?" → [Yes, initialize] [Cancel]

2. **Auto-Detection Option:**
   - "Enable automatic pattern detection?" → [Yes (Recommended)] [No]
   - When enabled: Patterns are automatically recorded when fixing lint/type/build/test errors

3. **If Already Exists:**
   - "Calibrator already exists" → [Keep] [Reinitialize (delete data)]

4. **Completion:**
   ```
   ✅ Calibrator initialization complete

   - .claude/calibrator/patterns.db created
   - .claude/skills/ directory created
   - .gitignore updated (if Git project)
   - Auto pattern detection: enabled

   You can now record mismatches with /calibrate.
   Patterns will also be recorded automatically when fixing errors.
   ```

</details>

---

### Toggle Auto-Detection

```bash
/calibrate auto [on|off]
```

Enable or disable automatic pattern detection.

<details>
<summary>📖 Detailed Usage</summary>

**Commands:**

| Command | Description |
|---------|-------------|
| `/calibrate auto on` | Enable auto-detection (default) |
| `/calibrate auto off` | Disable auto-detection |
| `/calibrate auto` | Show current status |

**When enabled, patterns are automatically recorded when fixing:**
- Lint errors (ESLint, Prettier, Biome, etc.)
- Type errors (TypeScript, Flow, etc.)
- Build errors (Webpack, Vite, esbuild, etc.)
- Test failures (Jest, Vitest, pytest, etc.)

**Auto-detection notification:**
```
┌─ 🔄 Auto-Calibrate ──────────────────────────────┐
│ Recorded: "TypeScript async/await handling"      │
│ Category: missing | Occurrences: 2               │
└──────────────────────────────────────────────────┘
💡 Pattern repeated 2x → /calibrate review to promote to skill
```

</details>

---

### Record Mismatches

```bash
/calibrate
```

Record patterns when Claude generates something different from your expectations.

<details>
<summary>📖 Detailed Usage</summary>

**Step 1: Category Selection**
```
What kind of mismatch just happened?

1. Something was missing
2. There was something unnecessary
3. I wanted a different approach
4. Let me explain
```

| Choice | Category |
|--------|----------|
| 1 | `missing` |
| 2 | `excess` |
| 3 | `style` |
| 4 | `other` |

**Step 2: Input Details**
```
In what situation, and what did you expect?
Example: "When creating a model, include timestamp field"

Situation: [your input]
Expected: [your input]
Instruction (imperative rule to learn): [your input]
```

| Field | Description | Max Length |
|-------|-------------|------------|
| Situation | When does this apply? | 500 chars |
| Expected | What did you expect? | 1000 chars |
| Instruction | Rule for Claude to learn | 2000 chars |

**Step 3: Confirmation**
```
✅ Record complete

Situation: {situation}
Expected: {expectation}
Instruction: {instruction}

Same pattern accumulated {count} times
```

If the pattern repeats 2+ times:
```
💡 You can promote this to a Skill with /calibrate review.
```

</details>

---

### Review & Promote to Skills

```bash
/calibrate review
```

Promote patterns that have repeated 2+ times to Skills.

<details>
<summary>📖 Detailed Usage</summary>

**Step 1: View Candidates**
```
📊 Skill Promotion Candidates (2+ repetitions)

[id=12] Model creation → Always include timestamp fields (3 times)
[id=15] API endpoint → Always include error handling (2 times)

Enter pattern id(s) to promote (comma-separated for multiple): _
```

If no candidates:
```
📊 No patterns available for promotion

Patterns need to repeat 2+ times to be promoted to a Skill.
Keep recording with /calibrate.
```

**Step 2: Skill Preview**
```
📝 Skill Preview: {situation}

---
name: {kebab-case situation}
description: {instruction}. Auto-applied in {situation} situations.
learned_from: calibrator ({count} repetitions, {first_seen} ~ {last_seen})
---

## Rules

{instruction}

## Applies to

- {situation}

## Learning History

This Skill was auto-generated by Calibrator.
- First detected: {first_seen}
- Last detected: {last_seen}
- Repetitions: {count}

---

[Save] [Edit] [Skip]
```

**Step 3: Result**
```
✅ Skill created

- .claude/skills/{skill-name}/SKILL.md

🔄 To activate this Skill, start a new Claude Code session.
   (Skills are loaded at session start)

Claude will then automatically apply this rule in "{situation}" situations.
```

</details>

---

### View Statistics

```bash
/calibrate status
```

View currently recorded patterns and statistics.

<details>
<summary>📖 Detailed Usage</summary>

**Output:**
```
📊 Calibrator Status

Total observations: {count}
Detected patterns: {count}
├─ Promoted to Skills: {count}
└─ Pending promotion (2+): {count}

Recent records:
- [{timestamp}] {category}: {situation}
- [{timestamp}] {category}: {situation}
- [{timestamp}] {category}: {situation}
```

If pending patterns exist:
```
💡 Run /calibrate review to promote pending patterns to Skills.
```

If no data recorded:
```
📊 Calibrator Status

No data recorded yet.
Record your first mismatch with /calibrate.
```

</details>

---

### Edit Skills & Merge Patterns

```bash
/calibrate refactor
```

Edit existing Skills, merge similar patterns, or remove duplicates.

<details>
<summary>📖 Detailed Usage</summary>

**Mode Selection:**
```
🔧 Calibrator Refactor

What would you like to do?

1. Edit Skill - Modify instruction or situation of existing Skills
2. Merge patterns - Combine similar patterns (same situation)
3. Remove duplicates - Delete exact duplicate patterns

Select mode (1/2/3):
```

**Mode 1: Edit Skill**
- View all promoted Skills
- Select a Skill to edit by ID
- Modify situation, instruction, or both
- Updates both database and SKILL.md file

**Mode 2: Merge Patterns**
- Find patterns with same situation but different instructions
- Select patterns to merge
- Choose primary instruction to keep
- Combines counts from merged patterns

**Mode 3: Remove Duplicates**
- Detects exact duplicate patterns
- Cleans up database integrity issues
- Keeps one copy of each unique pattern

</details>

---

### Delete Skills

```bash
/calibrate delete
```

Delete promoted Skills (multi-select support).

<details>
<summary>📖 Detailed Usage</summary>

**Step 1: View Promoted Skills**
```
🗑️ Delete Promoted Skills

Select Skills to delete (pattern data will be preserved, only SKILL.md files will be removed):

[id=1] Creating React components → Always define TypeScript interface (3 times)
       Path: .claude/skills/creating-react-components
[id=5] API endpoints → Always include error handling (5 times)
       Path: .claude/skills/api-endpoints

Enter skill id(s) to delete (comma-separated for multiple, or 'skip' to cancel):
Example: 1 or 1,5
```

**Step 2: Confirmation**
- "Are you sure you want to delete these Skills?"
- [Yes, delete selected Skills] [Cancel]

**Step 3: Result**
```
✅ Skill deletion complete

- Deleted: 2 skill(s)
- Failed: 0 skill(s)

Pattern data has been preserved. You can re-promote patterns with /calibrate review.

🔄 Restart Claude Code session to apply changes.
```

**What happens:**
- SKILL.md file: Deleted
- Skill directory: Preserved (empty directory remains)
- Database pattern: Preserved with `promoted = 0`
- Pattern count: Preserved (can be re-promoted later)

</details>

---

### Show Help

```bash
/calibrate help
```

Display available commands and current status.

<details>
<summary>📖 Detailed Usage</summary>

**Output (when initialized):**
```
📚 Calibrator Help

Status: ✅ Initialized | Patterns: {count} | Skills: {count} | Pending: {count}

Commands:
  /calibrate init      Initialize Calibrator
  /calibrate           Record an expectation mismatch
  /calibrate status    View statistics
  /calibrate review    Promote patterns to Skills
  /calibrate refactor  Edit Skills and merge patterns
  /calibrate delete    Delete promoted Skills
  /calibrate auto      Toggle auto pattern detection (on/off)
  /calibrate reset     Delete all data
  /calibrate help      Show this help

Quick Start:
  1. /calibrate init → 2. /calibrate → 3. /calibrate review
```

</details>

---

### Reset Data

```bash
/calibrate reset
```

⚠️ Deletes all observation records and patterns. Generated Skills are preserved.

<details>
<summary>📖 Detailed Usage</summary>

**Step 1: Current Status**
```
⚠️ Calibrator Reset

Database file:
- {DB_PATH}

Data to delete:
- {count} observations
- {count} patterns

Note: Generated Skills (.claude/skills/) will be preserved.
```

**Step 2: Confirmation**
- "Are you sure you want to delete all Calibrator data?"
- [Yes, reset all data] [Cancel]

**Step 3: Result**
```
✅ Calibrator data has been reset

- Observations: all deleted
- Patterns: all deleted
- Skills: preserved (.claude/skills/)

Start new records with /calibrate.
```

</details>

## Example: Teaching Claude Your Preferences

Let's walk through a real scenario from start to finish.

### 😤 The Problem

You ask Claude to create a React component:

```
> Create a Button component
```

Claude responds:
```jsx
const Button = ({ label, onClick }) => {
  return <button onClick={onClick}>{label}</button>
}
```

**But you wanted TypeScript interfaces!** This keeps happening...

---

### 📝 Step 1: Record the Mismatch

Run `/calibrate` right after the mismatch:

```
What kind of mismatch just happened?
> 1. Something was missing

Situation: > Creating React components
Expected: > TypeScript interface for props
Instruction: > Always define a TypeScript interface for component props
```

Result:
```
✅ Record complete
Same pattern accumulated 1 times
```

---

### 🔄 Step 2: Pattern Repeats

A few days later, same thing happens with a Modal component. Run `/calibrate` again with the same situation and instruction.

```
✅ Record complete
Same pattern accumulated 2 times

💡 You can promote this to a Skill with /calibrate review.
```

---

### ⬆️ Step 3: Promote to Skill

Run `/calibrate review`:

```
📊 Skill Promotion Candidates (2+ repetitions)

[id=1] Creating React components → Always define a TypeScript interface... (2 times)

Enter pattern id(s) to promote: > 1
```

Preview and save:
```
📝 Skill Preview: Creating React components
...
[Save] [Edit] [Skip]
> Save

✅ Skill created: .claude/skills/creating-react-components/SKILL.md
```

---

### ✨ Result: Before vs After

**Restart Claude Code**, then ask the same question:

```
> Create a Button component
```

Now Claude responds:
```tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
}

const Button = ({ label, onClick }: ButtonProps) => {
  return <button onClick={onClick}>{label}</button>
}
```

🎉 **Claude learned your preference and applies it automatically!**

---

## Best Practice

The recommended workflow for effective calibration:

```
1. Work with Claude as usual
       ↓
2. Notice a mismatch? Run /calibrate immediately
       ↓
3. Be specific: "When creating React components" > "When coding"
       ↓
4. Write clear instructions: "Always use TypeScript interfaces"
       ↓
5. Let patterns accumulate naturally (2+ times)
       ↓
6. Review with /calibrate review weekly
       ↓
7. Restart Claude Code to activate new Skills
```

**Tips:**
- 📝 Record mismatches **right when they happen** - context matters
- 🎯 Be **specific** about the situation - vague patterns don't help
- ✍️ Write **imperative instructions** - "Always do X" or "Never do Y"
- 🔄 **Check `/calibrate status`** regularly to see accumulated patterns
- 🚀 After promoting Skills, **restart Claude Code** to load them
- 🤖 **Auto-detection** records patterns automatically when fixing errors - no manual `/calibrate` needed
- ⚙️ Use `/calibrate auto off` if you prefer **manual-only** recording

## How It Works

1. **Record**: Log situations where Claude's output didn't match expectations with `/calibrate`
2. **Aggregate**: Pattern count automatically increases when the same situation repeats
3. **Detect**: View patterns repeated 2+ times with `/calibrate review`
4. **Promote**: Once promoted to a Skill, Claude automatically applies it in similar situations

## Data Storage

| File | Purpose |
|------|---------|
| `.claude/calibrator/patterns.db` | SQLite DB (`observations`, `patterns`, `schema_version` tables) |
| `.claude/calibrator/auto-detect.enabled` | Flag file for auto-detection (exists = enabled) |
| `.claude/skills/*/SKILL.md` | Promoted Skills |

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
- Verify the skill file exists in `.claude/skills/`

## Requirements

- Claude Code
- sqlite3 CLI (pre-installed on macOS/Linux)
- SQLite version 3.24.0+ (for UPSERT support)

## License

MIT
