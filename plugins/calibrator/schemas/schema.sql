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
  dismissed   INTEGER NOT NULL DEFAULT 0 CHECK(dismissed IN (0, 1)),  -- User declined promotion (won't ask again)
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

-- Composite index for UPSERT conflict detection (critical for performance)
CREATE INDEX IF NOT EXISTS idx_patterns_situation_instruction ON patterns(situation, instruction);

-- Composite index for review query optimization
-- Optimizes: WHERE count >= N AND promoted = 0 AND (dismissed = 0 OR dismissed IS NULL)
CREATE INDEX IF NOT EXISTS idx_patterns_review ON patterns(promoted, dismissed, count DESC);

-- ============================================================================
-- Migration Instructions (v1.0 → v1.1)
-- ============================================================================
-- For existing installations with schema v1.0, run the following migration:
--
-- Step 1: Check if dismissed column exists
--   SELECT COUNT(*) FROM pragma_table_info('patterns') WHERE name='dismissed';
--
-- Step 2: If result is 0, add the column:
--   ALTER TABLE patterns ADD COLUMN dismissed INTEGER NOT NULL DEFAULT 0 CHECK(dismissed IN (0, 1));
--
-- Step 3: Add index for dismissed column:
--   CREATE INDEX IF NOT EXISTS idx_patterns_dismissed ON patterns(dismissed);
--
-- Step 4: Update schema version:
--   INSERT OR REPLACE INTO schema_version (version) VALUES ('1.1');
--
-- Note: Commands that use the dismissed column (calibrate-review, prompt-skill-promotion)
-- will auto-migrate the database if they detect an older schema version.
