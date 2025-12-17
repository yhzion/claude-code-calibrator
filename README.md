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

Creates the Calibrator database and directory structure.

<details>
<summary>📖 Detailed Usage</summary>

**What it creates:**
- `.claude/calibrator/patterns.db` - SQLite database
- `.claude/skills/learned/` - Directory for promoted Skills
- Adds entries to `.gitignore` (for Git projects)

**Flow:**

1. **New Installation:**
   ```
   ⚙️ Calibrator Initialization

   Files to create:
   - .claude/calibrator/patterns.db

   [Confirm] [Cancel]
   ```

2. **If Already Exists:**
   ```
   ⚠️ Calibrator already exists

   Current files:
   - .claude/calibrator/patterns.db

   [Keep] [Reinitialize (delete data)]
   ```

3. **Completion:**
   ```
   ✅ Calibrator initialization complete

   - .claude/calibrator/patterns.db created
   - .claude/skills/learned/ directory created
   - .gitignore updated (if Git project)

   You can now record mismatches with /calibrate.
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

Note: Generated Skills (.claude/skills/learned/) will be preserved.

Really reset? Type "reset" to confirm: _
```

**Step 2: Confirmation**
- Type `reset` to proceed
- Any other input cancels the operation

**Step 3: Result**
```
✅ Calibrator data has been reset

- Observations: all deleted
- Patterns: all deleted
- Skills: preserved (.claude/skills/learned/)

Start new records with /calibrate.
```

</details>

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
