---
name: calibrate init
description: Initialize Calibrator. Create database and directory structure.
allowed-tools: Bash(mkdir:*), Bash(sqlite3:*), Bash(chmod:*), Bash(test:*), Bash(rm:*), Bash(grep:*), Bash(echo:*), Bash(awk:*), Bash(sort:*), Bash(head:*), Bash(printf:*)
---

# /calibrate init

Initialize the Calibrator system.

## Execution Flow

### Step 0: Dependency Check
```bash
# Bash strict mode for safer script execution
set -euo pipefail
IFS=$'\n\t'

# Check required dependencies
if ! command -v sqlite3 &> /dev/null; then
  echo "❌ Error: sqlite3 is required but not installed."
  exit 1
fi

# SQLite 3.24.0+ required for UPSERT support
SQLITE_VERSION=$(sqlite3 --version 2>/dev/null | awk '{print $1}')
MIN_SQLITE_VERSION="3.24.0"
FIRST_VERSION=$(printf '%s\n%s' "$MIN_SQLITE_VERSION" "$SQLITE_VERSION" | sort -V | head -n1)
if [ "$FIRST_VERSION" != "$MIN_SQLITE_VERSION" ]; then
  echo "❌ Error: SQLite $MIN_SQLITE_VERSION or higher required. Found: ${SQLITE_VERSION:-unknown}"
  exit 1
fi
```

### Step 1: Check Existing Installation
```bash
test -d .claude/calibrator
```

### Step 2: New Installation - Confirmation
```
⚙️ Calibrator Initialization

Files to create:
- .claude/calibrator/patterns.db

[Confirm] [Cancel]
```

On confirmation:
```bash
# Create directories (with error handling)
if ! mkdir -p .claude/calibrator; then
  echo "❌ Error: Failed to create .claude/calibrator directory"
  exit 1
fi
mkdir -p .claude/skills/learned

# Set secure permissions
chmod 700 .claude/calibrator        # Owner only: rwx
chmod 700 .claude/skills/learned    # Owner only: rwx

# Create DB from schema.sql (with error handling and cleanup on failure)
if ! sqlite3 .claude/calibrator/patterns.db < plugins/calibrator/schemas/schema.sql; then
  rm -f .claude/calibrator/patterns.db
  echo "❌ Error: Failed to create database"
  exit 1
fi

# Set secure permissions on DB file
chmod 600 .claude/calibrator/patterns.db  # Owner only: rw

# Update .gitignore (for Git projects)
if [ -d .git ]; then
  GITIGNORE_ENTRIES="
# Calibrator runtime data (auto-added by /calibrate init)
.claude/calibrator/
.claude/skills/learned/
.claude/calibrator/*.db-journal
.claude/calibrator/*.db-wal
.claude/calibrator/*.db-shm"

  if [ -f .gitignore ]; then
    # Check if calibrator entries already exist
    if ! grep -q ".claude/calibrator/" .gitignore; then
      echo "$GITIGNORE_ENTRIES" >> .gitignore
      echo "📝 Calibrator entries added to .gitignore"
    fi
  else
    # Create .gitignore file
    echo "$GITIGNORE_ENTRIES" > .gitignore
    echo "📝 .gitignore file created"
  fi
fi
```

### Step 3: When Already Exists
```
⚠️ Calibrator already exists

Current files:
- .claude/calibrator/patterns.db

[Keep] [Reinitialize (delete data)]
```

- Keep selected: Exit
- Reinitialize selected:
```bash
rm -rf .claude/calibrator
# Proceed with new installation (starting from confirmation)
```

### Step 4: Completion Message
English example:
```
✅ Calibrator initialization complete

- .claude/calibrator/patterns.db created
- .claude/skills/learned/ directory created
- .gitignore updated (if Git project)

You can now record mismatches with /calibrate.
```
