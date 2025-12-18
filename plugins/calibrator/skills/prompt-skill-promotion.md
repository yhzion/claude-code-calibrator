---
name: prompt-skill-promotion
description: When a manually recorded pattern reaches CALIBRATOR_THRESHOLD+ occurrences (default 2), prompt the user to promote it to a skill. Activates after /calibrate command records a pattern that reaches the threshold.
---

# Skill Promotion Prompt

This skill activates when a pattern recorded via `/calibrate` command reaches the promotion threshold (count >= CALIBRATOR_THRESHOLD, default 2) and hasn't been promoted or dismissed yet.

## Activation Condition

Activate this skill when the /calibrate command outputs a promotion suggestion:
```
💡 Pattern repeated {count}x → /calibrate review to promote to skill
```

Or when you detect that a newly recorded pattern has count >= CALIBRATOR_THRESHOLD by checking the database.

## Workflow

### Step 1: Parse the promotion context

Extract the following from the marker:
- `pattern_id`: Database ID of the pattern
- `count`: Number of occurrences
- `situation`: Error description
- `instruction`: Suggested fix instruction

### Step 2: Ask the user

Present the following question to the user using AskUserQuestion tool:

**Question format:**
```
This error pattern has occurred {count} times. Would you like to promote it to a Skill?

**Pattern**: {situation}
**Suggested Rule**: {instruction}

Promoting to a Skill means Claude will learn to handle this pattern automatically in the future.
```

**Options:**
1. `Yes` - Promote to Skill (requires restart)
2. `No` - Don't promote (won't ask again for this pattern)

### Step 3: Handle user response

#### If user selects "Yes":

1. Create the skill file using the centralized script:
```bash
# Use the centralized create-skill.sh script for consistent skill creation
# This script handles: name generation, collision detection, template processing, DB update
SCRIPT_PATH="${CLAUDE_PLUGIN_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/plugins/calibrator}/scripts/create-skill.sh"

if [ -f "$SCRIPT_PATH" ]; then
  bash "$SCRIPT_PATH" "{{PATTERN_ID}}" "{{SITUATION}}" "{{INSTRUCTION}}" "{{COUNT}}"
else
  echo "❌ Error: create-skill.sh not found at $SCRIPT_PATH"
  exit 1
fi
```

2. Display success message:
```
Skill created successfully: {skill_path}

To apply this skill, please restart Claude Code.
The skill will then be automatically loaded and applied to similar patterns.
```

#### If user selects "No":

1. Update the database to mark as dismissed:
```bash
set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DB_PATH="$PROJECT_ROOT/.claude/calibrator/patterns.db"

# Auto-migrate schema if needed (ensures dismissed column exists)
# Note: Centralized version available in scripts/utils.sh:ensure_schema_version()
HAS_DISMISSED=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pragma_table_info('patterns') WHERE name='dismissed';" 2>/dev/null || echo "0")
if [ "$HAS_DISMISSED" = "0" ]; then
  sqlite3 "$DB_PATH" "ALTER TABLE patterns ADD COLUMN dismissed INTEGER NOT NULL DEFAULT 0 CHECK(dismissed IN (0, 1));" 2>/dev/null || true
  sqlite3 "$DB_PATH" "CREATE INDEX IF NOT EXISTS idx_patterns_dismissed ON patterns(dismissed);" 2>/dev/null || true
  sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO schema_version (version) VALUES ('1.1');" 2>/dev/null || true
fi

sqlite3 "$DB_PATH" "UPDATE patterns SET dismissed = 1 WHERE id = {{PATTERN_ID}};"

echo "PATTERN_DISMISSED"
```

2. Display confirmation message:
```
Pattern dismissed. You won't be asked about this pattern again.

You can manually promote dismissed patterns later using:
/calibrate review --dismissed
```

## Important Notes

- Replace `{{PATTERN_ID}}`, `{{SITUATION}}`, `{{INSTRUCTION}}`, and `{{COUNT}}` with actual values from the promotion context
- The skill is created in a directory structure: `.claude/skills/{kebab-case-situation}/SKILL.md`
  - Example: `.claude/skills/typecheck-missing-type/SKILL.md`
- This naming is consistent with `/calibrate review` command's skill creation
- After creating a skill, the user must restart Claude Code for it to take effect
- Dismissed patterns can still be manually promoted via `/calibrate review --dismissed`
- Uses the same skill-template.md as other commands for consistent formatting
