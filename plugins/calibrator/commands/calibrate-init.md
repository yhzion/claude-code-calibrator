---
name: calibrate init
description: Initialize Calibrator. Create database and directory structure.
allowed-tools: Bash(git:*), Bash(mkdir:*), Bash(sqlite3:*), Bash(chmod:*), Bash(test:*), Bash(rm:*), Bash(grep:*), Bash(echo:*), Bash(awk:*), Bash(sort:*), Bash(head:*), Bash(printf:*)
---

# /calibrate init

Initialize the Calibrator system.

## Execution Flow

### Step 0: Dependency Check
```bash
# Bash strict mode for safer script execution
set -euo pipefail
IFS=$'\n\t'

# Ensure UTF-8 locale for proper character handling
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true

# Get project root (Git root or current directory as fallback)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# POSIX-compatible version comparison (returns 0 if $1 >= $2)
version_ge() {
  printf '%s\n%s' "$2" "$1" | awk -F. '
    NR==1 { split($0,a,"."); next }
    NR==2 { split($0,b,".")
      for(i=1; i<=3; i++) {
        if((b[i]+0) > (a[i]+0)) exit 0
        if((b[i]+0) < (a[i]+0)) exit 1
      }
      exit 0
    }'
}

# Check required dependencies
if ! command -v sqlite3 &> /dev/null; then
  echo "❌ Error: sqlite3 is required but not installed."
  exit 1
fi

# SQLite 3.24.0+ required for UPSERT support
SQLITE_VERSION=$(sqlite3 --version 2>/dev/null | awk '{print $1}')
MIN_SQLITE_VERSION="3.24.0"
if ! version_ge "$SQLITE_VERSION" "$MIN_SQLITE_VERSION"; then
  echo "❌ Error: SQLite $MIN_SQLITE_VERSION or higher required. Found: ${SQLITE_VERSION:-unknown}"
  exit 1
fi
```

### Step 1: Check Existing Installation
```bash
# NOTE: Avoid exiting in strict mode when directory does not exist
test -d "$PROJECT_ROOT/.claude/calibrator" || true
```

### Step 2: New Installation - Confirmation
```
⚙️ Calibrator Initialization

Files to create:
- .claude/calibrator/patterns.db

[Confirm] [Cancel]
```

On confirmation, execute Step 2-A, Step 2-B, and Step 2-C in order.

### Step 2-A: Create Directories and Database
```bash
# Create directories (with error handling)
if ! mkdir -p "$PROJECT_ROOT/.claude/calibrator"; then
  echo "❌ Error: Failed to create .claude/calibrator directory"
  exit 1
fi
mkdir -p "$PROJECT_ROOT/.claude/skills/learned"

# Set secure permissions
chmod 700 "$PROJECT_ROOT/.claude/calibrator"        # Owner only: rwx
chmod 700 "$PROJECT_ROOT/.claude/skills/learned"    # Owner only: rwx

# Create DB from schema.sql (with error handling and cleanup on failure)
if ! sqlite3 "$PROJECT_ROOT/.claude/calibrator/patterns.db" < "$PROJECT_ROOT/plugins/calibrator/schemas/schema.sql"; then
  rm -f "$PROJECT_ROOT/.claude/calibrator/patterns.db"
  echo "❌ Error: Failed to create database"
  exit 1
fi

# Set secure permissions on DB file
chmod 600 "$PROJECT_ROOT/.claude/calibrator/patterns.db"  # Owner only: rw
```

### Step 2-B: Update .gitignore (REQUIRED for Git projects)

**IMPORTANT:** This step MUST be executed for Git projects to prevent accidental commits of sensitive data.

```bash
# Update .gitignore (for Git projects)
if [ -d "$PROJECT_ROOT/.git" ]; then
  GITIGNORE_ENTRIES="
# Calibrator runtime data (auto-added by /calibrate init)
.claude/calibrator/
.claude/skills/learned/
.claude/calibrator/*.db-journal
.claude/calibrator/*.db-wal
.claude/calibrator/*.db-shm"

  if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    # .gitignore exists: append if not already present
    if ! grep -q ".claude/calibrator/" "$PROJECT_ROOT/.gitignore"; then
      echo "$GITIGNORE_ENTRIES" >> "$PROJECT_ROOT/.gitignore"
      echo "📝 Calibrator entries added to .gitignore"
    else
      echo "📝 .gitignore already contains calibrator entries"
    fi
  else
    # .gitignore does not exist: create new file
    echo "$GITIGNORE_ENTRIES" > "$PROJECT_ROOT/.gitignore"
    echo "📝 .gitignore file created with calibrator entries"
  fi
fi
```

### Step 2-C: Verify .gitignore was updated
```bash
# Verify .gitignore contains calibrator entries
if [ -d "$PROJECT_ROOT/.git" ]; then
  if [ -f "$PROJECT_ROOT/.gitignore" ] && grep -q ".claude/calibrator/" "$PROJECT_ROOT/.gitignore"; then
    echo "✅ .gitignore verification passed"
  else
    echo "⚠️ Warning: .gitignore may not be properly configured"
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
rm -rf "$PROJECT_ROOT/.claude/calibrator"
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
