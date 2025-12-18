# Skillfy

🌍 **English** | [한국어](./docs/README.ko.md) | [日本語](./docs/README.ja.md) | [中文](./docs/README.zh.md)

![macOS: compatible](https://img.shields.io/badge/macOS-compatible-brightgreen?style=for-the-badge&logo=apple&logoColor=white)
![Linux: compatible](https://img.shields.io/badge/Linux-compatible-brightgreen?style=for-the-badge&logo=linux&logoColor=white)
![Windows: use WSL](https://img.shields.io/badge/Windows-use%20WSL-blue?style=for-the-badge&logo=windows&logoColor=white)

> **Windows Users**: Use [WSL (Windows Subsystem for Linux)](https://learn.microsoft.com/en-us/windows/wsl/install) to run Skillfy.

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
/plugin install skillfy@claude-code-skillfy
```

### Update

```bash
/plugin marketplace update claude-code-skillfy
```

### Uninstall

To completely remove the plugin, first uninstall it and then remove it from the marketplace:
```bash
/plugin uninstall skillfy@claude-code-skillfy
/plugin marketplace remove claude-code-skillfy
```

## Usage

### Initialize

```bash
/skillfy init
```

Creates the Skillfy database and directory structure.

> **Note**: Skillfy installs in your Git repository root, or the current directory if not in a Git repository.

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
   - Note: Schema upgrades are handled via reinitialization. There is no in-place migration; back up your data if needed.

3. **Completion:**
   ```
   Skillfy initialization complete

   - .claude/skillfy/patterns.db created
   - .claude/skills/ directory created
   - .gitignore updated (if Git project)

   You can now record mismatches with /skillfy.
   Use /skillfy review to promote saved patterns to skills.
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

> **Smart Suggestions**: Claude analyzes your current session context and dynamically suggests relevant options at each step. You can always choose "Enter manually" if the suggestions don't match your needs.

**Step 1: Situation Selection** (max 500 chars)

Claude analyzes the current session and suggests relevant situations:
```
Recording Pattern Mismatch

What situation did this happen in?

1. {Suggested situation from context analysis}
2. {Another suggestion based on recent errors/corrections}
3. Enter manually

Select:
```

**Step 2: Expectation Selection** (max 1000 chars)

Claude suggests expectations based on the selected situation:
```
What did you expect?

1. {Suggested expectation based on situation}
2. {Another relevant expectation}
3. Enter manually

Select:
```

**Step 3: Instruction Selection** (max 2000 chars)

Claude suggests actionable instructions:
```
What rule should Claude learn? (imperative form)

1. {Suggested instruction - e.g., "Always include timestamp fields"}
2. {Another instruction option}
3. Enter manually

Select:
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

## Examples

### Do

(Add positive examples here)

### Don't

(Add negative examples here)

## Learning History

- Created: {created_at}
- Source: Manual recording via /skillfy

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

Status: ✅ Initialized | Patterns: {count} | Skills: {count} | Pending: {count}

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
  > ⚠️ **Warning**: This deletes the entire `.claude/skills/` directory, including any non-Skillfy skills. Back up important skills before using this option.

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

## Examples

Two common scenarios to learn how to use Skillfy.

### Example 1: Code Style Preference

Let's walk through a real scenario from start to finish.

#### 😤 The Problem

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

#### 📝 Step 1: Record the Mismatch

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

#### ✨ Step 2: Result

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

### Example 2: Workflow Behavior Preference

Learn how to teach Claude when to act automatically vs. ask for confirmation.

#### 😤 The Problem

You ask Claude to check code quality:

```
> Check lint and format
```

Claude finds issues and asks:
```
Found issues:

| Check    | Status                           |
|----------|----------------------------------|
| ESLint   | ⚠️ 1 warning                     |
| Prettier | ❌ 2 files need formatting       |

Would you like me to fix these issues?
```

**But you wanted Claude to just fix them!** You don't want to be asked every time...

---

#### 📝 Step 1: Record the Mismatch

Run `/skillfy` right after the mismatch:

```
Situation: > When checking lint/format
Expected: > Auto-fix issues without asking and fix first, then report
Instruction: > Fix without asking, report after

What would you like to do?
> 1. Register as Skill
```

Result:
```
✅ Skill created: .claude/skills/when-checking-lintformat/SKILL.md

🔄 Restart Claude Code to activate this skill.
```

---

#### ✨ Step 2: Result

**Restart Claude Code**, then ask the same question:

```
> Check lint and format
```

Now Claude responds:
```
The skill instructs me to fix without asking. Let me fix these issues now.

✅ All issues fixed:

| Check    | Result                                         |
|----------|------------------------------------------------|
| Prettier | ✅ 2 files formatted (App.vue, HelloWorld.vue) |
| ESLint   | ✅ 0 errors, 0 warnings                        |

Changes made:
- src/App.vue — formatting fixed
- src/components/HelloWorld.vue — formatting fixed + added default value
```

🎉 **Claude learned your workflow preference and acts without asking!**

---

#### ⚠️ Note: Skill Activation

Skills may not always trigger automatically. If Claude doesn't apply the skill:

1. **Improve the description** - Make the skill's `description` field more specific
2. **Manual invocation** - You can explicitly invoke it:
   ```
   > Check lint and format. Use skill: when-checking-lintformat
   ```
3. **Check skill loading** - Run `/skillfy help` to verify the skill is recognized

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

### Skill Naming Rules

When a skill is created, the name is automatically generated from the situation:

| Rule | Example |
|------|---------|
| Convert to lowercase | "Creating Models" → "creating-models" |
| Replace spaces with hyphens | "API endpoint" → "api-endpoint" |
| Remove special characters | "React (TSX)" → "react-tsx" |
| Maximum 50 characters | Truncated if longer |
| Collision handling | Adds suffix: `-1`, `-2`, etc. |

## Security Considerations

### Data Privacy
- **patterns.db may contain sensitive data**: The database stores situations and expectations you record. Be mindful of what information you include.
- **Automatic .gitignore**: The init command automatically adds `.claude/skillfy/` to `.gitignore` to prevent accidental commits.
- **Review skill files before committing**: Generated skills in `.claude/skills/` are NOT gitignored. Review them for sensitive context before committing to version control.
- **Backup exclusions**: Consider excluding `.claude/skillfy/` from cloud sync services if it contains sensitive information.

### File Permissions

Secure permissions are **automatically set** during initialization:

| Path | Permission | Description |
|------|------------|-------------|
| `.claude/skillfy/` | `700` (rwx------) | Owner only: read, write, execute |
| `.claude/skills/` | `700` (rwx------) | Owner only: read, write, execute |
| `patterns.db` | `600` (rw-------) | Owner only: read, write |

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
- SQLite version 3.24.0+ (for improved performance and compatibility)
- `realpath` or `python3` (for path resolution in review command; typically pre-installed)

## License

MIT
