# Skillfy

![macOS: compatible](https://img.shields.io/badge/macOS-compatible-brightgreen?style=for-the-badge&logo=apple&logoColor=white)
![Linux: compatible](https://img.shields.io/badge/Linux-compatible-brightgreen?style=for-the-badge&logo=linux&logoColor=white)
![Windows: coming soon](https://img.shields.io/badge/Windows-coming%20soon-yellow?style=for-the-badge&logo=windows&logoColor=white)

Turn your corrections into reusable Claude Code Skills.

A Claude Code plugin that transforms your feedback into persistent learning.

## Core Concept

```
User corrects Claude's output
       ↓
Record with /skillfy
       ↓
Promote to Skill with /skillfy review
       ↓
Claude automatically applies the rule going forward
```

## Installation

First, add the plugin to your local marketplace, and then install it:
```bash
/plugin marketplace add https://github.com/yhzion/claude-code-skillfy.git
/plugin install skillfy@yhzion-claude-code-skillfy
```

### Update

```bash
/plugin marketplace update yhzion-claude-code-skillfy
```

### Uninstall

To completely remove the plugin, first uninstall it and then remove it from the marketplace:
```bash
/plugin uninstall skillfy@yhzion-claude-code-skillfy
/plugin marketplace remove yhzion-claude-code-skillfy
```

## Usage

### Initialize

```bash
/skillfy init
```

Creates the Skillfy database and directory structure.

<details>
<summary>📖 Detailed Usage</summary>

**What it creates:**
- `.claude/skillfy/patterns.db` - SQLite database
- `.claude/skills/` - Directory for promoted Skills
- Adds entries to `.gitignore` (for Git projects)

**Flow:**

1. **Confirmation:**
   - "Initialize Skillfy?" → [Yes, initialize] [Cancel]

2. **If Already Exists:**
   - "Skillfy already exists" → [Keep] [Reinitialize (delete data)]

3. **Completion:**
   ```
   ✅ Skillfy initialization complete

   - .claude/skillfy/patterns.db created
   - .claude/skills/ directory created
   - .gitignore updated (if Git project)

   You can now record mismatches with /skillfy.
   ```

</details>

---

### Record Mismatches

```bash
/skillfy
```

Record patterns when Claude generates something different from your expectations.

<details>
<summary>📖 Detailed Usage</summary>

**Step 1: Situation Selection**

Claude analyzes the current session and suggests relevant situations:
```
Recording Pattern Mismatch

What situation did this happen in?

1. {Suggested situation from context}
2. {Another suggestion}
3. Enter manually

Select:
```

**Step 2: Expectation Input**
```
What did you expect? (max 1000 chars)
Example: "Include timestamp field", "Use TypeScript interfaces"
```

**Step 3: Instruction Input**
```
What rule should Claude learn? (imperative form, max 2000 chars)
Example: "Always include timestamp fields", "Never use var in JavaScript"
```

**Step 4: Action Selection**
```
Record Summary

Situation: {situation}
Expected: {expectation}
Instruction: {instruction}

What would you like to do?

1. Register as Skill - Create skill file immediately
2. Save as memo - Store in DB for later review
3. Cancel

Select:
```

</details>

---

### Review & Promote to Skills

```bash
/skillfy review
```

Review saved patterns and promote them to Skills.

<details>
<summary>📖 Detailed Usage</summary>

**Step 1: View Saved Patterns**
```
Saved Patterns (not yet promoted)

[id=12] When creating models → Always include timestamp fields (2024-12-18)
[id=15] When writing API endpoints → Always include error handling (2024-12-17)

Enter pattern id(s) to promote (comma-separated for multiple, or 'skip' to cancel):
Example: 12 or 12,15
```

**Step 2: Skill Preview**
```
Skill Preview: {situation}

---
name: {kebab-case situation}
description: {instruction}. Auto-applied in {situation} situations.
learned_from: skillfy ({created_at})
---

## Rules

{instruction}

## Applies to

- {situation}

---

[Save] [Edit] [Skip]
```

**Step 3: Result**
```
✅ Skill created

- .claude/skills/{skill-name}/SKILL.md

🔄 Restart Claude Code to activate this skill.
```

</details>

---

### Show Help

```bash
/skillfy help
```

Display available commands and current status.

<details>
<summary>📖 Detailed Usage</summary>

**Output (when initialized):**
```
📚 Skillfy Help

Status: ✅ Initialized | Patterns: {count} | Skills: {count}

Commands:
  /skillfy init      Initialize Skillfy
  /skillfy           Record an expectation mismatch
  /skillfy review    Promote patterns to Skills
  /skillfy reset     Delete all data
  /skillfy help      Show this help

Quick Start:
  1. /skillfy init → 2. /skillfy → 3. /skillfy review
```

</details>

---

### Reset Data

```bash
/skillfy reset
```

⚠️ Deletes all pattern records. Generated Skills are preserved.

<details>
<summary>📖 Detailed Usage</summary>

**Options:**
- `/skillfy reset` - Delete database records only (skills preserved)
- `/skillfy reset --all` - Delete everything including skills

**Step 1: Current Status**
```
⚠️ Skillfy Reset

Database file:
- {DB_PATH}

Data to delete:
- {count} patterns

Note: Generated Skills (.claude/skills/) will be preserved.
```

**Step 2: Confirmation**
- "Are you sure you want to delete all Skillfy data?"
- [Yes, reset all data] [Cancel]

**Step 3: Result**
```
✅ Skillfy data has been reset

- Patterns: all deleted
- Skills: preserved (.claude/skills/)

Start new records with /skillfy.
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

Run `/skillfy` right after the mismatch:

```
Situation: > Creating React components
Expected: > TypeScript interface for props
Instruction: > Always define a TypeScript interface for component props

What would you like to do?
> 1. Register as Skill
```

Result:
```
✅ Skill created: .claude/skills/creating-react-components/SKILL.md

🔄 Restart Claude Code to activate this skill.
```

---

### ✨ Step 2: Result

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

The recommended workflow:

```
1. Work with Claude as usual
       ↓
2. Notice a mismatch? Run /skillfy immediately
       ↓
3. Be specific: "When creating React components" > "When coding"
       ↓
4. Write clear instructions: "Always use TypeScript interfaces"
       ↓
5. Restart Claude Code to activate new Skills
```

**Tips:**
- 📝 Record mismatches **right when they happen** - context matters
- 🎯 Be **specific** about the situation - vague patterns don't help
- ✍️ Write **imperative instructions** - "Always do X" or "Never do Y"
- 🚀 After creating Skills, **restart Claude Code** to load them

## How It Works

1. **Record**: Log situations where Claude's output didn't match expectations with `/skillfy`
2. **Save or Promote**: Either save as memo for later or create Skill immediately
3. **Review**: Use `/skillfy review` to promote saved patterns to Skills
4. **Apply**: Once promoted to a Skill, Claude automatically applies it in similar situations

## Data Storage

| File | Purpose |
|------|---------|
| `.claude/skillfy/patterns.db` | SQLite DB (`patterns`, `schema_version` tables) |
| `.claude/skills/*/SKILL.md` | Promoted Skills |

## Security Considerations

### Data Privacy
- **patterns.db may contain sensitive data**: The database stores situations and expectations you record. Be mindful of what information you include.
- **Automatic .gitignore**: The init command automatically adds `.claude/skillfy/` to `.gitignore` to prevent accidental commits.
- **Backup exclusions**: Consider excluding `.claude/skillfy/` from cloud sync services if it contains sensitive information.

### File Permissions
- Ensure `.claude/` directory is not world-readable if it contains sensitive patterns
- The database file should only be accessible by your user account

### Input Validation
- SQL injection is prevented through quote escaping
- Path traversal is prevented in skill name generation

## Troubleshooting

### Common Issues

**"sqlite3 is required but not installed"**
- macOS/Linux: sqlite3 is typically pre-installed
- Windows: Install from https://sqlite.org/download.html

**Skills not being applied**
- Ensure the skill was properly created (check `/skillfy help` for status)
- Verify the skill file exists in `.claude/skills/`
- **Restart Claude Code** to load new skills

## Requirements

- Claude Code
- sqlite3 CLI (pre-installed on macOS/Linux)
- SQLite version 3.24.0+ (for UPSERT support)

## License

MIT
