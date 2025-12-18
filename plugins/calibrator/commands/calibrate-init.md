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
1. Initialize - Create database and directory structure
2. Cancel

Which option? (1/2):
```

Wait for user response:
- User responds "1" or "yes" → Proceed to Step 2-A, Step 2-B, and Step 2-C
- User responds "2" or "cancel" → Exit with message: "❌ Initialization cancelled."

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

# Create DB with inline schema (v1.1)
if ! sqlite3 "$PROJECT_ROOT/.claude/calibrator/patterns.db" <<'SCHEMA_EOF'
-- Calibrator SQLite Schema v1.1
-- Requires SQLite 3.24.0+ for UPSERT (ON CONFLICT DO UPDATE) support

-- Observations table: Individual mismatch records
CREATE TABLE IF NOT EXISTS observations (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
  category    TEXT NOT NULL CHECK(category IN ('missing', 'excess', 'style', 'other')),
  situation   TEXT NOT NULL CHECK(length(situation) <= 500),
  expectation TEXT NOT NULL CHECK(length(expectation) <= 1000),
  file_path   TEXT,
  notes       TEXT
);

-- Patterns table: Aggregated patterns for skill promotion
CREATE TABLE IF NOT EXISTS patterns (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  situation   TEXT NOT NULL CHECK(length(situation) <= 500),
  instruction TEXT NOT NULL CHECK(length(instruction) <= 2000),
  count       INTEGER DEFAULT 1 CHECK(count >= 1),
  first_seen  DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_seen   DATETIME DEFAULT CURRENT_TIMESTAMP,
  promoted    INTEGER NOT NULL DEFAULT 0 CHECK(promoted IN (0, 1)),
  dismissed   INTEGER NOT NULL DEFAULT 0 CHECK(dismissed IN (0, 1)),
  skill_path  TEXT,
  UNIQUE(situation, instruction)
);

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
  version    TEXT PRIMARY KEY,
  applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insert current schema version
INSERT OR IGNORE INTO schema_version (version) VALUES ('1.1');

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_observations_situation ON observations(situation);
CREATE INDEX IF NOT EXISTS idx_observations_timestamp ON observations(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_patterns_count ON patterns(count DESC);
CREATE INDEX IF NOT EXISTS idx_patterns_promoted ON patterns(promoted);
CREATE INDEX IF NOT EXISTS idx_patterns_dismissed ON patterns(dismissed);
CREATE INDEX IF NOT EXISTS idx_patterns_situation_instruction ON patterns(situation, instruction);

-- Composite index for review query optimization
CREATE INDEX IF NOT EXISTS idx_patterns_review ON patterns(promoted, dismissed, count DESC);
SCHEMA_EOF
then
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

If `.claude/calibrator` directory exists (from Step 1):

**Step 3-A: Check Schema Version**
```bash
DB_PATH="$PROJECT_ROOT/.claude/calibrator/patterns.db"
CURRENT_VERSION=""
NEEDS_MIGRATION="no"

if [ -f "$DB_PATH" ]; then
  # Get current schema version
  CURRENT_VERSION=$(sqlite3 "$DB_PATH" "SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;" 2>/dev/null || echo "")

  # If no version found, assume 1.0 (pre-versioning)
  if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="1.0"
  fi

  # Check if migration is needed (target: 1.1)
  if [ "$CURRENT_VERSION" != "1.1" ]; then
    NEEDS_MIGRATION="yes"
  fi
fi
```

**Step 3-B: Display Options Based on Migration Status**

If `NEEDS_MIGRATION="yes"`, display:
```
⚠️ Calibrator already exists (schema v{CURRENT_VERSION})

A database upgrade is available (v{CURRENT_VERSION} → v1.1).

Current files:
- .claude/calibrator/patterns.db

Options:
1. Upgrade database - Migrate to v1.1 (preserves all data)
2. Keep as-is - Exit without changes (some features may not work)
3. Reinitialize - Delete all data and start fresh with v1.1

Select option (1/2/3):
```

Wait for user response:
- User responds "1" or "upgrade" → Execute migration (Step 3-C)
- User responds "2" or "keep" → Exit with message: "Keeping existing installation. Note: Some features may not work with older schema."
- User responds "3" or "reinitialize" → Execute cleanup and proceed to Step 2

If `NEEDS_MIGRATION="no"` (already at latest version), display:
```
⚠️ Calibrator already exists (schema v1.1 - up to date)

Current files:
- .claude/calibrator/patterns.db

Options:
1. Keep existing data - Exit without changes
2. Reinitialize - Delete all data and start fresh

Select option (1/2):
```

Wait for user response:
- User responds "1" or "keep" → Exit with message: "Keeping existing installation."
- User responds "2" or "reinitialize" → Execute cleanup and proceed to Step 2

**Step 3-C: Execute Migration (v1.0 → v1.1)**
```bash
echo "🔄 Migrating database schema from v1.0 to v1.1..."

# Add dismissed column if it doesn't exist
# SQLite doesn't have IF NOT EXISTS for ADD COLUMN, so we check first
HAS_DISMISSED=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pragma_table_info('patterns') WHERE name='dismissed';" 2>/dev/null || echo "0")

if [ "$HAS_DISMISSED" = "0" ]; then
  if ! sqlite3 "$DB_PATH" "ALTER TABLE patterns ADD COLUMN dismissed INTEGER NOT NULL DEFAULT 0 CHECK(dismissed IN (0, 1));"; then
    echo "❌ Error: Failed to add dismissed column"
    exit 1
  fi

  # Add index for dismissed column
  sqlite3 "$DB_PATH" "CREATE INDEX IF NOT EXISTS idx_patterns_dismissed ON patterns(dismissed);" 2>/dev/null || true
fi

# Update schema version
sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO schema_version (version) VALUES ('1.1');" 2>/dev/null || true

echo "✅ Database migrated to schema v1.1"
```

After successful migration, display completion message and exit.

**Step 3-D: Reinitialize (cleanup)**
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

You can now record mismatches with /calibrate.
```
