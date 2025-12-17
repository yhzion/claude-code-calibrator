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

### Step 2: New Installation - User Confirmation

Ask the user for confirmation with a clear message:

```
⚙️ Calibrator Initialization

This will create:
- .claude/calibrator/patterns.db (SQLite database)
- .claude/skills/ directory (for promoted skills)

Options:
1. Initialize with auto-detection (recommended)
   → Automatically records patterns when fixing lint/type/build/test errors
2. Initialize without auto-detection
   → Only record patterns manually with /calibrate
3. Cancel

Which option? (1/2/3):
```

Wait for user response:
- User responds "1" or "yes" or confirms auto-detection → Set `AUTO_DETECT_ENABLED="yes"`
- User responds "2" or "no" or declines auto-detection → Set `AUTO_DETECT_ENABLED="no"`
- User responds "3" or "cancel" → Exit with message: "❌ Initialization cancelled."

On confirmation (option 1 or 2), execute Step 2-A, Step 2-B, and Step 2-C in order.

### Step 2-A: Create Directories and Database
```bash
# Create directories (with error handling)
if ! mkdir -p "$PROJECT_ROOT/.claude/calibrator"; then
  echo "❌ Error: Failed to create .claude/calibrator directory"
  exit 1
fi
mkdir -p "$PROJECT_ROOT/.claude/skills"

# Set secure permissions
chmod 700 "$PROJECT_ROOT/.claude/calibrator"        # Owner only: rwx
chmod 700 "$PROJECT_ROOT/.claude/skills"            # Owner only: rwx

# Create DB from schema.sql (with error handling and cleanup on failure)
if ! sqlite3 "$PROJECT_ROOT/.claude/calibrator/patterns.db" < "$PROJECT_ROOT/plugins/calibrator/schemas/schema.sql"; then
  rm -f "$PROJECT_ROOT/.claude/calibrator/patterns.db"
  echo "❌ Error: Failed to create database"
  exit 1
fi

# Set secure permissions on DB file
chmod 600 "$PROJECT_ROOT/.claude/calibrator/patterns.db"  # Owner only: rw
```

**Then, based on user's choice in Step 2:**

**If user selected Option 1 (auto-detection enabled):**
```bash
touch "$PROJECT_ROOT/.claude/calibrator/auto-detect.enabled"
chmod 600 "$PROJECT_ROOT/.claude/calibrator/auto-detect.enabled"
echo "📝 Auto pattern detection enabled"
```

**If user selected Option 2 (auto-detection disabled):**
```bash
rm -f "$PROJECT_ROOT/.claude/calibrator/auto-detect.enabled"
echo "📝 Auto pattern detection disabled"
```

### Step 2-B: Update .gitignore (REQUIRED for Git projects)

**IMPORTANT:** This step MUST be executed for Git projects to prevent accidental commits of sensitive data.

```bash
# Update .gitignore (for Git projects)
if [ -d "$PROJECT_ROOT/.git" ]; then
  GITIGNORE_ENTRIES="
# Calibrator runtime data (auto-added by /calibrate init)
.claude/calibrator/
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

If `.claude/calibrator` directory exists (from Step 1), display:

```
⚠️ Calibrator already exists

Current files:
- .claude/calibrator/patterns.db

Options:
1. Keep existing data - Exit without changes
2. Reinitialize - Delete all data and start fresh

Select option (1/2):
```

Wait for user response:
- User responds "1" or "keep" → Exit with message: "Keeping existing installation."
- User responds "2" or "reinitialize" → Execute cleanup and proceed to Step 2:
```bash
rm -rf "$PROJECT_ROOT/.claude/calibrator"
echo "🗑️ Existing data removed"
# Then proceed with new installation (Step 2)
```

### Step 4: Completion Message
English example:
```
✅ Calibrator initialization complete

- .claude/calibrator/patterns.db created
- .claude/skills/ directory created
- .gitignore updated (if Git project)
- Auto pattern detection: {enabled|disabled}

You can now record mismatches with /calibrate.
{If auto-detection enabled: Patterns will also be recorded automatically when fixing lint/format/type/build/test errors.}
```
